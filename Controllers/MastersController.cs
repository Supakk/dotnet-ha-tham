using Mammod.Data;
using Mammod.Database;
using Mammod.Models;
using Microsoft.AspNetCore.Mvc;

namespace Mammod.Controllers;

/// <summary>
/// The master records the transport flow points at. Every one of these is the
/// same three calls — list, create, update — with one uniqueness rule enforced
/// in <see cref="TmsStore"/>. There is no delete anywhere: a retired row is set
/// <c>active: false</c> so the documents that already name it still read, which
/// a delete would break.
/// </summary>

[ApiController]
[Route("warehouses")]
public sealed class WarehousesController(TmsStore store, MasterQueries queries) : ControllerBase
{
    [HttpGet]
    public ActionResult<List<Warehouse>> List() => queries.Warehouses();

    [HttpPost]
    public ActionResult<Warehouse> Create([FromBody] Warehouse input) => store.CreateWarehouse(input);

    [HttpPut("{id}")]
    public ActionResult<Warehouse> Update(string id, [FromBody] Warehouse input) =>
        store.UpdateWarehouse(id, input);
}

/// <summary>
/// Delivery territories. Not routed at <c>/zones</c>: in the WMS data model a
/// ZONE is an area *inside* a warehouse (aisles and bays), a different table with
/// a different owner. A shared path would hand this screen the wrong rows and
/// nothing on the client could tell.
/// </summary>
[ApiController]
[Route("delivery-zones")]
public sealed class DeliveryZonesController(TmsStore store, MasterQueries queries) : ControllerBase
{
    [HttpGet]
    public ActionResult<List<DeliveryZone>> List() => queries.Zones();

    [HttpPost]
    public ActionResult<DeliveryZone> Create([FromBody] DeliveryZone input) => store.CreateZone(input);

    [HttpPut("{id}")]
    public ActionResult<DeliveryZone> Update(string id, [FromBody] DeliveryZone input) =>
        store.UpdateZone(id, input);
}

[ApiController]
[Route("routes")]
public sealed class RoutesController(TmsStore store, MasterQueries queries) : ControllerBase
{
    [HttpGet]
    public ActionResult<List<RouteMaster>> List() => queries.Routes();

    [HttpPost]
    public ActionResult<RouteMaster> Create([FromBody] RouteMaster input) => store.CreateRoute(input);

    [HttpPut("{id}")]
    public ActionResult<RouteMaster> Update(string id, [FromBody] RouteMaster input) =>
        store.UpdateRoute(id, input);
}

[ApiController]
[Route("carriers")]
public sealed class CarriersController(TmsStore store, MasterQueries queries) : ControllerBase
{
    [HttpGet]
    public ActionResult<List<Carrier>> List() => queries.Carriers();

    [HttpPost]
    public ActionResult<Carrier> Create([FromBody] Carrier input) => store.CreateCarrier(input);

    [HttpPut("{id}")]
    public ActionResult<Carrier> Update(string id, [FromBody] Carrier input) =>
        store.UpdateCarrier(id, input);
}

[ApiController]
[Route("fleet-vehicles")]
public sealed class FleetVehiclesController(TmsStore store, MasterQueries queries) : ControllerBase
{
    [HttpGet]
    public ActionResult<List<FleetVehicle>> List() => queries.Vehicles();

    [HttpPost]
    public ActionResult<FleetVehicle> Create([FromBody] FleetVehicle input) => store.CreateVehicle(input);

    [HttpPut("{id}")]
    public ActionResult<FleetVehicle> Update(string id, [FromBody] FleetVehicle input) =>
        store.UpdateVehicle(id, input);
}

[ApiController]
[Route("drivers")]
public sealed class DriversController(TmsStore store, MasterQueries queries) : ControllerBase
{
    [HttpGet]
    public ActionResult<List<Driver>> List() => queries.Drivers();

    [HttpPost]
    public ActionResult<Driver> Create([FromBody] Driver input) => store.CreateDriver(input);

    [HttpPut("{id}")]
    public ActionResult<Driver> Update(string id, [FromBody] Driver input) =>
        store.UpdateDriver(id, input);
}

/// <summary>
/// The administrative-area register, read-only. Zones point at these by name,
/// because that is what is printed on a delivery label and what a driver reads.
/// </summary>
[ApiController]
[Route("geo")]
public sealed class GeoController : ControllerBase
{
    [HttpGet("provinces")]
    public ActionResult<List<Province>> Provinces() => GeoSeed.Provinces();

    /// <summary>Query name is <c>province</c> — that is what the client's axios params send.</summary>
    [HttpGet("districts")]
    public ActionResult<List<District>> Districts([FromQuery] string? province) =>
        GeoSeed.Districts(province ?? "");
}
