using System.Text.Json;
using Mammod.Data;

namespace Mammod.Database.Documents;

/// <summary>
/// Orchestration for แผนขนส่ง: open a transaction, take a number, insert the
/// document, write the audit, commit.
///
/// <b>Only <see cref="CreateAsync"/> is implemented.</b> Creating a plan was
/// chosen as the next slice because it is the smallest operation that consumes
/// a document number, and consuming one is the thing that had never been
/// exercised: the allocator can be reasoned about on its own, but only a real
/// caller proves the number and the document commit or roll back together.
///
/// The rest of the interface throws rather than being written half-way. Issue in
/// particular stays closed: it cuts a shipment from a plan, and a shipment that
/// exists but can never be sent — MMX has no contract yet — is not a document
/// anybody should be able to raise.
/// </summary>
public sealed class TransportPlanService(
    AppDbContext db,
    ITransportPlanRepository plans,
    IDocumentNumberAllocator numbers,
    IDocumentAuditWriter audit,
    IWarehouseContext warehouse,
    IActorContext actor) : ITransportPlanService
{
    /// <summary>The counter these numbers come from — TMS_DOCUMENT_NUMBER.PREFIX.</summary>
    private const string PlanPrefix = "PL";

    /// <summary>
    /// Raises a draft plan.
    ///
    /// A plan carries no truck, driver or seal — it answers <i>what goes out
    /// together</i>, and the dispatcher answers <i>on what</i> later by editing
    /// the manifest cut from it. So this writes a header and nothing else: the
    /// orders arrive through SetStops, which is a separate slice.
    ///
    /// The number and the document are taken in one transaction. That ordering
    /// is the whole reason the allocator refuses to open a transaction of its
    /// own: if the insert fails, the number goes back rather than being burnt on
    /// a plan that does not exist.
    /// </summary>
    public async Task<TransportPlanRow> CreateAsync(
        PlanHeaderInput input, CancellationToken ct = default)
    {
        var route = (input.RouteCode ?? "").Trim();
        if (route.Length == 0)
            throw new DomainException("ต้องเลือกสายส่งของแผนขนส่ง");

        if (string.IsNullOrWhiteSpace(actor.CurrentUser))
            throw new InvalidOperationException(
                "ไม่ทราบผู้ทำรายการ — WarehouseMiddleware ต้องทำงานก่อน controller");

        await using var transaction = await db.Database.BeginTransactionAsync(ct);

        // The number belongs to the month the plan is raised in, not the month it
        // delivers in: PL-202608-0007 says when it was written, and a plan raised
        // on the 31st for the 1st must not take next month's series.
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var planKey = await numbers.AllocateAsync(PlanPrefix, today, ct);

        var now = DateTime.UtcNow;
        var plan = new TransportPlanRow
        {
            PlanKey = planKey,
            PlanDate = now,
            DeliveryDate = input.DeliveryDate.ToDateTime(TimeOnly.MinValue),
            Route = route,
            Status = PlanStatus.Draft,
            Notes = string.IsNullOrWhiteSpace(input.Note) ? null : input.Note.Trim(),
            AddDate = now,
            AddWho = actor.CurrentUser,
        };

        // WHSEID is stamped by the repository from the request context. It is
        // never read off the request body, which is why PlanHeaderInput has no
        // warehouse on it in the first place.
        await plans.AddAsync(plan, ct);

        await audit.WriteAsync(new DocumentAuditRow
        {
            DocumentType = DocumentAuditWriter.PlanDocument,
            DocumentKey = planKey,
            Action = AuditAction.Created,
            ToStatus = PlanStatus.Draft,
            Actor = actor.CurrentUser,
            RequestId = actor.RequestId,
            ChangedAt = now,
            Metadata = JsonSerializer.Serialize(new
            {
                route,
                deliveryDate = input.DeliveryDate.ToString("yyyy-MM-dd"),
                warehouse = warehouse.CurrentWarehouseId,
            }, AuditJson),
        }, ct);

        // One call: the plan row and the audit row go as one batch, inside the
        // same transaction that already holds the counter's row lock.
        await db.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);

        return plan;
    }

    /// <summary>
    /// METADATA is read by people, in the database. The default encoder ships
    /// Thai as \u0E-escapes, which is valid JSON and unreadable in exactly the
    /// place this column exists to be read.
    /// </summary>
    private static readonly JsonSerializerOptions AuditJson = new()
    {
        Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
    };

    // ── ยังไม่ได้ทำ · not implemented yet ──────────────────────────────────

    public Task<TransportPlanRow> UpdateAsync(
        string planKey, PlanHeaderInput input, string ifMatch, CancellationToken ct = default) =>
        throw new NotImplementedException("ยังไม่ได้ย้าย 'แก้ไขแผนขนส่ง' มาที่ SQL — ยังใช้ TmsStore");

    public Task<TransportPlanRow> SetStopsAsync(
        string planKey, IReadOnlyList<string> orderKeys, string ifMatch, CancellationToken ct = default) =>
        throw new NotImplementedException("ยังไม่ได้ย้าย 'เลือกใบสั่งส่งเข้าแผน' มาที่ SQL — ยังใช้ TmsStore");

    /// <summary>
    /// Closed on purpose, not merely unwritten: issuing cuts a manifest, and a
    /// manifest that cannot be handed to MMX is a document nobody can act on.
    /// This opens when the MMX contract does.
    /// </summary>
    public Task<(TransportPlanRow Plan, ShipmentRow Shipment)> IssueAsync(
        string planKey, string ifMatch, CancellationToken ct = default) =>
        throw new NotImplementedException(
            "ยังไม่ได้ย้าย 'ออกใบปิดบรรทุก' มาที่ SQL — รอสัญญา MMX ก่อน");

    public Task<TransportPlanRow> CancelAsync(
        string planKey, string reason, string ifMatch, CancellationToken ct = default) =>
        throw new NotImplementedException("ยังไม่ได้ย้าย 'ยกเลิกแผน' มาที่ SQL — ยังใช้ TmsStore");
}
