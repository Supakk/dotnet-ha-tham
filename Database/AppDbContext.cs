using Microsoft.EntityFrameworkCore;

namespace Mammod.Database;

/// <summary>
/// Read access to <c>MMDEV</c>, the SQL Server database built by
/// <c>docs/data-model/build-local-db.ps1</c>.
///
/// Only the tables the API reads today are mapped. A DbContext that mirrored
/// all 61 would be mostly dead weight, and every entity here has to be checked
/// against the real column names by hand — the ER diagram gets several of them
/// wrong (README section 0), so guessing is not an option.
///
/// Everything is <c>AsNoTracking</c> by default: this context answers GETs. The
/// writes still go through the in-memory stores, which own the business rules,
/// and moving those across is a separate job that needs transactions to keep
/// "an order is in one place only" true under concurrent requests.
///
/// Names are the legacy ones — <c>WHSEID</c>, <c>TRANSPORTERKEY</c>,
/// <c>PUTAWAYZONE</c> — spelled exactly as the database has them rather than
/// tidied up. A prettier name here would only move the moment of confusion to
/// whoever compares this file against the table.
/// </summary>
public sealed class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<WhseRow> Warehouses => Set<WhseRow>();
    public DbSet<ZoneRow> Zones => Set<ZoneRow>();
    public DbSet<ZoneCoverageRow> ZoneCoverage => Set<ZoneCoverageRow>();
    public DbSet<RouteRow> Routes => Set<RouteRow>();
    public DbSet<RouteZoneRow> RouteZones => Set<RouteZoneRow>();
    public DbSet<TransporterRow> Transporters => Set<TransporterRow>();
    public DbSet<VehicleRow> Vehicles => Set<VehicleRow>();
    public DbSet<VehicleTypeRow> VehicleTypes => Set<VehicleTypeRow>();
    public DbSet<DriverRow> Drivers => Set<DriverRow>();
    public DbSet<CustomerRow> Customers => Set<CustomerRow>();
    public DbSet<DeliveryOrderRow> DeliveryOrders => Set<DeliveryOrderRow>();

    protected override void OnConfiguring(DbContextOptionsBuilder builder) =>
        // A read-only context that tracked entities would spend memory building
        // change-tracking state nothing ever reads.
        builder.UseQueryTrackingBehavior(QueryTrackingBehavior.NoTracking);

    protected override void OnModelCreating(ModelBuilder b)
    {
        b.Entity<WhseRow>(e =>
        {
            e.ToTable("MST_WHSE");
            // PK_site is on SERIALKEY, not on WHSEID — the warehouse code is
            // nullable and not unique in the base schema (README section 2.2).
            e.HasKey(x => x.SerialKey);
            e.Property(x => x.SerialKey).HasColumnName("SERIALKEY");
            e.Property(x => x.WhseId).HasColumnName("WHSEID");
            e.Property(x => x.Description).HasColumnName("description");
            // Added by 02-alter-existing.sql section C — the base table holds a
            // code and a description and nothing the setup form asks for.
            e.Property(x => x.Name).HasColumnName("WHSENAME");
            e.Property(x => x.Address1).HasColumnName("ADDRESS1");
            e.Property(x => x.SubDistrict).HasColumnName("SUBDISTRICT");
            e.Property(x => x.District).HasColumnName("DISTRICT");
            e.Property(x => x.Province).HasColumnName("PROVINCE");
            e.Property(x => x.PostalCode).HasColumnName("POSTALCODE");
            e.Property(x => x.Latitude).HasColumnName("LATITUDE");
            e.Property(x => x.Longitude).HasColumnName("LONGITUDE");
            e.Property(x => x.IsDc).HasColumnName("IS_DC");
            e.Property(x => x.Status).HasColumnName("STATUS");
            e.Property(x => x.AddDate).HasColumnName("ADDDATE");
            e.Property(x => x.Type).HasColumnName("type");
        });

        b.Entity<ZoneRow>(e =>
        {
            e.ToTable("MST_TRANSPORTATIONZONE");
            e.HasKey(x => new { x.WhseId, x.OwnerKey, x.ZoneKey });
            e.Property(x => x.WhseId).HasColumnName("WHSEID");
            e.Property(x => x.OwnerKey).HasColumnName("OWNERKEY");
            e.Property(x => x.ZoneKey).HasColumnName("TRANSPORTZONEKEY");
            e.Property(x => x.Name).HasColumnName("TRANSPORTZONENAME");
            e.Property(x => x.Province).HasColumnName("PROVINCE");
            e.Property(x => x.District).HasColumnName("DISTRICT");
            e.Property(x => x.DefaultRoute).HasColumnName("DEFAULTROUTE");
            e.Property(x => x.Status).HasColumnName("STATUS");
            // Added by 02 section C: the weight limit the zone form asks for.
            e.Property(x => x.MaxVehicleWeight).HasColumnName("MAX_VEHICLE_WEIGHT");
            e.Property(x => x.WeightUom).HasColumnName("WEIGHT_UOM");
            e.Property(x => x.AddDate).HasColumnName("ADDDATE");
        });

        b.Entity<ZoneCoverageRow>(e =>
        {
            e.ToTable("MST_ZONE_COVERAGE");
            e.HasKey(x => x.SerialKey);
            e.Property(x => x.SerialKey).HasColumnName("SERIALKEY");
            e.Property(x => x.WhseId).HasColumnName("WHSEID");
            e.Property(x => x.OwnerKey).HasColumnName("OWNERKEY");
            e.Property(x => x.ZoneKey).HasColumnName("TRANSPORTZONEKEY");
            e.Property(x => x.Province).HasColumnName("PROVINCE");
            e.Property(x => x.District).HasColumnName("DISTRICT");
            e.Property(x => x.Status).HasColumnName("STATUS");
            e.Property(x => x.AddDate).HasColumnName("ADDDATE");
        });

        b.Entity<RouteRow>(e =>
        {
            e.ToTable("MST_ROUTE");
            e.HasKey(x => x.Route);
            e.Property(x => x.Route).HasColumnName("ROUTE");
            e.Property(x => x.Name).HasColumnName("ROUTENAME");
            e.Property(x => x.OriginWhseId).HasColumnName("ORIGIN_WHSEID");
            e.Property(x => x.Colour).HasColumnName("COLOURHEX");
            e.Property(x => x.Status).HasColumnName("STATUS");
        });

        b.Entity<RouteZoneRow>(e =>
        {
            e.ToTable("MST_ROUTE_ZONE");
            e.HasKey(x => x.SerialKey);
            e.Property(x => x.SerialKey).HasColumnName("SERIALKEY");
            e.Property(x => x.Route).HasColumnName("ROUTE");
            e.Property(x => x.WhseId).HasColumnName("WHSEID");
            e.Property(x => x.OwnerKey).HasColumnName("OWNERKEY");
            e.Property(x => x.ZoneKey).HasColumnName("TRANSPORTZONEKEY");
            e.Property(x => x.Sequence).HasColumnName("SEQUENCE");
            e.Property(x => x.Status).HasColumnName("STATUS");
            e.Property(x => x.AddDate).HasColumnName("ADDDATE");
        });

        b.Entity<TransporterRow>(e =>
        {
            e.ToTable("MST_TRANSPORTER");
            e.HasKey(x => x.TransporterKey);
            e.Property(x => x.TransporterKey).HasColumnName("TRANSPORTERKEY");
            e.Property(x => x.Name).HasColumnName("TRANSPORTERNAME");
            e.Property(x => x.Type).HasColumnName("TRANSPORTERTYPE");
            e.Property(x => x.ContactName).HasColumnName("CONTACTNAME");
            e.Property(x => x.Phone).HasColumnName("PHONE");
            e.Property(x => x.Email).HasColumnName("EMAIL");
            e.Property(x => x.TaxId).HasColumnName("TAXID");
            e.Property(x => x.Status).HasColumnName("STATUS");
        });

        b.Entity<VehicleTypeRow>(e =>
        {
            e.ToTable("MST_VEHICLETYPE");
            e.HasKey(x => x.VehicleTypeKey);
            e.Property(x => x.VehicleTypeKey).HasColumnName("VEHICLETYPEKEY");
            e.Property(x => x.Name).HasColumnName("VEHICLETYPENAME");
            e.Property(x => x.MaxWeight).HasColumnName("MAXWEIGHT");
            e.Property(x => x.MaxCube).HasColumnName("MAXCUBE");
        });

        b.Entity<VehicleRow>(e =>
        {
            e.ToTable("MST_VEHICLE");
            e.HasKey(x => x.VehicleKey);
            e.Property(x => x.VehicleKey).HasColumnName("VEHICLEKEY");
            e.Property(x => x.TransporterKey).HasColumnName("TRANSPORTERKEY");
            e.Property(x => x.VehicleTypeKey).HasColumnName("VEHICLETYPEKEY");
            e.Property(x => x.LicensePlate).HasColumnName("LICENSEPLATE");
            e.Property(x => x.PlateTrailer).HasColumnName("PLATE_TRAILER");
            e.Property(x => x.Status).HasColumnName("STATUS");
        });

        b.Entity<DriverRow>(e =>
        {
            e.ToTable("MST_DRIVER");
            e.HasKey(x => x.DriverKey);
            e.Property(x => x.DriverKey).HasColumnName("DRIVERKEY");
            e.Property(x => x.TransporterKey).HasColumnName("TRANSPORTERKEY");
            e.Property(x => x.Name).HasColumnName("DRIVERNAME");
            e.Property(x => x.Mobile).HasColumnName("MOBILE");
            e.Property(x => x.LicenseNo).HasColumnName("LICENSE_NO");
            e.Property(x => x.LicenseType).HasColumnName("LICENSE_TYPE");
            e.Property(x => x.Status).HasColumnName("STATUS");
        });

        b.Entity<CustomerRow>(e =>
        {
            e.ToTable("MST_CUSTOMER");
            e.HasKey(x => x.CustomerKey);
            e.Property(x => x.CustomerKey).HasColumnName("CUSTOMERKEY");
            e.Property(x => x.Name).HasColumnName("CUSTOMERNAME");
            e.Property(x => x.Address1).HasColumnName("ADDRESS1");
            e.Property(x => x.SubDistrict).HasColumnName("SUBDISTRICT");
            e.Property(x => x.District).HasColumnName("DISTRICT");
            e.Property(x => x.Province).HasColumnName("PROVINCE");
            e.Property(x => x.PostalCode).HasColumnName("POSTALCODE");
            e.Property(x => x.Latitude).HasColumnName("LATITUDE");
            e.Property(x => x.Longitude).HasColumnName("LONGITUDE");
            e.Property(x => x.ZoneKey).HasColumnName("TRANSPORTZONEKEY");
            e.Property(x => x.Route).HasColumnName("ROUTE");
        });



        b.Entity<DeliveryOrderRow>(e =>
        {
            e.ToTable("DOC_DO_HDR");
            e.HasKey(x => new { x.WhseId, x.OrderKey });
            e.Property(x => x.WhseId).HasColumnName("WHSEID");
            e.Property(x => x.OrderKey).HasColumnName("ORDERKEY");
            // The sales order this delivery came from. Named EXTERNORDERKEY
            // because it long predated there being a sales-order table to point at.
            e.Property(x => x.SoKey).HasColumnName("EXTERNORDERKEY");
            e.Property(x => x.OrderDate).HasColumnName("ORDERDATE");
            e.Property(x => x.DeliveryDate).HasColumnName("DELIVERYDATE");
            e.Property(x => x.ShipTo).HasColumnName("SHIPTO");
            e.Property(x => x.CompanyName).HasColumnName("C_COMPANY");
            e.Property(x => x.Route).HasColumnName("ROUTE");
            e.Property(x => x.Zone).HasColumnName("ZONE");
            e.Property(x => x.Status).HasColumnName("STATUS");
        });
    }
}

