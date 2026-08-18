using System.Text.Json;
using Mammod.Data;
using Microsoft.EntityFrameworkCore;

namespace Mammod.Database.Documents;

/// <summary>
/// Orchestration for แผนขนส่ง: open a transaction, take a number, insert the
/// document, write the audit, commit.
///
/// Create, Update, SetStops and Cancel are implemented. Issue is not, and
/// stays closed rather than merely unwritten: it cuts a shipment from a plan,
/// and a shipment that exists but can never be sent — MMX has no contract yet —
/// is not a document anybody should be able to raise.
/// </summary>
public sealed class TransportPlanService(
    AppDbContext db,
    ITransportPlanRepository plans,
    ITransportPlanPolicy policy,
    IShipmentRepository shipments,
    IDeliveryOrderQuery orders,
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
        // that by silently returning the orders to the pool and emptying the plan.
        //
        // How a line leaves a plan is now settled — it is cancelled, not deleted —
        // so this could be done. It still is not, and the reason is no longer
        // technical: emptying a basket somebody spent time filling should be
        // something they ask for, not something that happens because they changed
        // a dropdown. Take the orders out through SetStops, then move the run.
        var liveLines = plan.Lines.Count(l => l.Status != PlanStatus.Cancelled);
        if (!string.Equals(route, plan.Route, StringComparison.OrdinalIgnoreCase) && liveLines > 0)
        {
            throw new DomainException(
                $"เปลี่ยนสายส่งไม่ได้ เพราะแผนถือใบสั่งส่งอยู่ {liveLines} รายการ " +
                "ซึ่งเลือกมาตามสายเดิม — เอาใบสั่งส่งออกจากแผนก่อน แล้วจึงเปลี่ยนสายส่ง",
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
    /// Makes the plan hold exactly these orders.
    ///
    /// Replace, not patch: the screen sends the tick-boxes as they now stand, so
    /// anything absent from the list is being taken out. An order taken out has
    /// its line cancelled rather than deleted, which is what returns it to the
    /// pool — see <see cref="TransportPlanRepository.ReplaceLinesAsync"/> for why
    /// that is the established reading rather than a choice made here.
    ///
    /// Everything is checked before anything is written. An order somebody else
    /// has taken, or one in a zone this run never enters, refuses the whole call
    /// — a partly-applied basket is worse than a rejected one, because the
    /// planner cannot see which half landed.
    /// </summary>
    public async Task<TransportPlanRow> SetStopsAsync(
        string planKey, IReadOnlyList<string> orderKeys, string ifMatch, CancellationToken ct = default)
    {
        var key = (planKey ?? "").Trim();
        if (key.Length == 0)
            throw new DomainException("ต้องระบุเลขที่แผนขนส่ง");

        if (!DocumentIdentity.TryReadVersion(ifMatch, out var expected))
        {
            throw new DomainException(
                "ต้องส่ง If-Match พร้อมเวอร์ชันของแผน (currentVersion ที่ได้จากการอ่านล่าสุด) — " +
                "ไม่งั้นการบันทึกอาจทับสิ่งที่คนอื่นเพิ่งแก้ไป");
        }

        if (string.IsNullOrWhiteSpace(actor.CurrentUser))
            throw new InvalidOperationException(
                "ไม่ทราบผู้ทำรายการ — WarehouseMiddleware ต้องทำงานก่อน controller");

        // The same order ticked twice is one order, as it has always been.
        var wanted = (orderKeys ?? [])
            .Select(o => (o ?? "").Trim())
            .Where(o => o.Length > 0)
            .Distinct(StringComparer.Ordinal)
            .ToList();

        await using var transaction = await db.Database.BeginTransactionAsync(ct);

        var plan = await plans.GetWithLinesAsync(key, ct)
            ?? throw DomainException.NotFound($"ไม่พบแผนขนส่ง {key}");

        var decision = policy.CanSetStops(plan);
        if (!decision.IsAllowed)
        {
            throw new DomainException(decision.Message, decision.Kind == RefusalKind.Incomplete
                ? StatusCodes.Status422UnprocessableEntity
                : StatusCodes.Status409Conflict);
        }

        var held = plan.Lines
            .Where(l => l.Status != PlanStatus.Cancelled)
            .Select(l => l.OrderKey)
            .ToHashSet(StringComparer.Ordinal);

        var arriving = wanted.Where(o => !held.Contains(o)).ToList();

        await RefuseUnavailableAsync(arriving, ct);
        await RefuseOffRouteAsync(plan, wanted, ct);

        // Touch the header so the version means something. Only the lines are
        // really changing, and EF adds the ROWVER predicate to an UPDATE it is
        // actually issuing — leave the plan row alone and If-Match would be read,
        // checked against nothing, and quietly ignored.
        var now = DateTime.UtcNow;
        db.Entry(plan).Property(p => p.RowVer).OriginalValue = expected;
        plan.EditDate = now;
        plan.EditWho = actor.CurrentUser;

        await plans.ReplaceLinesAsync(key, wanted, ct);

        var live = plan.Lines.Where(l => l.Status != PlanStatus.Cancelled).ToList();
        plan.TotalOrder = live.Count;

        var removed = held.Where(o => !wanted.Contains(o, StringComparer.Ordinal)).OrderBy(o => o).ToList();

        await audit.WriteAsync(new DocumentAuditRow
        {
            DocumentType = DocumentAuditWriter.PlanDocument,
            DocumentKey = plan.PlanKey,
            Action = AuditAction.Updated,
            FromStatus = plan.Status,
            ToStatus = plan.Status,
            Actor = actor.CurrentUser,
            RequestId = actor.RequestId,
            ChangedAt = now,
            Metadata = JsonSerializer.Serialize(new
            {
                change = "SET_STOPS",
                added = arriving.OrderBy(o => o).ToList(),
                removed,
                totalOrder = live.Count,
                warehouse = warehouse.CurrentWarehouseId,
            }, AuditJson),
        }, ct);

        try
        {
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
        return plan;
    }

    /// <summary>
    /// Refuses orders that are not free, naming them.
    ///
    /// Asked through <see cref="IDeliveryOrderQuery.FilterAvailableAsync"/>,
    /// which is warehouse-scoped, so this one check covers three refusals at
    /// once: an order that does not exist, one belonging to another site, and
    /// one another plan or shipment already holds. All three are "you cannot
    /// have this", and the caller does not need them told apart to act.
    /// </summary>
    private async Task RefuseUnavailableAsync(IReadOnlyList<string> arriving, CancellationToken ct)
    {
        if (arriving.Count == 0) return;

        var free = (await orders.FilterAvailableAsync(arriving, ct)).ToHashSet(StringComparer.Ordinal);
        var taken = arriving.Where(o => !free.Contains(o)).OrderBy(o => o).ToList();

        if (taken.Count > 0)
        {
            throw new DomainException(
                $"ใบสั่งส่ง {string.Join(", ", taken)} ไม่ว่างแล้ว — " +
                "อาจถูกแผนหรือใบปิดบรรทุกอื่นรับไปก่อน หรือไม่ได้อยู่ในคลังนี้",
                StatusCodes.Status409Conflict);
        }
    }

    /// <summary>
    /// Refuses orders in a zone the plan's run never enters.
    ///
    /// A lorry drives a line, not an area: the northern run reaches Phitsanulok
    /// by way of Nakhon Sawan and Phichit, so all three are loadable onto it and
    /// a zone it never passes is not. The rule is the one TmsStore has always
    /// applied and the client's own tests assert; the zones come from
    /// MST_ROUTE_ZONE, scoped to this warehouse.
    /// </summary>
    private async Task RefuseOffRouteAsync(
        TransportPlanRow plan, IReadOnlyList<string> wanted, CancellationToken ct)
    {
        if (wanted.Count == 0 || string.IsNullOrWhiteSpace(plan.Route)) return;

        var whse = warehouse.CurrentWarehouseId;
        var reachable = await db.RouteZones
            .AsNoTracking()
            .Where(rz => rz.WhseId == whse && rz.Route == plan.Route)
            .Select(rz => rz.ZoneKey)
            .ToListAsync(ct);

        // A run with no zones recorded is not evidence that nothing may ride it;
        // it is missing master data, and refusing every order would be blaming
        // the planner for it.
        if (reachable.Count == 0) return;

        var reach = reachable.ToHashSet(StringComparer.Ordinal);

        var zones = await db.DeliveryOrders
            .AsNoTracking()
            .Where(o => o.WhseId == whse && wanted.Contains(o.OrderKey))
            .Select(o => new { o.OrderKey, o.Zone })
            .ToListAsync(ct);

        var stray = zones
            .Where(o => o.Zone is null || !reach.Contains(o.Zone))
            .Select(o => o.OrderKey)
            .OrderBy(o => o)
            .ToList();

        if (stray.Count > 0)
        {
            throw new DomainException(
                $"ใบสั่งส่ง {string.Join(", ", stray)} อยู่ในโซนที่สาย {plan.Route} ไม่ได้วิ่งผ่าน — " +
                "เลือกได้เฉพาะใบในโซนที่สายนี้ผ่าน หรือสร้างแผนของสายอื่นแยกอีกใบ",
                StatusCodes.Status422UnprocessableEntity);
        }
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

    /// <summary>
    /// Closed on purpose, not merely unwritten: issuing cuts a manifest, and a
    /// manifest that cannot be handed to MMX is a document nobody can act on.
    /// This opens when the MMX contract does.
    /// </summary>
    public Task<(TransportPlanRow Plan, ShipmentRow Shipment)> IssueAsync(
        string planKey, string ifMatch, CancellationToken ct = default) =>
        throw new NotImplementedException(
            "ยังไม่ได้ย้าย 'ออกใบปิดบรรทุก' มาที่ SQL — รอสัญญา MMX ก่อน");

    /// <summary>
    /// Calls a draft plan off and hands everything it was holding back.
    ///
    /// <b>Cancelling the lines is not a courtesy — it is the whole operation.</b>
    /// The pending pool is derived from line status, not from plan status: an
    /// order is claimed while a line names it and is not CANCELLED, and
    /// <see cref="DeliveryOrderQuery"/> never looks at the plan the line belongs
    /// to. Mark the header alone and every order this plan held would be stranded
    /// permanently — out of the pool, on a plan nobody can use, and invisible to
    /// the screen that would put them somewhere else.
    ///
    /// Draft only, and only while it has issued nothing. A plan that produced a
    /// manifest is the record of where that document came from, and the document
    /// outlives it.
    /// </summary>
    public async Task<TransportPlanRow> CancelAsync(
        string planKey, string reason, string ifMatch, CancellationToken ct = default)
    {
        var key = (planKey ?? "").Trim();
        if (key.Length == 0)
            throw new DomainException("ต้องระบุเลขที่แผนขนส่ง");

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

        var plan = await plans.GetWithLinesAsync(key, ct)
            ?? throw DomainException.NotFound($"ไม่พบแผนขนส่ง {key}");

        // The policy asks whether a manifest is already out. Only looked up when
        // the plan names one — a draft never does, so the common path costs
        // nothing and the guard is still there if ISSUED ever becomes cancellable.
        var issued = string.IsNullOrWhiteSpace(plan.ShipmentKey)
            ? null
            : await shipments.GetAsync(plan.ShipmentKey, ct);

        var decision = policy.CanCancel(plan, issued);
        if (!decision.IsAllowed)
        {
            throw new DomainException(decision.Message, decision.Kind == RefusalKind.Incomplete
                ? StatusCodes.Status422UnprocessableEntity
                : StatusCodes.Status409Conflict);
        }

        db.Entry(plan).Property(p => p.RowVer).OriginalValue = expected;

        var now = DateTime.UtcNow;
        var trimmed = (reason ?? "").Trim();
        var released = plan.Lines
            .Where(l => l.Status != PlanStatus.Cancelled)
            .Select(l => l.OrderKey)
            .OrderBy(o => o, StringComparer.Ordinal)
            .ToList();

        plan.Status = PlanStatus.Cancelled;
        plan.CancelReason = trimmed.Length == 0 ? null : trimmed;
        plan.TotalOrder = 0;
        plan.EditDate = now;
        plan.EditWho = actor.CurrentUser;

        // Emptying the plan through the same path SetStops uses, so there is one
        // definition of what taking an order off a plan does.
        await plans.ReplaceLinesAsync(key, [], ct);

        await audit.WriteAsync(new DocumentAuditRow
        {
            DocumentType = DocumentAuditWriter.PlanDocument,
            DocumentKey = plan.PlanKey,
            Action = AuditAction.Cancelled,
            FromStatus = PlanStatus.Draft,
            ToStatus = PlanStatus.Cancelled,
            Reason = plan.CancelReason,
            Actor = actor.CurrentUser,
            RequestId = actor.RequestId,
            ChangedAt = now,
            // The orders let go, recorded because the plan itself no longer says
            // what it held: raising it again is decided against the pool as it
            // stands then, not against a promise made now.
            Metadata = JsonSerializer.Serialize(new
            {
                released,
                warehouse = warehouse.CurrentWarehouseId,
            }, AuditJson),
        }, ct);

        try
        {
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
        return plan;
    }
}
