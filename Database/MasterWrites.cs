using Mammod.Data;
using Mammod.Models;
using Microsoft.EntityFrameworkCore;

namespace Mammod.Database;

/// <summary>
/// Creating and updating master records in <c>MMDEV</c>.
///
/// Until this existed, the setup screens appeared to work and did nothing: a
/// create wrote to the in-memory store while the list beside it read from the
/// database, so the new row was saved somewhere nobody was looking. Reads and
/// writes now go to the same place.
///
/// <b>The code is the record's identity here.</b> In the in-memory store an id
/// was a counter and the code was just another field, so it could be edited
/// freely. In the database the code <i>is</i> the key — <c>TRANSPORTERKEY</c>,
/// <c>ROUTE</c>, <c>TRANSPORTZONEKEY</c> — and other tables point at it. Editing
/// it would orphan every vehicle, driver and document that names it, so an
/// update that changes the code is refused with a message saying why rather
/// than quietly renaming a key half the database references.
/// </summary>
public sealed partial class MasterQueries
{
    /// <summary>
    /// Every master row is scoped to a warehouse and an owner in this schema,
    /// including ones that are really company-wide, like a delivery zone. The
    /// setup screens have no field for either — nobody picks a warehouse when
    /// naming a transport zone — so new rows are filed under these.
    ///
    /// A single-tenant assumption, and the right one to make loudly rather than
    /// quietly: the moment a second owner shares this database it is wrong, and
    /// it should be wrong somewhere findable.
    /// </summary>
    private const string SeedWarehouse = "WSK";
    private const string SeedOwner = "MAMMOD";

    private static string Who => "api";

    private T InDb<T>(Func<AppDbContext, T> work)
    {
        using var scope = scopes.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var result = work(db);
        db.SaveChanges();
        return result;
    }

    private static string Key(string id, string prefix) =>
        id.StartsWith(prefix, StringComparison.OrdinalIgnoreCase) ? id[prefix.Length..] : id;

    private static string RequireCode(string? code, string what)
    {
        var trimmed = code?.Trim() ?? "";
        if (trimmed.Length == 0) throw new DomainException($"ต้องระบุ{what}");
        return trimmed;
    }

    /// <summary>
    /// A code change on update is a primary-key change, and the key is what the
    /// rest of the database uses to find this row. Renaming it here would leave
    /// the children pointing at nothing.
    /// </summary>
    private static void AssertCodeUnchanged(string existing, string incoming, string what)
    {
        if (!string.Equals(existing.Trim(), incoming.Trim(), StringComparison.OrdinalIgnoreCase))
            throw new DomainException(
                $"เปลี่ยน{what}จาก {existing} เป็น {incoming} ไม่ได้ — รหัสนี้เป็นคีย์ที่ตารางอื่นอ้างถึงอยู่ " +
                "ถ้าต้องการรหัสใหม่ ให้สร้างรายการใหม่แล้วปิดรายการเดิม");
    }

    private static string Flag(bool active) => active ? "ACTIVE" : "INACTIVE";

    // ── ผู้ให้บริการขนส่ง ───────────────────────────────────────────────────

    public Carrier CreateCarrier(Carrier input)
    {
        if (!useDatabase) return store.CreateCarrier(input);
        var code = RequireCode(input.Code, "รหัสผู้ให้บริการ");

        return InDb(db =>
        {
            if (db.Transporters.Any(t => t.TransporterKey == code))
                throw new DomainException($"รหัสผู้ให้บริการ {code} ถูกใช้แล้ว");

            db.Add(new TransporterRow
            {
                TransporterKey = code,
                Name = input.Name,
                Type = input.Type == "in-house" ? "INHOUSE" : "SUBCONTRACT",
                ContactName = input.ContactName,
                Phone = input.Phone,
                Email = input.Email,
                TaxId = input.TaxId,
                Status = Flag(input.Active),
            });
            return input with { Id = $"cr-{code}", Code = code };
        });
    }

    public Carrier UpdateCarrier(string id, Carrier input)
    {
        if (!useDatabase) return store.UpdateCarrier(id, input);
        var key = Key(id, "cr-");

        return InDb(db =>
        {
            var row = db.Transporters.AsTracking().FirstOrDefault(t => t.TransporterKey == key)
                ?? throw DomainException.NotFound("ไม่พบผู้ให้บริการนี้");
            AssertCodeUnchanged(row.TransporterKey, input.Code, "รหัสผู้ให้บริการ");

            row.Name = input.Name;
            row.Type = input.Type == "in-house" ? "INHOUSE" : "SUBCONTRACT";
            row.ContactName = input.ContactName;
            row.Phone = input.Phone;
            row.Email = input.Email;
            row.TaxId = input.TaxId;
            row.Status = Flag(input.Active);
            return input with { Id = id, Code = key };
        });
    }

