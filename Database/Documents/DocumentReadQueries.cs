using Microsoft.EntityFrameworkCore;
using Mammod.Data;
using Mammod.Models;

namespace Mammod.Database.Documents;

/// <summary>
/// Reading plans and manifests out of SQL, in the shape the client already
/// expects.
///
/// A projection rather than an entity graph. The API's <c>ManifestStop</c> is
/// assembled from four tables — the stop, the order riding on it, the product
/// lines, and the SKU master for their weight — and no single EF entity holds
/// that. Loading the graph and shaping it in memory would pull every line of
/// every shipment across the wire to produce two numbers.
///
/// <b>Aggregates are computed in isolated subqueries.</b> A stop has one order
/// today but the schema allows several, and each order has one to three product
/// lines. Joining stop → detail → line in one statement multiplies the stop row
/// once per line, and any SUM over that is inflated by exactly the factor nobody
/// notices until a lorry is overloaded on paper. Each aggregate is therefore its
/// own correlated subquery.
///
/// Everything is warehouse-scoped, without exception.
/// </summary>
public sealed class DocumentReadQueries(AppDbContext db, IWarehouseContext warehouse)
{
    private const string Cancelled = "CANCELLED";

    /// <summary>
    /// Weight and volume come from the SKU master, not from the shipment.
    ///
    /// <c>DOC_SHIPMENT_STOP.TOTALWEIGHT</c>, <c>TOTALCUBE</c> and
    /// <c>TOTALORDER</c> are null on every row in this database, as are
    /// <c>DOC_SHIPMENT_DETAIL.OUTWEIGHT</c> and the line-level <c>GROSSWGT</c>
    /// and <c>CUBE</c>. What is populated is the quantity shipped and the
    /// standard weight per unit on <c>MST_SKU</c>, so the figure is derived:
    /// quantity times the standard weight, summed.
    ///
    /// That is a real number rather than a stored one, and it will disagree with
    /// a catch-weight item whose actual weight was recorded elsewhere. When the
    /// WMS starts writing the line weights, this should prefer them and fall
    /// back to the standard — but preferring a column that is null everywhere
    /// would just produce zeroes today.
    ///
    /// <c>COLLATE</c> on the SKU join is not optional: <c>MST_SKU.SKU</c> and
    /// <c>DOC_SHIPMENT_DETAIL_LINE.SKU</c> carry different collations, and
    /// SQL Server refuses the comparison without it.
    /// </summary>
    private const string StopTotalsSql = """
        SELECT  Boxes  = ISNULL(SUM(l.SHIPMENTQTY), 0),
                Weight = ISNULL(SUM(l.SHIPMENTQTY * k.STDGROSSWGT), 0),
                Cube   = ISNULL(SUM(l.SHIPMENTQTY * k.STDCUBE), 0)
        FROM dbo.DOC_SHIPMENT_DETAIL d
        JOIN dbo.DOC_SHIPMENT_DETAIL_LINE l
             ON  l.WHSEID = d.WHSEID
             AND l.SHIPMENTKEY = d.SHIPMENTKEY
             AND l.SHIPMENTDETAILID = d.SHIPMENTDETAILID
        LEFT JOIN dbo.MST_SKU k
             ON  k.SKU COLLATE DATABASE_DEFAULT = l.SKU COLLATE DATABASE_DEFAULT
        WHERE d.WHSEID = s.WHSEID
          AND d.SHIPMENTKEY = s.SHIPMENTKEY
          AND d.SHIPMENTSTOPID = s.SHIPMENTSTOPID
          AND d.STATUS <> 'CANCELLED'
        """;

