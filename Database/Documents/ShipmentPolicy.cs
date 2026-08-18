namespace Mammod.Database.Documents;

/// <summary>
/// Every rule about when a ใบปิดบรรทุก may change, in one place and with no I/O.
///
/// The rules are not new. They were <c>AssertStatus(current, [...], "…")</c>
/// calls scattered through <see cref="Mammod.Data.TmsStore"/>, one beside each
/// mutation, which is why "when can this be cancelled" could only be answered by
/// reading the whole file. Moving them here does not change any of them — each
/// method below carries the line it came from.
///
/// Only <see cref="CanMarkInvoiced"/> is called today: the invoice slice is the
/// first mutation to run against SQL. The rest are written now because a policy
/// with one method in it is not a policy, and because the rule has to exist
/// somewhere a reader can compare the whole set at once. They will be wired up
/// as each mutation moves over; until then TmsStore is still the one enforcing
/// them, from the same rules.
/// </summary>
public sealed class ShipmentPolicy : IShipmentPolicy
{
    /// <summary>TmsStore.UpdateManifest — draft and confirmed.</summary>
    public PolicyResult CanEdit(ShipmentRow shipment) =>
        Require(shipment, "แก้ไข", ShipmentStatus.Draft, ShipmentStatus.Confirmed);

    /// <summary>TmsStore.ConfirmManifest — draft only.</summary>
    public PolicyResult CanConfirm(ShipmentRow shipment) =>
        Require(shipment, "ยืนยัน", ShipmentStatus.Draft);

    /// <summary>
    /// TmsStore.SendManifest — confirmed, or error, which is a resend after MMX
    /// refused it rather than a new document.
    /// </summary>
    public PolicyResult CanSend(ShipmentRow shipment) =>
        Require(shipment, "ส่งให้ MMX", ShipmentStatus.Confirmed, ShipmentStatus.Error);

    /// <summary>
    /// A retry is a fresh attempt at a hand-off that failed, so it needs a
    /// shipment that MMX rejected. A SENT one has already been taken.
    /// </summary>
    public PolicyResult CanRetry(ShipmentRow shipment) =>
        Require(shipment, "ส่งซ้ำ", ShipmentStatus.Error);

    /// <summary>
    /// TmsStore.CancelManifest — draft and confirmed. SENT is refused on purpose:
    /// the load may already be with MMX, and taking it back is a conversation,
    /// not a button.
    /// </summary>
    public PolicyResult CanCancel(ShipmentRow shipment) =>
        Require(shipment, "ยกเลิก", ShipmentStatus.Draft, ShipmentStatus.Confirmed);

    /// <summary>TmsStore.DeleteManifest — cancelled only.</summary>
    public PolicyResult CanDelete(ShipmentRow shipment) =>
        Require(shipment, "ลบ", ShipmentStatus.Cancelled);

    /// <summary>A replacement is only owed for a document that was called off.</summary>
    public PolicyResult CanReissue(ShipmentRow shipment) =>
        Require(shipment, "ออกใบใหม่", ShipmentStatus.Cancelled);

    /// <summary>
    /// TmsStore.MarkInvoiced — sent and completed. Nothing is invoiced before it
    /// has gone out: billing follows the load. A draft or a confirmed document
    /// is a plan, an error is a load MMX would not take, and a cancelled one
    /// never ran.
    ///
    /// Note what this does <b>not</b> exclude: a shipment that has already been
    /// invoiced. INVOICEDAT is not a status, so there is no state to read it off
    /// — re-invoicing is stopped by the concurrency token, not by this rule.
    /// </summary>
    public PolicyResult CanMarkInvoiced(ShipmentRow shipment) =>
        Require(shipment, "เปิดอินวอยซ์", ShipmentStatus.Sent, ShipmentStatus.Completed);

    /// <summary>
    /// TmsStore.ApplyExternalStatus — a callback only means something against a
    /// document we handed over. Anything else is late or duplicate: recorded and
    /// ignored, not an error to the sender.
    /// </summary>
    public PolicyResult CanApplyExternalStatus(ShipmentRow shipment, string outcome) =>
        Require(shipment, "รับสถานะกลับ", ShipmentStatus.Sent);

    /// <summary>
    /// The refusal names the status the user is looking at, in the words the
    /// screen uses — the same sentence TmsStore.AssertStatus produced, so a rule
    /// reads identically whichever side enforced it.
    /// </summary>
    private static PolicyResult Require(ShipmentRow shipment, string action, params string[] allowed) =>
        allowed.Contains(shipment.Status)
            ? PolicyResult.Allow()
            : PolicyResult.WrongState($"{action}ไม่ได้ เพราะเอกสารอยู่สถานะ \"{Label(shipment.Status)}\"");

    /// <summary>
    /// The database's uppercase status as the client's label. An unmapped one
    /// falls back to the raw value rather than throwing: a refusal that crashes
    /// on the way to being written is worse than one that names a status in
    /// English.
    /// </summary>
    private static string Label(string status) =>
        Mammod.Models.ManifestStatus.Label.TryGetValue(status.ToLowerInvariant(), out var label)
            ? label
            : status;
}