    // ── รถ ──────────────────────────────────────────────────────────────────

    public FleetVehicle CreateVehicle(FleetVehicle input)
    {
        if (!useDatabase) return store.CreateVehicle(input);
        var plate = RequireCode(input.PlateHead, "ทะเบียนรถ");

        return InDb(db =>
        {
            AssertPlateFree(db, plate, null);

            // No code on the form, so the key is generated. Numbered from the
            // highest existing rather than a count, so deleting a row cannot make
            // the next create collide with one that is still there.
            var next = db.Vehicles
                .Where(v => v.VehicleKey.StartsWith("VH-"))
                .ToList()
                .Select(v => int.TryParse(v.VehicleKey[3..], out var n) ? n : 0)
                .DefaultIfEmpty(0)
                .Max() + 1;
            var key = $"VH-{next:000}";

            db.Add(new VehicleRow
            {
                VehicleKey = key,
                TransporterKey = Key(input.CarrierId, "cr-"),
                VehicleTypeKey = TypeKeyFor(input.Type),
                LicensePlate = plate,
                PlateTrailer = input.PlateTrailer == "-" ? null : input.PlateTrailer,
                Status = Flag(input.Active),
            });
            return input with { Id = $"v-{key}" };
        });
    }

    public FleetVehicle UpdateVehicle(string id, FleetVehicle input)
    {
        if (!useDatabase) return store.UpdateVehicle(id, input);
        var key = Key(id, "v-");
        var plate = RequireCode(input.PlateHead, "ทะเบียนรถ");

        return InDb(db =>
        {
            var row = db.Vehicles.AsTracking().FirstOrDefault(v => v.VehicleKey == key)
                ?? throw DomainException.NotFound("ไม่พบรถคันนี้");
            AssertPlateFree(db, plate, key);

            row.TransporterKey = Key(input.CarrierId, "cr-");
            row.VehicleTypeKey = TypeKeyFor(input.Type);
            row.LicensePlate = plate;
            row.PlateTrailer = input.PlateTrailer == "-" ? null : input.PlateTrailer;
            row.Status = Flag(input.Active);
            return input with { Id = id };
        });
    }

    /// <summary>A plate identifies the truck on the road, so two records must never share one.</summary>
    private static void AssertPlateFree(AppDbContext db, string plate, string? exceptKey)
    {
        var clash = db.Vehicles
            .Where(v => v.LicensePlate == plate && (exceptKey == null || v.VehicleKey != exceptKey))
            .Select(v => v.VehicleKey)
            .FirstOrDefault();
        if (clash is not null) throw new DomainException($"ทะเบียน {plate} ถูกใช้แล้ว");
    }

    /// <summary>The client's class back to the database's type key — the inverse of VehicleClass.</summary>
    private static string TypeKeyFor(string vehicleClass) => vehicleClass switch
    {
        "4-wheel" => "4W",
        "10-wheel" => "10W",
        _ => "6W",
    };

    // ── พนักงานขับรถ ────────────────────────────────────────────────────────

    public Driver CreateDriver(Driver input)
    {
        if (!useDatabase) return store.CreateDriver(input);
        var code = RequireCode(input.Code, "รหัสพนักงานขับรถ");

        return InDb(db =>
        {
            if (db.Drivers.Any(d => d.DriverKey == code))
                throw new DomainException($"รหัสพนักงานขับรถ {code} ถูกใช้แล้ว");

            db.Add(new DriverRow
            {
                DriverKey = code,
                TransporterKey = Key(input.CarrierId, "cr-"),
                Name = input.Name,
                Mobile = input.Phone,
                LicenseNo = input.LicenseNo,
                LicenseType = LicenceClass(input.LicenseType),
                Status = Flag(input.Active),
            });
            return input with { Id = $"dr-{code}", Code = code };
        });
    }

    public Driver UpdateDriver(string id, Driver input)
    {
        if (!useDatabase) return store.UpdateDriver(id, input);
        var key = Key(id, "dr-");

        return InDb(db =>
        {
            var row = db.Drivers.AsTracking().FirstOrDefault(d => d.DriverKey == key)
                ?? throw DomainException.NotFound("ไม่พบพนักงานขับรถคนนี้");
            AssertCodeUnchanged(row.DriverKey, input.Code, "รหัสพนักงานขับรถ");

            row.TransporterKey = Key(input.CarrierId, "cr-");
            row.Name = input.Name;
            row.Mobile = input.Phone;
            row.LicenseNo = input.LicenseNo;
            row.LicenseType = LicenceClass(input.LicenseType);
            row.Status = Flag(input.Active);
            return input with { Id = id, Code = key };
        });
    }