    /// <summary>
    /// The stops of one or more shipments, already shaped as the client's
    /// <c>ManifestStop</c>.
    ///
    /// Raw SQL because the aggregate above has to be a CROSS APPLY and the SKU
    /// join needs an explicit collation — neither is expressible in LINQ without
    /// giving up the guarantee that the totals are not multiplied.
    /// </summary>
    public async Task<List<ManifestStop>> StopsAsync(
        IReadOnlyCollection<string> shipmentKeys, CancellationToken ct = default)
    {
        if (shipmentKeys.Count == 0) return [];

        // `$$` so that {0} and {1} stay literal for SqlQueryRaw's parameter
        // placeholders, and only {{StopTotalsSql}} is interpolated.
        var rows = await db.Database
            .SqlQueryRaw<StopRow>(
                $$"""
                 SELECT  ShipmentKey  = s.SHIPMENTKEY,
                         StopId       = s.SHIPMENTSTOPID,
                         StopSeq      = s.STOPSEQ,
                         Customer     = ISNULL(s.SHIPTONAME, ''),
                         Address      = ISNULL(s.ADDRESS1, ''),
                         DeliverTo    = ISNULL(s.DELIVERTO, ''),
                         Latitude     = s.LATITUDE,
                         Longitude    = s.LONGITUDE,
                         Cod          = ISNULL(s.CODAMOUNT, 0),
                         Status       = ISNULL(s.DELIVERY_STATUS, s.STATUS),
                         WarehouseCode= s.WHSEID,
                         OrderKey     = ISNULL(o.ORDERKEY, ''),
                         Zone         = ISNULL(o.ZONE, ''),
                         DueDate      = o.REQUIREDDELIVERYDATE,
                         Boxes        = t.Boxes,
                         Weight       = t.Weight,
                         Cube         = t.Cube
                 FROM dbo.DOC_SHIPMENT_STOP s
                 CROSS APPLY ({{StopTotalsSql}}) t
                 OUTER APPLY (
                     /* The order delivered at this stop. One today; if the
                        schema's 1:N ever happens the lowest detail id is shown
                        and the rest are not lost, they are simply not
                        representable in a DTO with a single doNo. */
                     SELECT TOP (1) d2.ORDERKEY, d2.ZONE, d2.REQUIREDDELIVERYDATE
                     FROM dbo.DOC_SHIPMENT_DETAIL d2
                     WHERE d2.WHSEID = s.WHSEID
                       AND d2.SHIPMENTKEY = s.SHIPMENTKEY
                       AND d2.SHIPMENTSTOPID = s.SHIPMENTSTOPID
                       AND d2.STATUS <> 'CANCELLED'
                     ORDER BY d2.SHIPMENTDETAILID
                 ) o
                 WHERE s.WHSEID = {0}
                   AND s.SHIPMENTKEY IN (SELECT value FROM STRING_SPLIT({1}, ','))
                 ORDER BY s.SHIPMENTKEY, s.STOPSEQ
                 """,
                warehouse.CurrentWarehouseId,
                string.Join(',', shipmentKeys))
            .ToListAsync(ct);

        return [.. rows.Select(ToStop)];
    }

    private static ManifestStop ToStop(StopRow r) => new()
    {
        Id = DocumentIdentity.StopId(r.ShipmentKey, r.StopId),
        DoNo = r.OrderKey,
        // The ใบปิดบรรทุก this drop rides on — see ManifestStop.SoNo.
        SoNo = r.ShipmentKey,
        // No source: DOC_DO_PICKHEADER is empty in this database. Left blank
        // rather than derived from the order number, which would look like a
        // real pick reference and match nothing.
        PickNo = "",
        PickDate = "",
        WarehouseCode = r.WarehouseCode,
        DeliveryZoneId = r.Zone == "" ? "" : $"zone-{r.Zone}",
        Customer = r.Customer,
        Address = r.Address,
        DeliverTo = r.DeliverTo,
        Boxes = (int)r.Boxes,
        Weight = (double)r.Weight,
        Cbm = (double)r.Cube,
        Cod = (double)r.Cod,
        DueDate = r.DueDate?.ToString("yyyy-MM-dd") ?? "",
        Status = MapStopStatus(r.Status),
        // Both or neither — CK_SHIPMENT_STOP_LATLNG guarantees it. An empty
        // array is the honest reading of "no coordinates recorded"; [0,0] would
        // put the drop in the Gulf of Guinea.
        Position = r.Latitude is null || r.Longitude is null
            ? []
            : [(double)r.Latitude, (double)r.Longitude],
    };

    /// <summary>
    /// The stop statuses the warehouse writes are not the ones the client draws.
    /// Anything unrecognised reads as pending rather than throwing: a status
    /// nobody has taught this mapper about is a display problem, not a reason to
    /// fail the whole list.
    /// </summary>
    private static string MapStopStatus(string? status) => status?.ToUpperInvariant() switch
    {
        "DELIVERED" => "delivered",
        "PARTIAL" => "partial",
        "RETURNED" or "REJECTED" => "returned",
        _ => "pending",
    };