/* ── Row shapes ──────────────────────────────────────────────────────────────
   Plain classes, not the API records in Models/. Two reasons: the response
   shapes are a contract with the client and should not shift because a column
   was renamed, and these carry the database's own nullability, which is far
   looser than the API's (WHSEID is nullable in every table). Mapping between
   the two is where that gets resolved, in DbMasterData.
   ────────────────────────────────────────────────────────────────────────── */

public sealed class WhseRow
{
    public int SerialKey { get; set; }
    public string? WhseId { get; set; }
    public string? Description { get; set; }
    public string? Name { get; set; }
    public string? Address1 { get; set; }
    public string? SubDistrict { get; set; }
    public string? District { get; set; }
    public string? Province { get; set; }
    public string? PostalCode { get; set; }
    public decimal? Latitude { get; set; }
    public decimal? Longitude { get; set; }
    public bool? IsDc { get; set; }
    public string? Status { get; set; }
    public DateTime AddDate { get; set; }
    /// <summary>CK_site_type allows only 'E' or 'S'; nothing records what either means.</summary>
    public string? Type { get; set; }
}

public sealed class ZoneRow
{
    public string WhseId { get; set; } = "";
    public string OwnerKey { get; set; } = "";
    public string ZoneKey { get; set; } = "";
    public string Name { get; set; } = "";
    public string? Province { get; set; }
    public string? District { get; set; }
    public string? DefaultRoute { get; set; }
    public string Status { get; set; } = "";
    public decimal? MaxVehicleWeight { get; set; }
    public string? WeightUom { get; set; }
    public DateTime AddDate { get; set; }
}

