using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;
using Mammod.Models;

namespace Mammod.Services;

/// <summary>
/// Issues the two tokens the client's <c>apiClient.ts</c> expects.
///
/// The access token goes back in the response body and the client puts it in an
/// <c>Authorization: Bearer</c> header. It is short-lived on purpose: a token
/// that leaks is only useful until it expires.
///
/// The refresh token goes back as an HttpOnly cookie, which JavaScript cannot
/// read — that is the whole reason it is a cookie and not a second field in the
/// body. When the access token expires the client gets a 401, calls
/// <c>POST /auth/refresh</c> with <c>withCredentials</c> so the browser attaches
/// that cookie, and retries the original request once.
/// </summary>
/// <param name="key">
/// รับกุญแจเข้ามา ไม่ไปอ่าน config เอง — เพื่อให้ <c>Program.cs</c> เป็นคนหามันตั้งแต่
/// ตอน startup ถ้าปล่อยให้คลาสนี้อ่านเองตอนถูกสร้าง (ซึ่ง DI จะเลื่อนไปจนมี request แรก)
/// เซิร์ฟเวอร์ที่ไม่ได้ตั้งกุญแจจะขึ้นมาปกติแล้วค่อยพังตอนมีคนใช้ ซึ่งเป็นเวลาที่แย่ที่สุด
/// ที่จะรู้
/// </param>
public sealed class TokenService(string key, IConfiguration config)
{
    private readonly string _key = key;
    private readonly string _issuer = config["Jwt:Issuer"] ?? "mammod-tms";
    private readonly string _audience = config["Jwt:Audience"] ?? "mammod-tms-client";

    /// <summary>Name of the HttpOnly cookie the refresh token rides in.</summary>
    public const string RefreshCookie = "mammod.refresh";

    public TokenValidationParameters ValidationParameters() => new()
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = _issuer,
        ValidAudience = _audience,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_key)),
        // Default is a five-minute grace period, which makes a 15-minute token
        // behave like a 20-minute one and hides expiry bugs during development.
        ClockSkew = TimeSpan.Zero,
    };

    public string AccessToken(User user) => Sign(user, TimeSpan.FromMinutes(30), "access");

    /// <summary>Long enough that a working day does not end in a surprise login screen.</summary>
    public string RefreshToken(User user) => Sign(user, TimeSpan.FromDays(7), "refresh");

    private string Sign(User user, TimeSpan lifetime, string kind)
    {
        var credentials = new SigningCredentials(
            new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_key)), SecurityAlgorithms.HmacSha256);

        List<Claim> claims =
        [
            new(JwtRegisteredClaimNames.Sub, user.Id),
            new(JwtRegisteredClaimNames.Email, user.Email),
            new(ClaimTypes.Name, user.Name),
            new(ClaimTypes.Role, user.Role),
            // Tells refresh from access, so an access token cannot be replayed at
            // the refresh endpoint to mint an endless series of new ones.
            new("kind", kind),
        ];

        // The scope an account is limited to. Absent means unscoped — the client
        // reads a missing `modules` as full access, which is the same convention.
        foreach (var module in user.Modules ?? []) claims.Add(new Claim("module", module));

        var token = new JwtSecurityToken(
            issuer: _issuer,
            audience: _audience,
            claims: claims,
            expires: DateTime.UtcNow.Add(lifetime),
            signingCredentials: credentials);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    /// <summary>
    /// Reads a refresh token back. Returns null on anything wrong with it —
    /// expired, re-signed, or an access token being passed off as a refresh one.
    /// </summary>
    public ClaimsPrincipal? ReadRefreshToken(string token)
    {
        try
        {
            var principal = new JwtSecurityTokenHandler()
                .ValidateToken(token, ValidationParameters(), out _);
            return principal.FindFirst("kind")?.Value == "refresh" ? principal : null;
        }
        catch (Exception)
        {
            // Any validation failure is the same answer to the caller: sign in again.
            return null;
        }
    }
}