    private sealed record StopRow(
        string ShipmentKey, int StopId, int StopSeq,
        string Customer, string Address, string DeliverTo,
        decimal? Latitude, decimal? Longitude, decimal Cod,
        string? Status, string WarehouseCode,
        string OrderKey, string Zone, DateTime? DueDate,
        decimal Boxes, decimal Weight, decimal Cube);

    // ── ใบปิดบรรทุก · manifests ────────────────────────────────────────────

    public async Task<List<Manifest>> ManifestsAsync(CancellationToken ct = default)
    {
        var whse = warehouse.CurrentWarehouseId;

        var headers = await db.Set<ShipmentRow>()
            .AsNoTracking()
            .Where(s => s.WhseId == whse && s.Status != ShipmentStatus.Deleted)
            .OrderByDescending(s => s.ShipmentKey)
            .ToListAsync(ct);

        return await WithStops(headers, ct);
    }

    /// <summary>
    /// One manifest by its number.
    ///
    /// The number is globally unique, so it could be found without the
    /// warehouse — but the query is scoped anyway. A document belonging to
    /// another site must read as absent, not as forbidden: telling a caller that
    /// MN-202608-0040 exists somewhere they cannot see is itself a disclosure.
    /// </summary>
    public async Task<Manifest?> ManifestAsync(string manifestNo, CancellationToken ct = default)
    {
        var whse = warehouse.CurrentWarehouseId;

        var header = await db.Set<ShipmentRow>()
            .AsNoTracking()
            .FirstOrDefaultAsync(s => s.WhseId == whse && s.ShipmentKey == manifestNo, ct);

        if (header is null) return null;
        return (await WithStops([header], ct)).SingleOrDefault();
    }

    private async Task<List<Manifest>> WithStops(List<ShipmentRow> headers, CancellationToken ct)
    {
        if (headers.Count == 0) return [];

        var stops = await StopsAsync([.. headers.Select(h => h.ShipmentKey)], ct);
        var byShipment = stops
            .GroupBy(s => s.SoNo)
            .ToDictionary(g => g.Key, g => g.ToList());

        // Named from the masters the shipment points at, so the document reads
        // the way it did when it was in memory rather than as a row of keys.
        var routes = await db.Routes.AsNoTracking()
            .ToDictionaryAsync(r => r.Route, r => r.Name, ct);
        var carriers = await db.Transporters.AsNoTracking()
            .ToDictionaryAsync(t => t.TransporterKey, t => t.Name, ct);

        return [.. headers.Select(h => ToManifest(h, byShipment.GetValueOrDefault(h.ShipmentKey, []), routes, carriers))];
    }

    private static Manifest ToManifest(
        ShipmentRow r, List<ManifestStop> stops,
        Dictionary<string, string> routes, Dictionary<string, string> carriers) => new()
    {
        Id = r.ShipmentKey,
        ManifestNo = r.ShipmentKey,
        Status = r.Status.ToLowerInvariant(),
        ClosedAt = Iso(r.ShipmentDate ?? r.AddDate),
        WarehouseCode = r.WhseId,
        CreatedBy = r.AddWho ?? "",
        ConfirmedAt = r.ConfirmDate is null ? null : Iso(r.ConfirmDate.Value),
        DeliveryDate = r.DeliveryDate?.ToString("yyyy-MM-dd") ?? "",
        ParentId = r.ParentShipmentKey,
        SentAt = r.SentDate is null ? null : Iso(r.SentDate.Value),
        StatusMessage = r.StatusMessage,
        CancelReason = r.CancelReason,
        DriverId = r.DriverKey ?? "",
        DriverName = r.DriverName ?? "",
        DriverPhone = r.DriverMobile ?? "",
        PlateHead = r.LicensePlate ?? "",
        PlateTrailer = r.TrailerId ?? "",
        Vehicle = "6-wheel",
        AssistantCount = r.AssistantCount ?? 0,
        MaxPayloadKg = (double)(r.MaxWeight ?? 0),
        MaxVolumeCbm = (double)(r.MaxCube ?? 0),
        CarrierId = r.TransporterKey ?? "",
        Carrier = r.TransporterKey is null ? "" : carriers.GetValueOrDefault(r.TransporterKey, ""),
        RouteId = r.Route is null ? "" : $"rt-{r.Route}",
        RouteCode = r.Route ?? "",
        RouteName = r.Route is null ? "" : routes.GetValueOrDefault(r.Route, ""),
        // MST_WHSE holds no coordinates, so the origin has a name and no point.
        Origin = new GeoPoint(r.WhseId, []),
        Dock = r.Door ?? "",
        SealNo = r.SealNo ?? "",
        FreightCost = (double)((r.TripPrice ?? 0) + (r.PriceAdd ?? 0) - (r.PriceDeduct ?? 0)),
        Pricing = new FreightPricing
        {
            TripPrice = (double)(r.TripPrice ?? 0),
            PriceAdd = (double)(r.PriceAdd ?? 0),
            PriceDeduct = (double)(r.PriceDeduct ?? 0),
            FreightNote = r.FreightNote ?? "",
        },
        Colour = Palette.RouteColour(Math.Abs(r.ShipmentKey.GetHashCode())),
        Stops = stops,
    };

