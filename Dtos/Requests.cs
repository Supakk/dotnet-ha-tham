using Mammod.Models;

namespace Mammod.Dtos;

/// <summary>
/// Request bodies, kept apart from the models on purpose.
///
/// A DTO carries only what the client is allowed to send. The manifest number,
/// the status, the trip colour and the timestamps are all missing from
/// <see cref="ManifestInput"/> because they are the server's to assign — if they
/// were on the model the client posted, a client could set them.
/// </summary>

/// <summary>Everything the manifest builder collects; the rest is assigned when it is closed.</summary>
public sealed record ManifestInput
{
    public string WarehouseCode { get; init; } = "";
    public string CreatedBy { get; init; } = "";
    public string DeliveryDate { get; init; } = "";
    public string? ConfirmedAt { get; init; }

    public string DriverId { get; init; } = "";
    public string DriverName { get; init; } = "";
    public string DriverPhone { get; init; } = "";
    public string PlateHead { get; init; } = "";
    public string PlateTrailer { get; init; } = "";
    public string Vehicle { get; init; } = "6-wheel";
    public int AssistantCount { get; init; }
    public double MaxPayloadKg { get; init; }
    public double MaxVolumeCbm { get; init; }
    public string CarrierId { get; init; } = "";
    public string Carrier { get; init; } = "";

    public string RouteId { get; init; } = "";
    public string RouteCode { get; init; } = "";
    public string RouteName { get; init; } = "";
    public GeoPoint? Origin { get; init; }
    public string Dock { get; init; } = "";
    public string SealNo { get; init; } = "";
    public double FreightCost { get; init; }
    public FreightPricing Pricing { get; init; } = new();
    public ExpressDispatch? Express { get; init; }

    /// <summary>
    /// Accepted and thrown away. The client sends back whatever it was holding;
    /// the colour it ends up with is the one the server hands out, because two
    /// clients creating a manifest at once would otherwise pick the same one.
    /// </summary>
    public string Colour { get; init; } = "";

    public List<ManifestStop> Stops { get; init; } = [];

    /// <summary>
    /// The parts of a manifest that came off the wire. The caller fills in the
    /// server-assigned fields with a <c>with</c> expression — the placeholders
    /// here exist only so the record can be constructed at all.
    /// </summary>
    public Manifest ToManifest() => new()
    {
        Id = "",
        ManifestNo = "",
        Status = ManifestStatus.Draft,
        ClosedAt = "",
        WarehouseCode = WarehouseCode,
        CreatedBy = CreatedBy,
        DeliveryDate = DeliveryDate,
        ConfirmedAt = ConfirmedAt,
        DriverId = DriverId,
        DriverName = DriverName,
        DriverPhone = DriverPhone,
        PlateHead = PlateHead,
        PlateTrailer = PlateTrailer,
        Vehicle = Vehicle,
        AssistantCount = AssistantCount,
        MaxPayloadKg = MaxPayloadKg,
        MaxVolumeCbm = MaxVolumeCbm,
        CarrierId = CarrierId,
        Carrier = Carrier,
        RouteId = RouteId,
        RouteCode = RouteCode,
        RouteName = RouteName,
        // A document with no origin would draw its route line from nowhere; the
        // Nonthaburi DC is where every fixture leaves from.
        Origin = Origin ?? new GeoPoint("DC นนทบุรี", [13.8591, 100.5217]),
        Dock = Dock,
        SealNo = SealNo,
        FreightCost = FreightCost,
        Pricing = Pricing,
        Express = Express,
        Colour = Colour,
        Stops = Stops,
    };
}

/// <summary>The editable plan header — the stops are moved by their own call, not typed in.</summary>
public sealed record TransportPlanInput
{
    public string WarehouseCode { get; init; } = "";
    public string DeliveryDate { get; init; } = "";
    public string RouteId { get; init; } = "";
    public string Note { get; init; } = "";
}

/// <summary>Body of <c>PUT /transport-plans/{id}/stops</c>.</summary>
public sealed record SetStopsRequest(List<string>? StopIds);

/// <summary>Body of <c>POST /manifests/{id}/cancel</c> — the reason is optional.</summary>
public sealed record CancelRequest(string? Reason);

/// <summary>Body of <c>POST /manifests/{id}/split</c>.</summary>
public sealed record SplitRequest(List<string>? StopIds);

/// <summary>Body of <c>POST /manifests/{id}/move</c>.</summary>
public sealed record MoveRequest(string? ToId, List<string>? StopIds);

/// <summary>Body of <c>POST /manifests/{id}/status</c> — what OMS reports back.</summary>
public sealed record ExternalStatusRequest(string? Outcome, string? Message);

/// <summary>Body of <c>POST /auth/login</c>.</summary>
public sealed record Credentials(string? Email, string? Password);
