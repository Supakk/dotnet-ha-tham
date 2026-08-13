using Mammod.Data;
using Mammod.Models;
using Microsoft.AspNetCore.Mvc;

namespace Mammod.Controllers;

/// <summary>
/// บันทึกการเชื่อมต่อ — every message in or out of TMS.
///
/// Only OMS (in) and MMX (out) ever appear. Task Assign, WMS and SAP have no
/// interface with TMS: what they do comes back as one <c>Status.Update</c> from
/// OMS, so a row naming them would be a row that cannot exist.
/// </summary>
[ApiController]
[Route("integration/messages")]
public sealed class IntegrationController(TmsStore store) : ControllerBase
{
    [HttpGet]
    public ActionResult<List<IntegrationMessage>> List() => store.ListMessages();

    /// <summary>
    /// Re-sends a failed outbound message. The retry is logged as its own entry
    /// and the original is marked `resolved` rather than overwritten — the
    /// failure stays on the record, which is the reason to keep a log at all.
    /// </summary>
    [HttpPost("{id}/retry")]
    public ActionResult<IntegrationMessage> Retry(string id) => store.RetryMessage(id);
}