    // ── แผนขนส่ง · plans ───────────────────────────────────────────────────

    public async Task<List<TransportPlan>> PlansAsync(CancellationToken ct = default)
    {
        var whse = warehouse.CurrentWarehouseId;

        var plans = await db.Set<TransportPlanRow>()
            .AsNoTracking()
            .Where(p => p.WhseId == whse)
            .OrderByDescending(p => p.PlanKey)
            .ToListAsync(ct);

        if (plans.Count == 0) return [];

        var routes = await db.Routes.AsNoTracking()
            .ToDictionaryAsync(r => r.Route, r => r.Name, ct);

        // A plan's contents are its lines, which name orders rather than stops:
        // the stops only exist once a manifest has been cut. Read from the order
        // table so a draft plan can show what it is holding.
        var planKeys = plans.Select(p => p.PlanKey).ToList();
        var lines = await (
            from l in db.Set<TransportPlanLineRow>().AsNoTracking()
            join o in db.DeliveryOrders.AsNoTracking()
                 on new { l.WhseId, l.OrderKey } equals new { o.WhseId, o.OrderKey }
            where l.WhseId == whse && planKeys.Contains(l.PlanKey) && l.Status != Cancelled
            select new { l.PlanKey, o.OrderKey, o.CompanyName, o.ShipTo, o.Zone, o.DeliveryDate })
            .ToListAsync(ct);

        var byPlan = lines.GroupBy(l => l.PlanKey).ToDictionary(g => g.Key, g => g.ToList());

        return [.. plans.Select(p => new TransportPlan
        {
            Id = p.PlanKey,
            PlanNo = p.PlanKey,
            Status = p.Status.ToLowerInvariant(),
            CreatedAt = Iso(p.AddDate),
            CreatedBy = p.AddWho ?? "",
            WarehouseCode = p.WhseId,
            DeliveryDate = p.DeliveryDate.ToString("yyyy-MM-dd"),
            RouteId = p.Route is null ? "" : $"rt-{p.Route}",
            RouteCode = p.Route ?? "",
            RouteName = p.Route is null ? "" : routes.GetValueOrDefault(p.Route, ""),
            Note = p.Notes ?? "",
            ManifestId = p.ShipmentKey,
            ManifestNo = p.ShipmentKey,
            Stops = [.. byPlan.GetValueOrDefault(p.PlanKey, []).Select(l => new ManifestStop
            {
                Id = l.OrderKey,
                DoNo = l.OrderKey,
                SoNo = "",
                PickNo = "",
                PickDate = "",
                WarehouseCode = p.WhseId,
                DeliveryZoneId = l.Zone is null ? "" : $"zone-{l.Zone}",
                Customer = l.CompanyName ?? "",
                Address = l.ShipTo,
                DueDate = l.DeliveryDate?.ToString("yyyy-MM-dd") ?? "",
                Position = [],
            })],
        })];
    }

    public async Task<TransportPlan?> PlanAsync(string planNo, CancellationToken ct = default) =>
        (await PlansAsync(ct)).FirstOrDefault(p => p.PlanNo == planNo);

    private static string Iso(DateTime value) =>
        DateTime.SpecifyKind(value, DateTimeKind.Utc).ToString("yyyy-MM-ddTHH:mm:ss.fffZ");
}
