using Microsoft.EntityFrameworkCore;

namespace Mammod.Database.Documents;

/// <summary>
/// Loading and saving ใบปิดบรรทุก. Persistence only — no rules, no transaction
/// of its own: the service owns both.
///
/// <b>Every query is scoped to the request's warehouse, and the scope is not a
/// parameter.</b> No caller passes WHSEID, so no caller can forget to, and no
/// caller can pass one that came out of a request body. That is the whole reason
/// this class exists rather than callers using <c>db.Set&lt;ShipmentRow&gt;()</c>
/// directly.
///
/// <b>No <c>Find</c>.</b> The key is <c>(WHSEID, SHIPMENTKEY)</c>. A single-key
/// lookup would compile against a composite key only by accident and would be
/// the exact bug the warehouse scope exists to prevent.
///
/// Entities come back <b>tracked</b>, and the <c>AsTracking()</c> on each query
/// is not decoration: <see cref="AppDbContext"/> is configured
/// <c>NoTracking</c> by default because it began as a read-only context. Without
/// the opt-in the service mutates a detached object, <c>SaveChanges</c> finds
/// nothing to do, and the call answers 200 having written nothing — which is
/// exactly what happened the first time this was wired up. The audit row went in,
/// the invoice did not, and only a test that read the column back caught it.
///
/// Tracking is also what makes ROWVER work: EF puts the original value into the
/// UPDATE's WHERE clause, and there is no original value without an entry.
/// </summary>
public sealed class ShipmentRepository(AppDbContext db, IWarehouseContext warehouse) : IShipmentRepository
{
    private string Whse => warehouse.CurrentWarehouseId;

    public Task<ShipmentRow?> GetAsync(string shipmentKey, CancellationToken ct = default) =>
        db.Set<ShipmentRow>()
            .AsTracking()
            .FirstOrDefaultAsync(s => s.WhseId == Whse && s.ShipmentKey == shipmentKey, ct);

    public Task<ShipmentRow?> GetWithStopsAsync(string shipmentKey, CancellationToken ct = default) =>
        db.Set<ShipmentRow>()
            .AsTracking()
            .Include(s => s.Stops)
            .FirstOrDefaultAsync(s => s.WhseId == Whse && s.ShipmentKey == shipmentKey, ct);

    /// <summary>
    /// Newest first, by number — the numbers are sequential per month, so this
    /// is the order the list screen shows without a separate sort column.
    /// </summary>
    public async Task<IReadOnlyList<ShipmentRow>> ListAsync(CancellationToken ct = default) =>
        await db.Set<ShipmentRow>()
            .Where(s => s.WhseId == Whse && s.Status != ShipmentStatus.Deleted)
            .OrderByDescending(s => s.ShipmentKey)
            .ToListAsync(ct);

    public async Task<IReadOnlyList<ShipmentRow>> ListDeletedAsync(CancellationToken ct = default) =>
        await db.Set<ShipmentRow>()
            .Where(s => s.WhseId == Whse && s.Status == ShipmentStatus.Deleted)
            .OrderByDescending(s => s.ShipmentKey)
            .ToListAsync(ct);

    /// <summary>
    /// Stamps the warehouse rather than trusting the caller to have set it. A
    /// row built in a service and handed here with a blank WHSEID would insert
    /// and then be invisible to every read.
    /// </summary>
    public async Task AddAsync(ShipmentRow shipment, CancellationToken ct = default)
    {
        shipment.WhseId = Whse;
        await db.Set<ShipmentRow>().AddAsync(shipment, ct);
    }

    public async Task<IReadOnlyList<ShipmentRow>> ListForPlanAsync(
        string planKey, CancellationToken ct = default) =>
        await db.Set<ShipmentRow>()
            .Where(s => s.WhseId == Whse && s.PlanKey == planKey)
            .OrderByDescending(s => s.ShipmentKey)
            .ToListAsync(ct);
}
