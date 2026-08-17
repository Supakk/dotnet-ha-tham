using System.Security.Claims;

namespace Mammod.Database.Documents;

/// <summary>
/// Which warehouse this request is acting on, and who is acting.
///
/// Both are request-scoped and both are populated by
/// <see cref="WarehouseMiddleware"/> before any controller runs. They are
/// separate interfaces because they change for different reasons: the warehouse
/// comes off the request, the actor comes off the token.
/// </summary>
public sealed class RequestContext : IWarehouseContext, IActorContext
{
    /// <summary>
    /// Set once, by the middleware. Reading it before that is a bug in the
    /// pipeline order rather than a runtime condition to handle, so it throws
    /// instead of quietly answering with a default — a repository that silently
    /// scoped to the wrong warehouse would return another site's documents.
    /// </summary>
    public string CurrentWarehouseId =>
        _warehouseId ?? throw new InvalidOperationException(
            "ยังไม่ได้กำหนดคลังของ request นี้ — WarehouseMiddleware ต้องทำงานก่อน controller " +
            "ถ้าเห็นข้อความนี้แปลว่าลำดับ middleware ใน Program.cs ผิด");

    public string CurrentUser { get; private set; } = "";
    public string RequestId { get; private set; } = "";

    private string? _warehouseId;

    internal void Bind(string warehouseId, string user, string requestId)
    {
        _warehouseId = warehouseId;
        CurrentUser = user;
        RequestId = requestId;
    }
}

/// <summary>
/// Reads the warehouse off the request, checks it against the warehouse master,
/// and hands both it and the caller's identity to the scoped context.
///
/// <b>No default.</b> A request with no <c>X-Warehouse-Id</c> is refused rather
/// than served from a configured fallback. The database holds documents for
/// three warehouses; answering an unscoped request with one of them, chosen by
/// configuration, is how a planner in Bang Bua Thong ends up looking at Phichit's
/// load and believing it.
///
/// Applied to the document endpoints only. The master-data and auth controllers
/// have their own scoping and predate this, so forcing the header on them would
/// break the login screen for no gain.
/// </summary>
public sealed class WarehouseMiddleware(RequestDelegate next)
{
    public const string WarehouseHeader = "X-Warehouse-Id";
    public const string RequestIdHeader = "X-Request-Id";

    /// <summary>
    /// Paths the warehouse header is required on. Everything else passes
    /// through untouched — including <c>/auth</c>, which is how a caller gets a
    /// token in the first place and cannot be expected to know a warehouse yet.
    /// </summary>
    private static readonly string[] Scoped = ["/transport-plans", "/manifests"];

    public async Task InvokeAsync(HttpContext http, RequestContext context, MasterQueries masters)
    {
        var path = http.Request.Path.Value ?? "";
        var needsWarehouse = Scoped.Any(p => path.StartsWith(p, StringComparison.OrdinalIgnoreCase));

        // Preserved when the caller supplies one, so a trace that starts in the
        // browser stays one trace; generated otherwise so every audit row has
        // something to correlate on.
        var requestId = http.Request.Headers[RequestIdHeader].FirstOrDefault();
        if (string.IsNullOrWhiteSpace(requestId)) requestId = Guid.NewGuid().ToString("N")[..16];
        http.Response.Headers[RequestIdHeader] = requestId;

        var user = http.User.FindFirstValue(ClaimTypes.Name)
                ?? http.User.FindFirstValue(ClaimTypes.Email)
                ?? "anonymous";

        if (!needsWarehouse)
        {
            context.Bind("", user, requestId);
            await next(http);
            return;
        }

        var warehouse = http.Request.Headers[WarehouseHeader].FirstOrDefault()?.Trim();

        if (string.IsNullOrWhiteSpace(warehouse))
        {
            await Refuse(http, requestId, "WAREHOUSE_REQUIRED",
                $"ต้องระบุคลังใน header {WarehouseHeader} — ระบบมีเอกสารของหลายคลัง " +
                "จึงไม่เดาให้ว่ากำลังดูคลังไหน");
            return;
        }

        // Checked against the master rather than a list in code: a warehouse
        // added to MST_WHSE should work without a redeploy, and a list here
        // would be a second place for the two to disagree.
        var known = masters.Warehouses()
            .Any(w => string.Equals(w.Code, warehouse, StringComparison.OrdinalIgnoreCase));

        if (!known)
        {
            await Refuse(http, requestId, "WAREHOUSE_UNKNOWN",
                $"ไม่รู้จักคลัง {warehouse}");
            return;
        }

        // Normalised to the master's spelling so every downstream comparison and
        // every stored WHSEID matches, whatever case the caller sent.
        var code = masters.Warehouses()
            .First(w => string.Equals(w.Code, warehouse, StringComparison.OrdinalIgnoreCase)).Code;

        context.Bind(code, user, requestId);
        await next(http);
    }

    private static Task Refuse(HttpContext http, string requestId, string code, string message)
    {
        http.Response.StatusCode = StatusCodes.Status400BadRequest;
        return http.Response.WriteAsJsonAsync(new { code, message, requestId });
    }
}
