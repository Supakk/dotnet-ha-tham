using System.Security.Claims;
using Mammod.Data;
using Mammod.Dtos;
using Mammod.Models;
using Mammod.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Mammod.Controllers;

/// <summary>
/// The token flow <c>apiClient.ts</c> is already written against:
///
///   1. <c>POST /auth/login</c> answers <c>{ user, accessToken }</c> and sets the
///      refresh cookie. The client puts the access token in an Authorization
///      header on every later request.
///   2. When it expires the client gets a 401, and its response interceptor calls
///      <c>POST /auth/refresh</c> once — with <c>withCredentials</c>, so the
///      browser attaches the cookie — then retries the original request.
///   3. If the refresh also fails the client sends the user back to the login
///      screen. So a 401 from here has to mean "sign in again" and nothing else.
///
/// Passwords are not checked. This is the demo account list carried over from the
/// client's <c>authService.ts</c>, and pretending otherwise would be worse than
/// saying so: see <see cref="Accounts"/> for where the real check belongs.
/// </summary>
[ApiController]
[Route("auth")]
public sealed class AuthController(TokenService tokens, IWebHostEnvironment env) : ControllerBase
{
    private sealed record Account(string Name, string Role, List<string>? Modules);

    /// <summary>
    /// Demo accounts, keyed by the local part of the email.
    ///
    /// Two kinds. <c>admin@…</c> and friends exercise the role guards with the run
    /// of the whole system; the module accounts are scoped to one area, which is
    /// how a transport office or a receiving desk actually signs in. Anything
    /// unrecognised falls back to an unscoped admin so a typo does not lock the
    /// demo out.
    ///
    /// Replacing this with a users table and a BCrypt check is the one change that
    /// turns this file into a real login — nothing above or below it moves.
    /// </summary>
    private static readonly Dictionary<string, Account> Accounts = new()
    {
        ["admin"] = new("ผู้ดูแลระบบ", "admin", null),
        ["manager"] = new("ผู้จัดการ", "manager", null),
        ["operator"] = new("ผู้ปฏิบัติงาน", "operator", null),
        ["viewer"] = new("ผู้ดูข้อมูล", "viewer", null),

        ["tms"] = new("ฝ่ายขนส่ง (TMS)", "operator", ["/logistics"]),
        ["inbound"] = new("ฝ่ายรับสินค้า", "operator", ["/inbound"]),
        ["outbound"] = new("ฝ่ายจัดส่งออก", "operator", ["/outbound"]),
        ["warehouse"] = new("ฝ่ายคลังสินค้า", "operator", ["/warehouse"]),
        ["inventory"] = new("ฝ่ายสต็อก", "operator", ["/inventory"]),
        ["reports"] = new("ฝ่ายรายงาน", "viewer", ["/reports"]),
        // The warehouse floor as a whole — every module except transport.
        ["wms"] = new("ฝ่ายคลัง (WMS)", "operator", ["/inbound", "/outbound", "/warehouse", "/inventory"]),
    };

    private static User UserFor(string email)
    {
        var local = email.Split('@')[0].ToLowerInvariant();
        var account = Accounts.GetValueOrDefault(local) ?? Accounts["admin"];
        return new User
        {
            Id = $"u-{(local == "" ? "1" : local)}",
            Name = account.Name,
            Email = email,
            Role = account.Role,
            Modules = account.Modules,
        };
    }

    [HttpPost("login")]
    public ActionResult<Session> Login([FromBody] Credentials body)
    {
        var email = body?.Email?.Trim() ?? "";
        if (email == "") throw new DomainException("กรุณากรอกอีเมล");

        var user = UserFor(email);
        SetRefreshCookie(user);
        return new Session(user, tokens.AccessToken(user));
    }

    /// <summary>
    /// Reads the refresh cookie and mints a new access token. Answers
    /// <c>{ accessToken }</c> — the exact shape <c>refreshAccessToken</c> in
    /// <c>apiClient.ts</c> destructures.
    /// </summary>
    [HttpPost("refresh")]
    public ActionResult<object> Refresh()
    {
        var cookie = Request.Cookies[TokenService.RefreshCookie];
        if (string.IsNullOrEmpty(cookie))
            throw new DomainException("เซสชันหมดอายุ — กรุณาเข้าสู่ระบบอีกครั้ง", StatusCodes.Status401Unauthorized);

        var principal = tokens.ReadRefreshToken(cookie)
            ?? throw new DomainException("เซสชันหมดอายุ — กรุณาเข้าสู่ระบบอีกครั้ง", StatusCodes.Status401Unauthorized);

        var user = UserFor(principal.FindFirst(ClaimTypes.Email)?.Value
            ?? principal.FindFirst("email")?.Value
            ?? "admin@mammod.co");

        // Reissued on every refresh, so a session that stays in use never expires
        // out from under someone mid-afternoon.
        SetRefreshCookie(user);
        return Ok(new { accessToken = tokens.AccessToken(user) });
    }

    /// <summary>
    /// Who the current token belongs to. Requires a valid access token — this is
    /// the one endpoint whose whole job is to answer that question, so an
    /// unauthenticated call to it is a 401 by design.
    /// </summary>
    [HttpGet("me")]
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    public ActionResult<User> Me()
    {
        var email = User.FindFirst(ClaimTypes.Email)?.Value
            ?? User.FindFirst("email")?.Value
            ?? "";
        return UserFor(email);
    }

    /// <summary>
    /// Clears the refresh cookie. The client ignores a failure here on purpose —
    /// a failed sign-out must not trap someone in a session they have left — so
    /// this always succeeds.
    /// </summary>
    [HttpPost("logout")]
    public IActionResult Logout()
    {
        Response.Cookies.Delete(TokenService.RefreshCookie, CookieOptions());
        return NoContent();
    }

    private void SetRefreshCookie(User user) =>
        Response.Cookies.Append(
            TokenService.RefreshCookie, tokens.RefreshToken(user),
            CookieOptions(DateTimeOffset.UtcNow.AddDays(7)));

    /// <summary>
    /// <c>HttpOnly</c> is the point: script on the page cannot read this cookie,
    /// so an XSS bug cannot walk off with a seven-day token.
    ///
    /// The client and the API are on different ports, which makes every request
    /// cross-site, so the cookie needs <c>SameSite=None</c> — and browsers only
    /// accept that together with <c>Secure</c>, which in turn needs HTTPS. Over
    /// plain http in development that combination is silently dropped, so
    /// development uses <c>SameSite=Lax</c> instead and refresh works on
    /// localhost. Serve this over HTTPS in any real deployment and the
    /// production branch takes over.
    /// </summary>
    private CookieOptions CookieOptions(DateTimeOffset? expires = null) => new()
    {
        HttpOnly = true,
        Path = "/",
        Expires = expires,
        Secure = !env.IsDevelopment(),
        SameSite = env.IsDevelopment() ? SameSiteMode.Lax : SameSiteMode.None,
    };
}