public sealed class ZoneCoverageRow
{
    public int SerialKey { get; set; }
    public string WhseId { get; set; } = "";
    public string OwnerKey { get; set; } = "";
    public string ZoneKey { get; set; } = "";
    public string Province { get; set; } = "";
    public string? District { get; set; }
    public string Status { get; set; } = "";
    public DateTime AddDate { get; set; }
}

public sealed class RouteRow
{
    public string Route { get; set; } = "";
    public string Name { get; set; } = "";
    public string? OriginWhseId { get; set; }
    public string? Colour { get; set; }
    public string Status { get; set; } = "";
}

public sealed class RouteZoneRow
{
    public int SerialKey { get; set; }
    public string Route { get; set; } = "";
    public string WhseId { get; set; } = "";
    public string OwnerKey { get; set; } = "";
    public string ZoneKey { get; set; } = "";
    public int Sequence { get; set; }
    public string Status { get; set; } = "";
    public DateTime AddDate { get; set; }
}

public sealed class TransporterRow
{
    public string TransporterKey { get; set; } = "";
    public string Name { get; set; } = "";
    public string? Type { get; set; }
    public string? ContactName { get; set; }
    public string? Phone { get; set; }
    public string? Email { get; set; }
    public string? TaxId { get; set; }
    public string Status { get; set; } = "";
}

