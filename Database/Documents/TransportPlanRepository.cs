using Microsoft.EntityFrameworkCore;

namespace Mammod.Database.Documents;

/// <summary>
/// Loading and saving แผนขนส่ง. Persistence only — the rules live in the policy
/// and the transaction lives in the service.
///
/// Warehouse-scoped by the implementation, never by a parameter, for the same
/// reason <see cref="ShipmentRepository"/> is: a caller cannot forget a scope it
/// was never asked for, and cannot pass one that arrived in a request body.
///
/// Writes ask for tracking explicitly. <see cref="AppDbContext"/> is
/// <c>NoTracking</c> by default, and a mutation that forgets to opt in writes
/// nothing at all while still answering 200 — see the note on that class.
/// </summary>
public sealed class TransportPlanRepository(
    AppDbContext db, IWarehouseContext warehouse) : ITransportPlanRepository
{
    private string Whse => warehouse.CurrentWarehouseId;

    public Task<TransportPlanRow?> GetAsync(string planKey, CancellationToken ct = default) =>
        db.Set<TransportPlanRow>()
            .AsTracking()
            .FirstOrDefaultAsync(p => p.WhseId == Whse && p.PlanKey == planKey, ct);

    /// <summary>
    /// With lines, for issuing — where how many orders the plan is holding is a
    /// rule rather than a display detail.
    /// </summary>
    public Task<TransportPlanRow?> GetWithLinesAsync(string planKey, CancellationToken ct = default) =>
        db.Set<TransportPlanRow>()
            .AsTracking()
            .Include(p => p.Lines)
            .FirstOrDefaultAsync(p => p.WhseId == Whse && p.PlanKey == planKey, ct);

    /// <summary>Newest first — the numbers run in order, so the key sorts as the date does.</summary>
    public async Task<IReadOnlyList<TransportPlanRow>> ListAsync(CancellationToken ct = default) =>
        await db.Set<TransportPlanRow>()
            .Where(p => p.WhseId == Whse)
            .OrderByDescending(p => p.PlanKey)
            .ToListAsync(ct);

    /// <summary>
    /// Stamps the warehouse rather than trusting the caller to have set it: a row
    /// inserted with a blank WHSEID would be invisible to every read afterwards.
    /// </summary>
    public async Task AddAsync(TransportPlanRow plan, CancellationToken ct = default)
    {
        plan.WhseId = Whse;
        await db.Set<TransportPlanRow>().AddAsync(plan, ct);
    }

    /// <summary>
    /// Not implemented, and deliberately not guessed at.
    ///
    /// <c>UX_DOC_TRANSPORT_PLAN_LINE_ORDER</c> is unique on ORDERKEY filtered to
    /// <c>STATUS &lt;&gt; 'CANCELLED'</c>, which means dropping an order from a plan
    /// is either a delete or a status change, and the two leave different
    /// histories behind. Nothing in the schema or the contracts says which, and
    /// picking one here would settle a rule that belongs to the SetStops slice.
    /// </summary>
    public Task ReplaceLinesAsync(
        string planKey, IReadOnlyList<string> orderKeys, CancellationToken ct = default) =>
        throw new NotImplementedException(
            "ยังไม่ได้ย้าย 'เลือกใบสั่งส่งเข้าแผน' มาที่ SQL — ยังใช้ TmsStore " +
            "(ต้องตัดสินก่อนว่าการเอาออกจากแผนคือลบแถวหรือเปลี่ยนสถานะเป็น CANCELLED)");
}
