using Mammod.Data;
using Microsoft.EntityFrameworkCore;

namespace Mammod.Database;

/// <summary>
/// Deleting master records — and refusing to when something still points at them.
///
/// There was no delete anywhere in this project on purpose: retiring a row by
/// setting <c>active: false</c> keeps the documents that already name it
/// readable, and a delete does not. That reasoning holds for anything a document
/// has ever used, and it is why every delete here checks first. What it does not
/// justify is being unable to remove a row typed in by mistake five minutes ago,
/// which is the case these methods exist for.
///
/// So the rule is: <b>delete what nothing refers to, refuse everything else, and
/// say what is holding it.</b> A refusal names the table and the count, because
/// "cannot delete" without a reason leaves someone hunting through six screens.
/// Deactivating remains the right answer for a record with history — the message
/// says so rather than leaving the reader to work it out.
///
/// The checks are raw SQL rather than mapped entities. Counting references means
/// touching a dozen tables the API never otherwise reads, and mapping each one
/// to ask <c>COUNT(*)</c> would be a lot of code that earns nothing. Every query
/// here is parameterised — the values are keys that arrived over HTTP.
/// </summary>
public sealed partial class MasterQueries
{
    /// <summary>One table that could block a delete, and what to call it in the message.</summary>
    private sealed record Reference(string Table, string Column, string Label);

    /// <summary>
    /// Counts rows pointing at <paramref name="key"/> and throws naming the first
    /// table that has any. Ordered by how much the reference matters: a document
    /// is a stronger reason to refuse than another master row, and it is the one
    /// the reader most needs to hear about.
    /// </summary>
    private static void AssertNothingReferences(
        AppDbContext db, string key, string what, IEnumerable<Reference> references)
    {
        foreach (var reference in references)
        {
            // Table and column names are literals from the arrays below, never
            // from a request; the key is a parameter.
            var count = db.Database
                .SqlQueryRaw<int>(
                    $"SELECT COUNT(*) AS Value FROM dbo.{reference.Table} WHERE {reference.Column} = {{0}}", key)
                .AsEnumerable()
                .First();

            if (count > 0)
                throw new DomainException(
                    $"ลบ{what} {key} ไม่ได้ — มี{reference.Label} {count} รายการอ้างถึงอยู่ " +
                    "ถ้าเลิกใช้แล้วให้ตั้งเป็นไม่ใช้งาน (active = false) แทน เอกสารเก่าจะได้ยังอ่านได้");
        }
    }

    private static readonly Reference[] CarrierReferences =
    [
        new("DOC_SHIPMENT_HDR", "TRANSPORTERKEY", "ใบปิดบรรทุก"),
        new("MST_VEHICLE", "TRANSPORTERKEY", "รถ"),
        new("MST_DRIVER", "TRANSPORTERKEY", "พนักงานขับรถ"),
        new("MST_TRANSPORT_RATE", "TRANSPORTERKEY", "เรตค่าขนส่ง"),
        new("MST_TRANSPORTER_ROUTE", "TRANSPORTERKEY", "สายส่งที่ผูกไว้"),
        new("MST_TRANSPORTER_DOCUMENT", "TRANSPORTERKEY", "เอกสารแนบ"),
    ];

    private static readonly Reference[] VehicleReferences =
    [
        new("DOC_SHIPMENT_HDR", "VEHICLEKEY", "ใบปิดบรรทุก"),
        new("MST_DRIVER", "DEFAULT_VEHICLEKEY", "พนักงานขับรถที่ตั้งรถคันนี้เป็นค่าเริ่มต้น"),
        new("MST_TRANSPORTER_DOCUMENT", "VEHICLEKEY", "เอกสารแนบ"),
    ];

    private static readonly Reference[] DriverReferences =
    [
        new("DOC_SHIPMENT_HDR", "DRIVERKEY", "ใบปิดบรรทุก"),
    ];

    /* ZONE บนตารางเอกสารเป็นคอลัมน์ข้อความ ไม่ใช่ FK (README หัวข้อ 2.4) — ฐาน
       จึงไม่กันให้ ต้องนับเอง ไม่งั้นลบโซนทิ้งแล้วใบปิดบรรทุกเก่าจะอ้างโซนที่ไม่มีอยู่ */
    private static readonly Reference[] ZoneReferences =
    [
        new("DOC_SHIPMENT_HDR", "ZONE", "ใบปิดบรรทุก"),
        new("DOC_SHIPMENT_DETAIL", "ZONE", "รายการในใบปิดบรรทุก"),
        new("DOC_TRANSPORT_PLAN", "ZONE", "แผนขนส่ง"),
        new("DOC_DO_HDR", "ZONE", "ใบสั่งส่ง"),
        new("MST_CUSTOMER", "TRANSPORTZONEKEY", "ลูกค้า"),
    ];

    private static readonly Reference[] RouteReferences =
    [
        new("DOC_SHIPMENT_HDR", "ROUTE", "ใบปิดบรรทุก"),
        new("DOC_SHIPMENT_DETAIL", "ROUTE", "รายการในใบปิดบรรทุก"),
        new("DOC_TRANSPORT_PLAN", "ROUTE", "แผนขนส่ง"),
        new("DOC_DO_HDR", "ROUTE", "ใบสั่งส่ง"),
        new("MST_CUSTOMER", "ROUTE", "ลูกค้า"),
        new("MST_TRANSPORT_RATE", "ROUTE", "เรตค่าขนส่ง"),
        new("MST_TRANSPORTER_ROUTE", "ROUTE", "ผู้ให้บริการที่วิ่งสายนี้"),
        new("MST_TRANSPORTATIONZONE", "DEFAULTROUTE", "โซนที่ตั้งสายนี้เป็นสายหลัก"),
    ];

