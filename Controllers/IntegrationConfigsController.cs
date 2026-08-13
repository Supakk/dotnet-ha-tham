using Mammod.Data;
using Microsoft.AspNetCore.Mvc;

namespace Mammod.Controllers;

/// <summary>
/// ค่าเชื่อมต่อระบบ — token and base URL for each system TMS talks to, edited on
/// the settings screen. Secrets go out masked and never come back in that form:
/// see <see cref="IntegrationConfigStore"/> for why.
/// </summary>
[ApiController]
[Route("integrations/configs")]
public sealed class IntegrationConfigsController(IntegrationConfigStore store) : ControllerBase
{
    [HttpGet]
    public ActionResult<List<IntegrationConfig>> List() => store.List();

    [HttpPut("{key}")]
    public ActionResult<IntegrationConfig> Save(string key, [FromBody] IntegrationConfigInput input) =>
        store.Save(key, input);

    /// <summary>Asks the server to reach the system with the stored credentials.</summary>
    [HttpPost("{key}/test")]
    public ActionResult<IntegrationTestResult> Test(string key) => store.Test(key);
}
