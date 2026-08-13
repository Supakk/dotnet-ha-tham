using System.Text.Json.Serialization;

namespace Mammod.Models;

/// <summary>
/// The domain, ported field for field from the TypeScript types in
/// <c>src/features/logistics/types</c>. Property names serialise to camelCase,
/// which is what the client reads — do not rename one side without the other.
///
/// Optional properties (TypeScript <c>field?:</c>) carry
/// <c>[JsonIgnore(WhenWritingNull)]</c> so they are absent rather than null.
/// Properties that are genuinely nullable in the client (<c>LatLng | null</c>,
/// <c>string[] | null</c>) must NOT carry it: the client tests them against
/// <c>null</c>, and an omitted key reads back as <c>undefined</c>, which fails
/// that test and silently takes the wrong branch.
/// </summary>

/// <summary>[lat, lng] — the order Leaflet expects, so it stays an array.</summary>
public sealed record GeoPoint(string Name, double[] Position);

public sealed record ManifestStop
{
    public required string Id { get; init; }
    public required string DoNo { get; init; }
    /// <summary>Sales order this drop came from — the reference back to SAP via OMS.</summary>
    public required string SoNo { get; init; }
    public required string PickNo { get; init; }
    public required string PickDate { get; init; }
    public required string WarehouseCode { get; init; }
    public required string DeliveryZoneId { get; init; }
    public required string Customer { get; init; }
    public required string Address { get; init; }
    /// <summary>A site, branch or third party. Empty means the address above.</summary>
    public string DeliverTo { get; init; } = "";
    public int Boxes { get; init; }
    /// <summary>Gross weight in kg.</summary>
    public double Weight { get; init; }
    /// <summary>Volume in cubic metres.</summary>
    public double Cbm { get; init; }
    /// <summary>Cash on delivery in baht; 0 prints as a dash.</summary>
    public double Cod { get; init; }
    public required string DueDate { get; init; }
    /// <summary>pending | delivered | partial | returned</summary>
    public string Status { get; init; } = "pending";
    public required double[] Position { get; init; }
}

/// <summary>
/// Kept as parts, not one total: the trip rate is the standing price, the
/// adjustments are what happened on the day.
/// </summary>
public sealed record FreightPricing
{
    public double TripPrice { get; init; }
    public double PriceAdd { get; init; }
    public double PriceDeduct { get; init; }
    public string FreightNote { get; init; } = "";

    /// <summary>The billed total. Derived, never stored, so the parts stay the truth.</summary>
    public double Total() => TripPrice + PriceAdd - PriceDeduct;
}

public sealed record ExpressDispatch
{
    public string Requester { get; init; } = "";
    public string Approver { get; init; } = "";
    public string Note { get; init; } = "";
}

public static class ManifestStatus
{
    public const string Draft = "draft";
    public const string Confirmed = "confirmed";
    public const string Sent = "sent";
    public const string Invoiced = "invoiced";
    public const string Completed = "completed";
    public const string Error = "error";
    public const string Cancelled = "cancelled";

    /// <summary>
    /// The Thai labels the client shows. The server quotes them back inside the
    /// rejection messages, so a refusal names the status the user is looking at
    /// rather than the internal key.
    /// </summary>
    public static readonly IReadOnlyDictionary<string, string> Label = new Dictionary<string, string>
    {
        [Draft] = "สร้างใบขนส่ง",
        [Confirmed] = "ยืนยันใบขนส่งแล้ว",
        [Sent] = "ส่ง MMX แล้ว",
        [Invoiced] = "เปิดอินวอยซ์แล้ว",
        [Completed] = "เสร็จสิ้น",
        [Error] = "ตีกลับ / ผิดพลาด",
        [Cancelled] = "ยกเลิก",
    };
}

