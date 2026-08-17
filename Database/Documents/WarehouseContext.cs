using Microsoft.Extensions.Options;

namespace Mammod.Database.Documents;

/// <summary>
/// Settings under <c>Tms</c> in appsettings.
///
/// <c>WarehouseId</c> is one value today because the application serves one
/// warehouse. It is configuration rather than a constant so that the assumption
/// is visible and changeable, and so that nothing in the repositories has to
/// know the literal.
/// </summary>
public sealed class TmsOptions
{
    public const string Section = "Tms";

    public string WarehouseId { get; set; } = "WSK";

    /// <summary>Written into ADDWHO/EDITWHO when no signed-in user is available.</summary>
    public string SystemActor { get; set; } = "api";
}

/// <summary>
/// The warehouse every query is scoped to, read from configuration.
///
/// Registered as a singleton: it does not vary per request today. When it does —
/// a warehouse picker, a claim on the token — this is the one class that
/// changes, and it becomes scoped without any repository noticing.
/// </summary>
public sealed class ConfiguredWarehouseContext(IOptions<TmsOptions> options) : IWarehouseContext
{
    public string CurrentWarehouseId { get; } = Require(options.Value.WarehouseId);

    /// <summary>
    /// A blank warehouse would not fail loudly — it would quietly match nothing,
    /// and every screen would show an empty list with no error. Better to refuse
    /// to start.
    /// </summary>
    private static string Require(string? value)
    {
        var trimmed = value?.Trim() ?? "";
        if (trimmed.Length == 0)
            throw new InvalidOperationException(
                "ไม่ได้ตั้งค่า Tms:WarehouseId — ต้องระบุรหัสคลังที่ระบบนี้ทำงานด้วย " +
                "(ค่าปกติคือ WSK) ไม่งั้นทุกหน้าจอจะแสดงข้อมูลว่างโดยไม่มีข้อความผิดพลาด");
        return trimmed;
    }
}
