using System.Text.Json;
using Mammod.Data;
using Microsoft.EntityFrameworkCore;

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
    ITransportPlanPolicy policy,
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
    /// Edits a draft plan's header.
    ///
    /// A plan carries three things anyone edits: the day it delivers, the run it
    /// is being built for, and a note. Its number, its warehouse and its status
    /// are not among them — the first two are identity and the third is a
    /// lifecycle, and neither is something a form should be able to move.
    ///
    /// <b>Header only.</b> What the plan is holding changes through SetStops,
    /// which is a separate transaction for a reason: an order sits on one live
    /// plan at a time, so taking one is a claim on shared state rather than an
    /// edit to this document.
    /// </summary>
    public async Task<TransportPlanRow> UpdateAsync(
        string planKey, PlanHeaderInput input, string ifMatch, CancellationToken ct = default)
    {
        var key = (planKey ?? "").Trim();
        if (key.Length == 0)
            throw new DomainException("ต้องระบุเลขที่แผนขนส่ง");

        var route = (input.RouteCode ?? "").Trim();
        if (route.Length == 0)
            throw new DomainException("ต้องเลือกสายส่งของแผนขนส่ง");

        // Absent and unreadable are answered alike, as everywhere else: both mean
        // the caller has not said which version they are editing.
        if (!DocumentIdentity.TryReadVersion(ifMatch, out var expected))
        {
            throw new DomainException(
                "ต้องส่ง If-Match พร้อมเวอร์ชันของแผน (currentVersion ที่ได้จากการอ่านล่าสุด) — " +
                "ไม่งั้นการบันทึกอาจทับสิ่งที่คนอื่นเพิ่งแก้ไป");
        }

        if (string.IsNullOrWhiteSpace(actor.CurrentUser))
            throw new InvalidOperationException(
                "ไม่ทราบผู้ทำรายการ — WarehouseMiddleware ต้องทำงานก่อน controller");

        await using var transaction = await db.Database.BeginTransactionAsync(ct);

        // Lines come with it because whether the plan is holding anything decides
        // whether the route may move — see below.
        var plan = await plans.GetWithLinesAsync(key, ct)
            ?? throw DomainException.NotFound($"ไม่พบแผนขนส่ง {key}");

        var decision = policy.CanEdit(plan);
        if (!decision.IsAllowed)
        {
            throw new DomainException(decision.Message, decision.Kind == RefusalKind.Incomplete
                ? StatusCodes.Status422UnprocessableEntity
                : StatusCodes.Status409Conflict);
        }

        // Moving a plan to another route strands whatever it is holding: the load
        // was gathered because the old route passes those zones. TmsStore handles
        // that by returning the orders to the pool and emptying the plan — which
        // is a line mutation, and how a line leaves a plan is exactly what is
        // still undecided (a delete, or STATUS = CANCELLED; the filtered index
        // UX_DOC_TRANSPORT_PLAN_LINE_ORDER permits either reading).
        //
        // So the route may move only while the plan is holding nothing. Refusing
        // is not a new rule — it is declining an operation whose semantics have
        // not been settled, and it keeps the invariant that comment is protecting
        // rather than quietly breaking it.
        var liveLines = plan.Lines.Count(l => l.Status != PlanStatus.Cancelled);
        if (!string.Equals(route, plan.Route, StringComparison.OrdinalIgnoreCase) && liveLines > 0)
        {
            throw new DomainException(
                $"เปลี่ยนสายส่งไม่ได้ตอนนี้ เพราะแผนถือใบสั่งส่งอยู่ {liveLines} รายการ — " +
                "เอาใบสั่งส่งออกจากแผนก่อน แล้วจึงเปลี่ยนสายส่ง",
                StatusCodes.Status409Conflict);
        }

        // The concurrency check in one line: EF puts the original ROWVER into the
        // UPDATE's WHERE clause, so telling it the original is what the caller
        // sent leaves the decision to SQL Server.
        db.Entry(plan).Property(p => p.RowVer).OriginalValue = expected;

        var now = DateTime.UtcNow;
        var fromRoute = plan.Route;
        var fromDelivery = plan.DeliveryDate;
        var fromNotes = plan.Notes;

        plan.DeliveryDate = input.DeliveryDate.ToDateTime(TimeOnly.MinValue);
        plan.Route = route;
        plan.Notes = string.IsNullOrWhiteSpace(input.Note) ? null : input.Note.Trim();
        plan.EditDate = now;
        plan.EditWho = actor.CurrentUser;

        await audit.WriteAsync(new DocumentAuditRow
        {
            DocumentType = DocumentAuditWriter.PlanDocument,
            DocumentKey = plan.PlanKey,
            Action = AuditAction.Updated,
            // The status did not move, and saying so in both columns is the
            // record: an edit is not a transition.
            FromStatus = plan.Status,
            ToStatus = plan.Status,
            Actor = actor.CurrentUser,
            RequestId = actor.RequestId,
            ChangedAt = now,
            Metadata = JsonSerializer.Serialize(new
            {
                route = new { from = fromRoute, to = plan.Route },
                deliveryDate = new
                {
                    from = fromDelivery.ToString("yyyy-MM-dd"),
                    to = plan.DeliveryDate.ToString("yyyy-MM-dd"),
                },
                note = new { from = fromNotes, to = plan.Notes },
                warehouse = warehouse.CurrentWarehouseId,
            }, AuditJson),
        }, ct);

        try
        {
            // One call, so the plan and its audit row go as one batch.
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateConcurrencyException)
        {
            await transaction.RollbackAsync(ct);
            throw new ConcurrencyConflictException(
                $"แผนขนส่ง {key} ถูกแก้ไขไปแล้วหลังจากที่คุณเปิดหน้านี้ — โหลดใหม่แล้วลองอีกครั้ง",
                await CurrentVersionAsync(key, ct));
        }

        await transaction.CommitAsync(ct);

        // ROWVER is SQL Server's. EF read the new value back as part of the
        // UPDATE, so plan.RowVer is already the V2 the caller must be given.
        return plan;
    }

    /// <summary>
    /// What the database holds now, read after the failed write rolled back.
    /// Untracked and re-queried: the tracked copy still carries the version the
    /// caller sent, which is the one value that is certainly not current.
    /// </summary>
    private async Task<string> CurrentVersionAsync(string planKey, CancellationToken ct)
    {
        var whse = warehouse.CurrentWarehouseId;
        var latest = await db.Set<TransportPlanRow>()
            .AsNoTracking()
            .Where(p => p.WhseId == whse && p.PlanKey == planKey)
            .Select(p => p.RowVer)
            .FirstOrDefaultAsync(ct);

        return DocumentIdentity.EncodeVersion(latest);
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
