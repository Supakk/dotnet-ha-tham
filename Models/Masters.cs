using System.Text.Json.Serialization;

namespace Mammod.Models;

/// <summary>
/// Master data — the records the flow above points at. Ported from the same
/// TypeScript types, with the same rule about optional versus nullable fields.
/// </summary>

public sealed record Warehouse
{
    public required string Id { get; init; }
    /// <summary>What the floor says out loud, e.g. WSK. Printed on documents.</summary>
    public required string Code { get; init; }
    public required string Name { get; init; }
    public string Address { get; init; } = "";
    public string Province { get; init; } = "";
    public string District { get; init; } = "";
    public string SubDistrict { get; init; } = "";
    public string ZipCode { get; init; } = "";

    /// <summary>
    /// Where the yard gate actually is, confirmed by eye rather than geocoded.
    /// <c>null</c> means nobody has pinned it yet, and the client tests for
    /// exactly that — so this is never omitted from the JSON.
    /// </summary>
    public double[]? Position { get; init; }

    /// <summary>Whether a route may start here. A pick-only warehouse is not an origin.</summary>
    public bool IsDC { get; init; }
    public bool Active { get; init; } = true;
}

public sealed record DeliveryZone
{
    public required string Id { get; init; }
    public required string Code { get; init; }
    public required string Name { get; init; }
    /// <summary>Comma-separated districts the zone covers.</summary>
    public string Areas { get; init; } = "";
    public string Province { get; init; } = "";
    public string District { get; init; } = "";
    public string SubDistrict { get; init; } = "";
    public string ZipCode { get; init; } = "";
    public double Weight { get; init; }
    /// <summary>kg | ton</summary>
    public string WeightUnit { get; init; } = "kg";
}

public sealed record RouteMaster
{
    public required string Id { get; init; }
    /// <summary>Running code shown on documents, e.g. RT-NORTH-01.</summary>
    public required string Code { get; init; }
    public required string Name { get; init; }
    /// <summary>
    /// Zones this route covers, in the order the lorry passes through them —
    /// the link back to the territory master, and what a plan's order pool is
    /// narrowed to.
    /// </summary>
    public List<string> DeliveryZoneIds { get; init; } = [];

    /// <summary>
    /// Which of them the run is <i>for</i>. The northern run is the Phitsanulok
    /// run even though it calls at Nakhon Sawan and Phichit on the way, and that
    /// is the zone a report groups it under. Empty only on a route with no zones
    /// yet; otherwise the first is taken as primary.
    /// </summary>
    public string PrimaryZoneId { get; init; } = "";
    /// <summary>DC the run starts from, pre-filled onto every manifest built from it.</summary>
    public required GeoPoint DefaultOrigin { get; init; }
    public string Colour { get; init; } = "";
    /// <summary>Retired routes stay for historical manifests but cannot be picked.</summary>
    public bool Active { get; init; } = true;
}

public sealed record Carrier
{
    public required string Id { get; init; }
    public required string Code { get; init; }
    public required string Name { get; init; }
    /// <summary>in-house | subcontract</summary>
    public required string Type { get; init; }
    public string ContactName { get; init; } = "";
    public string Phone { get; init; } = "";
    public string Email { get; init; } = "";
    /// <summary>เลขประจำตัวผู้เสียภาษี — text, so leading zeros survive.</summary>
    public string TaxId { get; init; } = "";
    public bool Active { get; init; } = true;
}

public sealed record FleetVehicle
{
    public required string Id { get; init; }
    /// <summary>4-wheel | 6-wheel | 10-wheel</summary>
    public required string Type { get; init; }
    public required string PlateHead { get; init; }
    /// <summary>Trailer plate, or "-" for rigid trucks that have none.</summary>
    public string PlateTrailer { get; init; } = "-";
    public required string CarrierId { get; init; }
    public double MaxPayloadKg { get; init; }
    public double MaxVolumeCbm { get; init; }
    public bool Active { get; init; } = true;
}

public sealed record Driver
{
    public required string Id { get; init; }
    public required string Code { get; init; }
    public required string Name { get; init; }
    public string Phone { get; init; } = "";
    public string LicenseNo { get; init; } = "";
    /// <summary>ท.1 | ท.2 | ท.3 | ท.4</summary>
    public string LicenseType { get; init; } = "ท.2";
    public required string CarrierId { get; init; }
    public bool Active { get; init; } = true;
}

public sealed record Province(string Code, string Name);

public sealed record District(string ProvinceCode, string Name);

public sealed record DeliveryOrder
{
    public required string Id { get; init; }
    public required string DeliveryNo { get; init; }
    public required string CreatedDate { get; init; }
    public string Warehouse { get; init; } = "";
    public string CreatedBy { get; init; } = "";
    public string Vendor { get; init; } = "";
    /// <summary>pending | in_transit | delivered | cancelled</summary>
    public string Status { get; init; } = "pending";
}

/// <summary>Page of results, as returned by every paginated list endpoint.</summary>
public sealed record Paginated<T>(IReadOnlyList<T> Items, int Total, int Page, int PageSize);

public sealed record User
{
    public required string Id { get; init; }
    public required string Name { get; init; }
    public required string Email { get; init; }
    /// <summary>admin | manager | operator | viewer</summary>
    public required string Role { get; init; }

    /// <summary>
    /// Module paths this account may open. <c>null</c> is full access — the client
    /// reads that as "unscoped", so it is serialised as null rather than omitted.
    /// </summary>
    public List<string>? Modules { get; init; }
}

public sealed record Session(User User, string AccessToken);