public sealed record Manifest
{
    public required string Id { get; init; }
    public required string ManifestNo { get; init; }
    public required string Status { get; init; }
    /// <summary>ISO timestamp the manifest was closed and the truck released.</summary>
    public required string ClosedAt { get; init; }
    public required string WarehouseCode { get; init; }
    public required string CreatedBy { get; init; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? ConfirmedAt { get; init; }

    /// <summary>YYYY-MM-DD. A plain date: planning happens by day, and a timestamp
    /// would make the calendar depend on the reader's timezone.</summary>
    public required string DeliveryDate { get; init; }

    /// <summary>Set on split children: the parent keeps its number, children get -1, -2, …</summary>
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? ParentId { get; init; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? SentAt { get; init; }

    /// <summary>What OMS reported back — the message shown against an error.</summary>
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? StatusMessage { get; init; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? CancelReason { get; init; }

    public string DriverId { get; init; } = "";
    /// <summary>Name as it was when the manifest closed — snapshotted like the carrier.</summary>
    public string DriverName { get; init; } = "";
    public string DriverPhone { get; init; } = "";
    public string PlateHead { get; init; } = "";
    public string PlateTrailer { get; init; } = "";
    /// <summary>4-wheel | 6-wheel | 10-wheel</summary>
    public string Vehicle { get; init; } = "6-wheel";
    /// <summary>Crew riding with the driver, excluding the driver.</summary>
    public int AssistantCount { get; init; }
    public double MaxPayloadKg { get; init; }
    public double MaxVolumeCbm { get; init; }
    public string CarrierId { get; init; } = "";
    public string Carrier { get; init; } = "";

    public string RouteId { get; init; } = "";
    /// <summary>Snapshot: renaming a route master must not rewrite issued documents.</summary>
    public string RouteCode { get; init; } = "";
    public string RouteName { get; init; } = "";
    public required GeoPoint Origin { get; init; }
    public string Dock { get; init; } = "";
    public string SealNo { get; init; } = "";
    /// <summary>Baht; 0 when the run is in-house. The figure the document was issued at.</summary>
    public double FreightCost { get; init; }
    public required FreightPricing Pricing { get; init; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public ExpressDispatch? Express { get; init; }

    /// <summary>Line colour on the map, assigned per trip by the server.</summary>
    public string Colour { get; init; } = "";

    public List<ManifestStop> Stops { get; init; } = [];

    /// <summary>
    /// The confirm gate. A manifest cut from a plan has no truck yet; confirming
    /// one would hand the warehouse a document nobody can drive. Enforced here as
    /// well as on the client's button — a disabled button is not a rule.
    /// </summary>
    public bool IsAssigned() => DriverId != "" && PlateHead != "" && RouteId != "";
}

public static class TransportPlanStatus
{
    public const string Draft = "draft";
    public const string Issued = "issued";
    public const string Cancelled = "cancelled";

    public static readonly IReadOnlyDictionary<string, string> Label = new Dictionary<string, string>
    {
        [Draft] = "ร่างแผน",
        [Issued] = "ออกใบขนส่งแล้ว",
        [Cancelled] = "ยกเลิก",
    };
}

public sealed record TransportPlan
{
    public required string Id { get; init; }
    public required string PlanNo { get; init; }
    public required string Status { get; init; }
    public required string CreatedAt { get; init; }
    public required string CreatedBy { get; init; }
    public required string WarehouseCode { get; init; }
    public required string DeliveryDate { get; init; }
    /// <summary>Territory the plan is built for — the pool is narrowed to it.</summary>
    public required string DeliveryZoneId { get; init; }
    public string Note { get; init; } = "";
    public List<ManifestStop> Stops { get; init; } = [];

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? ManifestId { get; init; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? ManifestNo { get; init; }
}

public sealed record IntegrationMessage
{
    public required string Id { get; init; }
    /// <summary>in = arriving at TMS, out = sent by TMS.</summary>
    public required string Direction { get; init; }
    /// <summary>OMS | MMX — the only two systems TMS has an interface with.</summary>
    public required string System { get; init; }
    /// <summary>Interface name, e.g. SO.Create.</summary>
    public required string Channel { get; init; }
    /// <summary>Document the message is about — an SO or a manifest number.</summary>
    public required string Reference { get; init; }
    public required string At { get; init; }
    /// <summary>success | failed | pending | resolved</summary>
    public required string Status { get; init; }
    public string Detail { get; init; } = "";
}