    /* คลังไม่มี FK ชี้มาเลย เพราะ WHSEID ไม่ unique (README หัวข้อ 2.2) แต่ทุก
       เอกสารในระบบเก็บ WHSEID ไว้เป็นข้อความ — ลบคลังทิ้งจึงทำให้เอกสารทั้งกอง
       ชี้ไปที่ว่างเปล่าโดยที่ฐานไม่ปริปาก */
    private static readonly Reference[] WarehouseReferences =
    [
        new("DOC_SHIPMENT_HDR", "WHSEID", "ใบปิดบรรทุก"),
        new("DOC_TRANSPORT_PLAN", "WHSEID", "แผนขนส่ง"),
        new("DOC_DO_HDR", "WHSEID", "ใบสั่งส่ง"),
        new("MST_CUSTOMER", "WHSEID", "ลูกค้า"),
        new("MST_TRANSPORTATIONZONE", "WHSEID", "โซนจัดส่ง"),
    ];

    // ── ผู้ให้บริการขนส่ง ───────────────────────────────────────────────────

    public void DeleteCarrier(string id)
    {
        var key = Key(id, "cr-");
        if (!useDatabase) { store.DeleteCarrier(id); return; }

        InDb(db =>
        {
            var row = db.Transporters.AsTracking().FirstOrDefault(t => t.TransporterKey == key)
                ?? throw DomainException.NotFound("ไม่พบผู้ให้บริการนี้");
            AssertNothingReferences(db, key, "ผู้ให้บริการ", CarrierReferences);
            db.Remove(row);
            return true;
        });
    }

    // ── รถ ──────────────────────────────────────────────────────────────────

    public void DeleteVehicle(string id)
    {
        var key = Key(id, "v-");
        if (!useDatabase) { store.DeleteVehicle(id); return; }

        InDb(db =>
        {
            var row = db.Vehicles.AsTracking().FirstOrDefault(v => v.VehicleKey == key)
                ?? throw DomainException.NotFound("ไม่พบรถคันนี้");
            AssertNothingReferences(db, key, "รถ", VehicleReferences);
            db.Remove(row);
            return true;
        });
    }

    // ── พนักงานขับรถ ────────────────────────────────────────────────────────

    public void DeleteDriver(string id)
    {
        var key = Key(id, "dr-");
        if (!useDatabase) { store.DeleteDriver(id); return; }

        InDb(db =>
        {
            var row = db.Drivers.AsTracking().FirstOrDefault(d => d.DriverKey == key)
                ?? throw DomainException.NotFound("ไม่พบพนักงานขับรถคนนี้");
            AssertNothingReferences(db, key, "พนักงานขับรถ", DriverReferences);
            db.Remove(row);
            return true;
        });
    }

    // ── โซนจัดส่ง ───────────────────────────────────────────────────────────

    public void DeleteZone(string id)
    {
        var key = Key(id, "zone-");
        if (!useDatabase) { store.DeleteZone(id); return; }

        InDb(db =>
        {
            var row = db.Zones.AsTracking().FirstOrDefault(z => z.ZoneKey == key)
                ?? throw DomainException.NotFound("ไม่พบโซนนี้");
            AssertNothingReferences(db, key, "โซนจัดส่ง", ZoneReferences);

            // Coverage and route membership belong to the zone rather than
            // referring to it — they have no meaning once it is gone, so they go
            // with it instead of blocking it.
            db.ZoneCoverage.RemoveRange(db.ZoneCoverage.AsTracking().Where(c => c.ZoneKey == key));
            db.RouteZones.RemoveRange(db.RouteZones.AsTracking().Where(rz => rz.ZoneKey == key));
            db.Remove(row);
            return true;
        });
    }

    // ── สายส่ง ──────────────────────────────────────────────────────────────

    public void DeleteRoute(string id)
    {
        var key = Key(id, "rt-");
        if (!useDatabase) { store.DeleteRoute(id); return; }

        InDb(db =>
        {
            var row = db.Routes.AsTracking().FirstOrDefault(r => r.Route == key)
                ?? throw DomainException.NotFound("ไม่พบสายส่งนี้");
            AssertNothingReferences(db, key, "สายส่ง", RouteReferences);

            db.RouteZones.RemoveRange(db.RouteZones.AsTracking().Where(rz => rz.Route == key));
            db.Remove(row);
            return true;
        });
    }

    // ── คลัง ────────────────────────────────────────────────────────────────

    public void DeleteWarehouse(string id)
    {
        var key = Key(id, "wh-");
        if (!useDatabase) { store.DeleteWarehouse(id); return; }

        InDb(db =>
        {
            var row = db.Warehouses.AsTracking().FirstOrDefault(w => w.WhseId == key)
                ?? throw DomainException.NotFound("ไม่พบคลังนี้");
            AssertNothingReferences(db, key, "คลัง", WarehouseReferences);

            // A route starting here would be left pointing at a warehouse that no
            // longer exists. Cleared rather than blocked: the origin is optional
            // on a route, so losing it degrades the route instead of breaking it.
            foreach (var route in db.Routes.AsTracking().Where(r => r.OriginWhseId == key))
                route.OriginWhseId = null;

            db.Remove(row);
            return true;
        });
    }
}
