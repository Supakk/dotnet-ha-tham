namespace Mammod.Database.Documents;

/// <summary>
/// Writes TMS_DOCUMENT_AUDIT — what a person did, to which document, and why.
///
/// <b>It does not save.</b> The row is added to the change tracker and left
/// there for the caller's <c>SaveChangesAsync</c>, so the audit and the change
/// it describes go to the database in one batch inside one transaction. Saving
/// here instead would mean a shipment could be invoiced with no record of it, or
/// a record written for an update that then rolled back — and an audit trail
/// that is sometimes wrong is worse than none, because it is believed.
///
/// The warehouse is stamped from the request context, never from the row handed
/// in: an audit row filed under the wrong site is a hole in exactly the
/// isolation the rest of the layer enforces.
/// </summary>
public sealed class DocumentAuditWriter(
    AppDbContext db, IWarehouseContext warehouse, IActorContext actor) : IDocumentAuditWriter
{
    /// <summary>The document types CK_TMS_DOCUMENT_AUDIT_TYPE allows.</summary>
    public const string ShipmentDocument = "SHIPMENT";
    public const string PlanDocument = "PLAN";
    public const string SendAttemptDocument = "SEND_ATTEMPT";

    public Task WriteAsync(DocumentAuditRow entry, CancellationToken ct = default)
    {
        entry.WhseId = warehouse.CurrentWarehouseId;

        // ACTOR and CHANGEDAT are NOT NULL in the table. Filled from the request
        // context when the caller left them blank rather than defaulted in the
        // database, so a row can always say who without the reader having to
        // know which rows were written by which code path.
        if (string.IsNullOrWhiteSpace(entry.Actor)) entry.Actor = actor.CurrentUser;
        if (string.IsNullOrWhiteSpace(entry.RequestId)) entry.RequestId = actor.RequestId;
        if (entry.ChangedAt == default) entry.ChangedAt = DateTime.UtcNow;

        db.Set<DocumentAuditRow>().Add(entry);
        return Task.CompletedTask;
    }
}