    // ── โซนจัดส่ง ───────────────────────────────────────────────────────────

    /// <summary>
    /// Districts arrive as one comma-separated string because that is the shape
    /// the form posts. They are stored one row per district in
    /// <c>MST_ZONE_COVERAGE</c>, which is the only shape that can answer "which
    /// zone is this address in" — see 01-new-tables.sql section 3.
    /// </summary>
    private static List<string> Districts(string? areas) =>
        [.. (areas ?? "").Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Distinct()];

    public DeliveryZone CreateZone(DeliveryZone input)
    {
        if (!useDatabase) return store.CreateZone(input);
        var code = RequireCode(input.Code, "รหัสโซน");

        return InDb(db =>
        {
            if (db.Zones.Any(z => z.ZoneKey == code))
                throw new DomainException($"รหัสโซน {code} ถูกใช้แล้ว");
            AssertDistrictsFree(db, input, null);

            db.Add(new ZoneRow
            {
                WhseId = SeedWarehouse, OwnerKey = SeedOwner, ZoneKey = code,
                Name = input.Name, Province = input.Province, Status = "ACTIVE",
                MaxVehicleWeight = (decimal)input.Weight,
                WeightUom = input.WeightUnit,
                AddDate = DateTime.Now,
            });
            AddCoverage(db, code, input);
            return input with { Id = $"zone-{code}", Code = code };
        });
    }

    public DeliveryZone UpdateZone(string id, DeliveryZone input)
    {
        if (!useDatabase) return store.UpdateZone(id, input);
        var key = Key(id, "zone-");

        return InDb(db =>
        {
            var row = db.Zones.AsTracking().FirstOrDefault(z => z.ZoneKey == key)
                ?? throw DomainException.NotFound("ไม่พบโซนนี้");
            AssertCodeUnchanged(row.ZoneKey, input.Code, "รหัสโซน");
            AssertDistrictsFree(db, input, key);

            row.Name = input.Name;
            row.Province = input.Province;
            row.MaxVehicleWeight = (decimal)input.Weight;
            row.WeightUom = input.WeightUnit;

            // Coverage is replaced rather than merged: the form posts the whole
            // list every time, so a district missing from it was removed on
            // purpose, and merging would make removal impossible.
            db.ZoneCoverage.RemoveRange(db.ZoneCoverage.AsTracking().Where(c => c.ZoneKey == key));
            AddCoverage(db, key, input);
            return input with { Id = id, Code = key };
        });
    }

    private static void AddCoverage(AppDbContext db, string zoneKey, DeliveryZone input)
    {
        foreach (var district in Districts(input.Areas))
        {
            db.Add(new ZoneCoverageRow
            {
                WhseId = SeedWarehouse,
                OwnerKey = SeedOwner,
                ZoneKey = zoneKey,
                Province = input.Province,
                District = district,
                Status = "ACTIVE",
                AddDate = DateTime.Now,
            });
        }
    }

    /// <summary>
    /// One district belongs to one zone. Checked here rather than left to
    /// <c>UX_MST_ZONE_COVERAGE_AREA</c> so the message names the district and the
    /// zone already holding it, instead of surfacing a unique-index violation.
    /// </summary>
    private static void AssertDistrictsFree(AppDbContext db, DeliveryZone input, string? exceptKey)
    {
        var wanted = Districts(input.Areas);
        if (wanted.Count == 0) return;

        var taken = db.ZoneCoverage
            .Where(c => wanted.Contains(c.District!) && (exceptKey == null || c.ZoneKey != exceptKey))
            .Select(c => new { c.District, c.ZoneKey })
            .FirstOrDefault();

        if (taken is not null)
            throw new DomainException($"{taken.District} อยู่ในโซน {taken.ZoneKey} แล้ว");
    }

    // ── สายส่ง ──────────────────────────────────────────────────────────────

    public RouteMaster CreateRoute(RouteMaster input)
    {
        if (!useDatabase) return store.CreateRoute(input);
        var code = RequireCode(input.Code, "รหัสสายส่ง");

        return InDb(db =>
        {
            if (db.Routes.Any(r => r.Route == code))
                throw new DomainException($"รหัสสายส่ง {code} ถูกใช้แล้ว");

            db.Add(new RouteRow
            {
                Route = code,
                Name = input.Name,
                OriginWhseId = OriginKey(db, input),
                Colour = input.Colour,
                Status = Flag(input.Active),
            });
            AddRouteZones(db, code, input);
            return input with { Id = $"rt-{code}", Code = code };
        });
    }

