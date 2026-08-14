using Mammod.Data;
using Mammod.Models;
using Microsoft.EntityFrameworkCore;

namespace Mammod.Database;

/// <summary>
/// Where a list of master records comes from.
///
/// With a connection string configured, the lists are read from <c>MMDEV</c>.
/// Without one, they come from the in-memory seed exactly as before, so the
/// project still runs with nothing installed but the .NET SDK — which is what
/// the smoke tests and the frontend fixtures rely on.
///
/// <b>Reads only.</b> Create and update still go to <see cref="TmsStore"/>,
/// which owns the uniqueness rules. That split is deliberate but it has a sharp
/// edge worth stating plainly: with the database on, a row created through
/// <c>POST /carriers</c> will not appear in <c>GET /carriers</c>, because the
/// two are no longer the same collection. Moving the writes across is the next
/// step, and it needs transactions to keep "an order is in one place only" true
/// when two requests arrive at once — which is why it is not bundled in here.
/// </summary>
public sealed partial class MasterQueries(
    TmsStore store,
    IServiceScopeFactory scopes,
    bool useDatabase)
{
    public bool UsesDatabase => useDatabase;

    private T FromDb<T>(Func<AppDbContext, T> read)
    {
        using var scope = scopes.CreateScope();
        return read(scope.ServiceProvider.GetRequiredService<AppDbContext>());
    }

    /// <summary>
    /// The legacy schema has no <c>active</c> flag — it has <c>STATUS</c>, upper
    /// case, and the client expects a boolean (README section 2.6). Anything that
    /// is not explicitly retired counts as active, so an unfamiliar status value
    /// shows the row rather than hiding it: a record nobody can see is a worse
    /// failure than one that should have been filtered.
    /// </summary>
    private static bool IsActive(string? status) =>
        !string.Equals(status, "INACTIVE", StringComparison.OrdinalIgnoreCase);

    public List<Warehouse> Warehouses()
    {
        if (!useDatabase) return store.ListWarehouses();

        return FromDb(db => db.Warehouses
            .Where(w => w.WhseId != null)
            .OrderBy(w => w.WhseId)
            .ToList()
            .Select(w => new Warehouse
            {
                Id = $"wh-{w.WhseId}",
                Code = w.WhseId!,
                Name = w.Name ?? w.Description ?? w.WhseId!,
                Address = w.Address1 ?? "",
                SubDistrict = w.SubDistrict ?? "",
                District = w.District ?? "",
                Province = w.Province ?? "",
                ZipCode = w.PostalCode ?? "",
                // null, not [0, 0] — the client tests for a missing pin, and the
                // origin of the Atlantic is not a warehouse in Nakhon Ratchasima.
                Position = w.Latitude is null || w.Longitude is null
                    ? null
                    : [(double)w.Latitude.Value, (double)w.Longitude.Value],
                // Rows seeded before IS_DC existed have null. Treated as a DC,
                // because the alternative hides every one of them from the origin
                // picker and a route with no origin cannot be planned at all.
                IsDC = w.IsDc ?? true,
                Active = IsActive(w.Status),
            })
            .ToList());
    }

    public List<DeliveryZone> Zones()
    {
        if (!useDatabase) return store.ListZones();

        return FromDb(db =>
        {
            var zones = db.Zones.OrderBy(z => z.ZoneKey).ToList();
            // The districts a zone covers live one table down, because the zone
            // master can hold only a single area rule (README section 2.4).
            var coverage = db.ZoneCoverage
                .ToList()
                .GroupBy(c => c.ZoneKey)
                .ToDictionary(g => g.Key,
                              g => g.Select(c => c.District)
                                    .Where(d => !string.IsNullOrWhiteSpace(d))
                                    .Distinct()
                                    .ToList());

            return zones.Select(z => new DeliveryZone
            {
                Id = $"zone-{z.ZoneKey}",
                Code = z.ZoneKey,
                Name = z.Name,
                Areas = string.Join(", ", coverage.GetValueOrDefault(z.ZoneKey, [])!),
                Province = z.Province ?? "",
                District = "",
                SubDistrict = "",
                ZipCode = "",
                Weight = (double)(z.MaxVehicleWeight ?? 0),
                WeightUnit = string.IsNullOrWhiteSpace(z.WeightUom) ? "kg" : z.WeightUom,
            }).ToList();
        });
    }

    public List<RouteMaster> Routes()
    {
        if (!useDatabase) return store.ListRoutes();

        return FromDb(db =>
        {
            var routes = db.Routes.OrderBy(r => r.Route).ToList();
            var zonesByRoute = db.RouteZones
                .OrderBy(rz => rz.Sequence)
                .ToList()
                .GroupBy(rz => rz.Route)
                .ToDictionary(g => g.Key, g => g.Select(rz => $"zone-{rz.ZoneKey}").ToList());
            var whseNames = db.Warehouses
                .Where(w => w.WhseId != null)
                .ToList()
                .ToDictionary(w => w.WhseId!, w => w.Description ?? w.WhseId!);

            return routes.Select(r => new RouteMaster
            {
                Id = $"rt-{r.Route}",
                Code = r.Route,
                Name = r.Name,
                DeliveryZoneIds = zonesByRoute.GetValueOrDefault(r.Route, []),
                // MST_WHSE holds no coordinates, so the origin has a name and an
                // empty position. GeoPoint.Position is non-nullable, and an empty
                // array is the honest reading — "no coordinates recorded" — where
                // [0, 0] would put every route's origin in the Gulf of Guinea.
                DefaultOrigin = new GeoPoint(
                    r.OriginWhseId is null ? "" : whseNames.GetValueOrDefault(r.OriginWhseId, r.OriginWhseId),
                    []),
                Colour = r.Colour ?? "",
                Active = IsActive(r.Status),
            }).ToList();
        });
    }

    public List<Carrier> Carriers()
    {
        if (!useDatabase) return store.ListCarriers();

        return FromDb(db => db.Transporters
            .OrderBy(t => t.TransporterKey)
            .ToList()
            .Select(t => new Carrier
            {
                Id = $"cr-{t.TransporterKey}",
                Code = t.TransporterKey,
                Name = t.Name,
                // The client's two values are lower case with a hyphen; the
                // database stores INHOUSE / SUBCONTRACT (README section 2.6).
                Type = string.Equals(t.Type, "INHOUSE", StringComparison.OrdinalIgnoreCase)
                    ? "in-house" : "subcontract",
                ContactName = t.ContactName ?? "",
                Phone = t.Phone ?? "",
                Email = t.Email ?? "",
                TaxId = t.TaxId ?? "",
                Active = IsActive(t.Status),
            })
            .ToList());
    }

    /// <summary>
    /// The three vehicle classes the client knows, by the database's type key.
    ///
    /// This is a closed set on the client side, not free text: it picks a truck
    /// drawing with <c>IMAGES[type]</c> and reads a label from
    /// <c>VEHICLE_LABEL[type]</c>. Hand it anything else — the Thai name held in
    /// <c>VEHICLETYPENAME</c>, or a type key nobody has mapped — and both lookups
    /// return undefined, so the truck silently disappears from the screen with no
    /// error anywhere. Passing the database's own wording straight through is
    /// exactly the bug that caused.
    /// </summary>
    private static readonly Dictionary<string, string> VehicleClasses = new(StringComparer.OrdinalIgnoreCase)
    {
        ["4W"] = "4-wheel",
        ["6W"] = "6-wheel",
        ["10W"] = "10-wheel",
    };

    /// <summary>
    /// Three sources, tried in order of how much they can be trusted.
    ///
    /// The name comes first because <c>MST_VEHICLETYPE.VEHICLETYPENAME</c> now
    /// holds these exact strings, so a database that has been set up this way
    /// needs no translation at all. The key map covers a database that has not.
    /// Capacity is the last resort: a real one will hold type keys this code has
    /// never seen, and the screen still has to draw a truck. Weight is the honest
    /// discriminator — it is what actually separates the classes — with the
    /// thresholds at the midpoints between 3,500 / 8,000 / 15,000 kg.
    /// </summary>
    private static string VehicleClass(VehicleTypeRow? type, string typeKey)
    {
        var name = type?.Name?.Trim();
        if (name is not null && VehicleClasses.ContainsValue(name)) return name;

        if (VehicleClasses.TryGetValue(typeKey, out var known)) return known;

        var weight = type?.MaxWeight ?? 0;
        return weight switch
        {
            <= 5_000 => "4-wheel",
            <= 11_000 => "6-wheel",
            _ => "10-wheel",
        };
    }

    public List<FleetVehicle> Vehicles()
    {
        if (!useDatabase) return store.ListVehicles();

        return FromDb(db =>
        {
            var types = db.VehicleTypes.ToList().ToDictionary(t => t.VehicleTypeKey);
            return db.Vehicles
                .OrderBy(v => v.VehicleKey)
                .ToList()
                .Select(v =>
                {
                    var type = types.GetValueOrDefault(v.VehicleTypeKey);
                    return new FleetVehicle
                    {
                        Id = $"v-{v.VehicleKey}",
                        Type = VehicleClass(type, v.VehicleTypeKey),
                        PlateHead = v.LicensePlate,
                        // "-" rather than empty: a rigid truck has no trailer,
                        // and the client prints this field as it stands.
                        PlateTrailer = string.IsNullOrWhiteSpace(v.PlateTrailer) ? "-" : v.PlateTrailer,
                        CarrierId = $"cr-{v.TransporterKey}",
                        // Capacity is on the type, not the truck — every 6-wheeler
                        // is assumed to carry the same as any other.
                        MaxPayloadKg = (double)(type?.MaxWeight ?? 0),
                        MaxVolumeCbm = (double)(type?.MaxCube ?? 0),
                        Active = IsActive(v.Status),
                    };
                })
                .ToList();
        });
    }

    /// <summary>
    /// Licence classes the client offers in its dropdown. Same closed-set problem
    /// as the vehicle classes: a value outside this list leaves the select with
    /// nothing highlighted, so anyone opening the driver form sees a blank where
    /// the licence should be and can save the blank back.
    /// </summary>
    private static readonly HashSet<string> LicenceClasses = ["ท.1", "ท.2", "ท.3", "ท.4"];

    private static string LicenceClass(string? value) =>
        value is not null && LicenceClasses.Contains(value.Trim()) ? value.Trim() : "ท.2";

    public List<Driver> Drivers()
    {
        if (!useDatabase) return store.ListDrivers();

        return FromDb(db => db.Drivers
            .OrderBy(d => d.DriverKey)
            .ToList()
            .Select(d => new Driver
            {
                Id = $"dr-{d.DriverKey}",
                Code = d.DriverKey,
                Name = d.Name,
                Phone = d.Mobile ?? "",
                LicenseNo = d.LicenseNo ?? "",
                LicenseType = LicenceClass(d.LicenseType),
                CarrierId = $"cr-{d.TransporterKey}",
                Active = IsActive(d.Status),
            })
            .ToList());
    }
}