public sealed class VehicleTypeRow
{
    public string VehicleTypeKey { get; set; } = "";
    public string Name { get; set; } = "";
    public decimal? MaxWeight { get; set; }
    public decimal? MaxCube { get; set; }
}

public sealed class VehicleRow
{
    public string VehicleKey { get; set; } = "";
    public string TransporterKey { get; set; } = "";
    public string VehicleTypeKey { get; set; } = "";
    public string LicensePlate { get; set; } = "";
    public string? PlateTrailer { get; set; }
    public string Status { get; set; } = "";
}

public sealed class DriverRow
{
    public string DriverKey { get; set; } = "";
    public string TransporterKey { get; set; } = "";
    public string Name { get; set; } = "";
    public string? Mobile { get; set; }
    public string? LicenseNo { get; set; }
    public string? LicenseType { get; set; }
    public string Status { get; set; } = "";
}

public sealed class CustomerRow
{
    public string CustomerKey { get; set; } = "";
    public string Name { get; set; } = "";
    public string? Address1 { get; set; }
    public string? SubDistrict { get; set; }
    public string? District { get; set; }
    public string? Province { get; set; }
    public string? PostalCode { get; set; }
    public decimal? Latitude { get; set; }
    public decimal? Longitude { get; set; }
    public string? ZoneKey { get; set; }
    public string? Route { get; set; }
}



public sealed class DeliveryOrderRow
{
    public string WhseId { get; set; } = "";
    public string OrderKey { get; set; } = "";
    public string SoKey { get; set; } = "";
    public DateTime OrderDate { get; set; }
    public DateTime? DeliveryDate { get; set; }
    public string ShipTo { get; set; } = "";
    public string? CompanyName { get; set; }
    public string? Route { get; set; }
    public string? Zone { get; set; }
    public string Status { get; set; } = "";
}
