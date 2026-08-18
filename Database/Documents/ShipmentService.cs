using System.Text.Json;
using Mammod.Data;
using Microsoft.EntityFrameworkCore;

namespace Mammod.Database.Documents;

/// <summary>
/// Orchestration for ใบปิดบรรทุก: open a transaction, ask the policy, use the
/// repository, write the audit, commit.
///
/// <b>Only <see cref="MarkInvoicedAsync"/> is implemented.</b> Invoicing is the
/// first mutation moved off <see cref="TmsStore"/> and onto SQL, deliberately on
/// its own: it is the smallest write in the system — two columns, no status
/// change, no document number, nothing else touched — which makes it the one
/// where the concurrency contract can be got right before anything larger
/// depends on it. The rest of the interface throws rather than being written
/// half-way; a method that silently does part of a transition is worse than one
/// that says it does not exist yet.
/// </summary>
public sealed class ShipmentService(
    AppDbContext db,
    IShipmentRepository shipments,
    IShipmentPolicy policy,
    IDocumentAuditWriter audit,
    IWarehouseContext warehouse,
    IActorContext actor) : IShipmentService
{
    /// <summary>
    /// Records the invoice against a ใบปิดบรรทุก.
    ///
    /// What it writes is exactly INVOICEDAT and INVOICEDBY, plus one audit row.
    /// Not the status: a shipment that has been invoiced still has to be able to
    /// say whether it was delivered, and overwriting SENT or COMPLETED with an
    /// INVOICED stage destroys that answer for good. Not the stops, the details,
    /// the lines or the plan — billing is a fact recorded about a document, not
    /// a change to what the document says.
    ///
    /// <paramref name="ifMatch"/> is required. Without it two people looking at
    /// the same screen both invoice, and the second write silently wins over a
    /// row it never read.
    /// </summary>
    public async Task<ShipmentRow> MarkInvoicedAsync(
        string shipmentKey, string ifMatch, CancellationToken ct = default)
    {
        var key = (shipmentKey ?? "").Trim();
        if (key.Length == 0)
            throw new DomainException("ต้องระบุเลขที่ใบปิดบรรทุก");

        // Unreadable and absent are answered the same way on purpose: both mean
        // the caller has not told us which version they are acting on, and
        // "your version is wrong" would send them looking for the wrong problem.
        // See DocumentIdentity.TryReadVersion.
        if (!DocumentIdentity.TryReadVersion(ifMatch, out var expected))
        {
            throw new DomainException(
                "ต้องส่ง If-Match พร้อมเวอร์ชันของเอกสาร (currentVersion ที่ได้จากการอ่านล่าสุด) — " +
                "ไม่งั้นการบันทึกอาจทับสิ่งที่คนอื่นเพิ่งแก้ไป");
        }

        // The pipeline fills both in before any controller runs; a blank one
        // means WarehouseMiddleware did not, which is a wiring bug and not
        // something to write "anonymous" into an audit row over.
        if (string.IsNullOrWhiteSpace(actor.CurrentUser))
            throw new InvalidOperationException(
                "ไม่ทราบผู้ทำรายการ — WarehouseMiddleware ต้องทำงานก่อน controller");
        if (string.IsNullOrWhiteSpace(actor.RequestId))
            throw new InvalidOperationException(
                "ไม่มี request id — WarehouseMiddleware ต้องทำงานก่อน controller");

        await using var transaction = await db.Database.BeginTransactionAsync(ct);

        // Warehouse-scoped by the repository. A document of another site reads
        // as absent rather than forbidden — saying "forbidden" would confirm the
        // number exists somewhere the caller may not look.
        var shipment = await shipments.GetAsync(key, ct)
            ?? throw DomainException.NotFound($"ไม่พบใบปิดบรรทุก {key}");

        var decision = policy.CanMarkInvoiced(shipment);
        if (!decision.IsAllowed)
        {
            throw new DomainException(decision.Message, decision.Kind == RefusalKind.Incomplete
                ? StatusCodes.Status422UnprocessableEntity
                : StatusCodes.Status409Conflict);
        }

        // The whole of the concurrency check, and it is one line: EF puts the
        // original ROWVER into the UPDATE's WHERE clause, so telling it that the
        // original is what the caller sent makes SQL Server decide. Comparing
        // the loaded row's version by hand here would be a check against a value
        // that could change between the read and the write.
        db.Entry(shipment).Property(s => s.RowVer).OriginalValue = expected;

        var now = DateTime.UtcNow;
        var status = shipment.Status;

        shipment.InvoicedAt = now;
        shipment.InvoicedBy = actor.CurrentUser;

        // FROMSTATUS and TOSTATUS are the same value, and that is the record: it
        // says in the audit trail itself that invoicing left the lifecycle
        // alone, rather than leaving a reader to infer it from two empty columns.
        await audit.WriteAsync(new DocumentAuditRow
        {
            DocumentType = DocumentAuditWriter.ShipmentDocument,
            DocumentKey = shipment.ShipmentKey,
            Action = AuditAction.Invoiced,
            FromStatus = status,
            ToStatus = status,
            Actor = actor.CurrentUser,
            RequestId = actor.RequestId,
            ChangedAt = now,
            Metadata = JsonSerializer.Serialize(new
            {
                invoicedAt = now.ToString("yyyy-MM-ddTHH:mm:ss.fffZ"),
                invoicedBy = actor.CurrentUser,
                warehouse = warehouse.CurrentWarehouseId,
            }, AuditJson),
        }, ct);

        try
        {
            // One call, so the UPDATE and the audit INSERT go as one batch. If
            // the audit fails, the shipment is not invoiced; if the shipment is
            // gone or has moved on, no audit row is written for something that
            // did not happen.
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateConcurrencyException)
        {
            await transaction.RollbackAsync(ct);
            throw new ConcurrencyConflictException(
                $"ใบปิดบรรทุก {key} ถูกแก้ไขไปแล้วหลังจากที่คุณเปิดหน้านี้ — โหลดใหม่แล้วลองอีกครั้ง",
                await CurrentVersionAsync(key, ct));
        }

        await transaction.CommitAsync(ct);

        // ROWVER is not incremented here and must not be: SQL Server stamps it
        // on the UPDATE, and EF reads the new value back as part of the same
        // statement. shipment.RowVer is the V2 the caller has to be given.
        return shipment;
    }

    /// <summary>
    /// METADATA is read by people, in the database, when something is being
    /// explained after the fact. The default encoder ships every Thai character
    /// as a \u0E-escape, which is valid JSON and unreadable in exactly the place
    /// this column exists to be read — the same reason Program.cs sets this on
    /// the API's responses.
    /// </summary>
    private static readonly JsonSerializerOptions AuditJson = new()
    {
        Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
    };

    /// <summary>
    /// The version the database holds now, read after the failed write has been
    /// rolled back.
    ///
    /// Untracked and re-queried rather than taken from the entity in memory: the
    /// point of the answer is to tell the caller what they did not know, and the
    /// tracked copy still holds the version they sent. A row that has since been
    /// deleted answers empty rather than throwing — the caller's next read will
    /// find it gone, which is the truer error.
    /// </summary>
    private async Task<string> CurrentVersionAsync(string shipmentKey, CancellationToken ct)
    {
        var whse = warehouse.CurrentWarehouseId;
        var latest = await db.Set<ShipmentRow>()
            .AsNoTracking()
            .Where(s => s.WhseId == whse && s.ShipmentKey == shipmentKey)
            .Select(s => s.RowVer)
            .FirstOrDefaultAsync(ct);

        return DocumentIdentity.EncodeVersion(latest);
    }

    // ── ยังไม่ได้ทำ · not implemented yet ──────────────────────────────────
    //
    // Each of these is its own vertical slice, and each brings something the
    // invoice slice did not need: a document number to allocate, a send attempt
    // to record, stops and details to rewrite, a plan to hand back. They stay on
    // TmsStore until they are moved over one at a time, with the same treatment
    // invoicing got — an HTTP-level test against real SQL before the next one
    // starts. Nothing calls them; the endpoints for them still go to the store.

    public Task<ShipmentRow> UpdateAsync(
        string shipmentKey, ShipmentHeaderInput input, string ifMatch, CancellationToken ct = default) =>
        throw new NotImplementedException("ยังไม่ได้ย้าย 'แก้ไขใบปิดบรรทุก' มาที่ SQL — ยังใช้ TmsStore");

    public Task<ShipmentRow> ConfirmAsync(string shipmentKey, string ifMatch, CancellationToken ct = default) =>
        throw new NotImplementedException("ยังไม่ได้ย้าย 'ยืนยัน' มาที่ SQL — ยังใช้ TmsStore");

    public Task<ShipmentRow> SendAsync(string shipmentKey, string ifMatch, CancellationToken ct = default) =>
        throw new NotImplementedException("ยังไม่ได้ย้าย 'ส่งให้ MMX' มาที่ SQL — ยังใช้ TmsStore");

    public Task<ShipmentRow> RetryAsync(string shipmentKey, string ifMatch, CancellationToken ct = default) =>
        throw new NotImplementedException("ยังไม่ได้ย้าย 'ส่งซ้ำ' มาที่ SQL — ยังใช้ TmsStore");

    public Task<ShipmentRow> CancelAsync(
        string shipmentKey, string reason, string ifMatch, CancellationToken ct = default) =>
        throw new NotImplementedException("ยังไม่ได้ย้าย 'ยกเลิก' มาที่ SQL — ยังใช้ TmsStore");

    public Task<ShipmentRow> DeleteAsync(
        string shipmentKey, string? reason, string ifMatch, CancellationToken ct = default) =>
        throw new NotImplementedException("ยังไม่ได้ย้าย 'ลบ' มาที่ SQL — ยังใช้ TmsStore");

    public Task<ReissueResult> ReissueAsync(string shipmentKey, CancellationToken ct = default) =>
        throw new NotImplementedException("ยังไม่ได้ย้าย 'ออกใบใหม่' มาที่ SQL — ยังใช้ TmsStore");

    public Task<ShipmentRow> ApplyExternalStatusAsync(
        ExternalStatusInput input, CancellationToken ct = default) =>
        throw new NotImplementedException("ยังไม่ได้ย้าย 'รับสถานะกลับ' มาที่ SQL — ยังใช้ TmsStore");
}