    public RouteMaster UpdateRoute(string id, RouteMaster input)
    {
        if (!useDatabase) return store.UpdateRoute(id, input);
        var key = Key(id, "rt-");

        return InDb(db =>
        {
            var row = db.Routes.AsTracking().FirstOrDefault(r => r.Route == key)
                ?? throw DomainException.NotFound("ไม่พบสายส่งนี้");
            AssertCodeUnchanged(row.Route, input.Code, "รหัสสายส่ง");

            row.Name = input.Name;
            row.OriginWhseId = OriginKey(db, input);
            row.Colour = input.Colour;
            row.Status = Flag(input.Active);

            db.RouteZones.RemoveRange(db.RouteZones.AsTracking().Where(rz => rz.Route == key));
            AddRouteZones(db, key, input);
            return input with { Id = id, Code = key };
        });
    }

    private static void AddRouteZones(AppDbContext db, string route, RouteMaster input)
    {
        var sequence = 1;
        foreach (var zoneId in input.DeliveryZoneIds)
        {
            db.Add(new RouteZoneRow
            {
                Route = route,
                WhseId = SeedWarehouse,
                OwnerKey = SeedOwner,
                ZoneKey = Key(zoneId, "zone-"),
                Sequence = sequence++,
                Status = "ACTIVE",
                AddDate = DateTime.Now,
            });
        }
    }

    /// <summary>
    /// The form picks an origin by name; the table stores a warehouse code. Match
    /// on the name, and fall back to null rather than inventing a code — a route
    /// with an unrecognised origin is better than one pointing at a warehouse
    /// that does not exist.
    /// </summary>
    private static string? OriginKey(AppDbContext db, RouteMaster input)
    {
        var name = input.DefaultOrigin?.Name?.Trim();
        if (string.IsNullOrEmpty(name)) return null;

        return db.Warehouses
            .Where(w => w.WhseId != null && (w.Name == name || w.Description == name || w.WhseId == name))
            .Select(w => w.WhseId)
            .FirstOrDefault();
    }

    // ── คลัง ────────────────────────────────────────────────────────────────

    public Warehouse CreateWarehouse(Warehouse input)
    {
        if (!useDatabase) return store.CreateWarehouse(input);
        var code = RequireCode(input.Code, "รหัสคลัง");

        return InDb(db =>
        {
            var clash = db.Warehouses.FirstOrDefault(w => w.WhseId == code);
            if (clash is not null)
                throw new DomainException($"รหัสคลัง {code} ถูกใช้กับ {clash.Name ?? clash.Description} แล้ว");

            db.Add(Fill(new WhseRow { WhseId = code, AddDate = DateTime.Now }, input));
            return input with { Id = $"wh-{code}", Code = code };
        });
    }

    public Warehouse UpdateWarehouse(string id, Warehouse input)
    {
        if (!useDatabase) return store.UpdateWarehouse(id, input);
        var key = Key(id, "wh-");

        return InDb(db =>
        {
            var row = db.Warehouses.AsTracking().FirstOrDefault(w => w.WhseId == key)
                ?? throw DomainException.NotFound("ไม่พบคลังนี้");
            AssertCodeUnchanged(row.WhseId ?? "", input.Code, "รหัสคลัง");

            Fill(row, input);
            return input with { Id = id, Code = key };
        });
    }

    private static WhseRow Fill(WhseRow row, Warehouse input)
    {
        row.Name = input.Name;
        // `description` predates WHSENAME and is what the legacy screens read.
        // Kept in step so a row written here is not blank in the old system.
        row.Description = input.Name;
        row.Address1 = input.Address;
        row.SubDistrict = input.SubDistrict;
        row.District = input.District;
        row.Province = input.Province;
        row.PostalCode = input.ZipCode;
        // Coordinates arrive as [lat, lng]; anything else is treated as absent
        // rather than half-read, because half a coordinate maps to the wrong place.
        row.Latitude = input.Position is [var lat, _] ? (decimal)lat : null;
        row.Longitude = input.Position is [_, var lng] ? (decimal)lng : null;
        row.IsDc = input.IsDC;
        row.Status = input.Active ? "ACTIVE" : "INACTIVE";
        // CK_site_type accepts only 'E' or 'S'. 'S' is the one every seeded row
        // uses; no code table anywhere says what either letter means.
        row.Type ??= "S";
        return row;
    }
}
