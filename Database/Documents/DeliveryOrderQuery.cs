using Microsoft.EntityFrameworkCore;

namespace Mammod.Database.Documents;

/// <summary>
/// The pending pool — the only piece of Phase 3 with a body, because it is a
/// query rather than a behaviour and it settles a design question worth settling
/// early.
///
/// <b>There is no pool table.</b> The pool is the delivery orders that nothing
/// live has claimed: not on a plan, not on a shipment. Deriving it means the
/// invariant "an order is in exactly one place" cannot drift — there is no
/// second list to keep in step, and no code path that can forget to remove
/// something from it. The old in-memory <c>_pendingStops</c> was exactly that
/// second list, and keeping it correct was what every <c>GiveBack</c> call in
/// the store was for.
///
/// <c>NOT EXISTS</c> rather than a <c>LEFT JOIN … IS NULL</c>: the join
/// multiplies rows when an order appears more than once on the other side, and
/// the answer here has to be one row per order whatever the other tables
/// contain. That holds even after <c>UQ_DOC_DO_HDR_ORDER</c> lands.
///
/// "Claimed" means a row whose own status is not <c>CANCELLED</c> — the same
/// predicate as the two filtered unique indexes, so this query and the database
/// constraint can never disagree about what counts.
/// </summary>
public sealed class DeliveryOrderQuery(AppDbContext db, IWarehouseContext warehouse) : IDeliveryOrderQuery
{
    private const string Cancelled = "CANCELLED";

    public async Task<IReadOnlyList<DeliveryOrderRow>> GetAvailableAsync(CancellationToken ct = default) =>
        await Available().OrderBy(o => o.OrderKey).ToListAsync(ct);

    public async Task<IReadOnlyList<string>> FilterAvailableAsync(
        IReadOnlyList<string> orderKeys, CancellationToken ct = default)
    {
        if (orderKeys.Count == 0) return [];

        // Asked before taking, so the refusal can name the orders someone else
        // took rather than surfacing a unique-index violation from the insert.
        return await Available()
            .Where(o => orderKeys.Contains(o.OrderKey))
            .Select(o => o.OrderKey)
            .ToListAsync(ct);
    }

    private IQueryable<DeliveryOrderRow> Available()
    {
        var whse = warehouse.CurrentWarehouseId;

        return db.DeliveryOrders
            .AsNoTracking()
            .Where(o => o.WhseId == whse)
            .Where(o => !db.Set<ShipmentDetailRow>()
                .Any(d => d.WhseId == o.WhseId
                       && d.OrderKey == o.OrderKey
                       && d.Status != Cancelled))
            .Where(o => !db.Set<TransportPlanLineRow>()
                .Any(l => l.WhseId == o.WhseId
                       && l.OrderKey == o.OrderKey
                       && l.Status != Cancelled));
    }
}
