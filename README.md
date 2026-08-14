# Project TMS Backend

ASP.NET Core backend for the Project TMS/WMS training project.

The main stack is **.NET 8 / C#**. Python is used only as a helper layer for API
smoke tests and development data generation.

## Current State

This backend stores data **in memory**. Restarting the API resets all transport
plans, manifests, pending stops, master data, and generated rows back to the
seed data.

The core transport business rules are already enforced on the server, but the
project is still a development/training backend, not production-ready.

> Warning: do not expose this service publicly yet.
>
> `/auth/login` does not validate passwords. It accepts an email address and
> issues a token. Anyone who can reach the server can request an admin-like
> session.
>
> Seed data is fictional. Do not put real customer names, tax IDs, phone numbers,
> license plates, secrets, or production data in `Data/Seed.cs`, the REST Client
> `.http` file, or any committed test payload.

## Requirements

- .NET SDK 8 or newer
- Python 3.10 or newer, only for scripts in `tests/`

## Run The API

```powershell
dotnet run
```

The API listens on:

```text
http://localhost:5080
```

Swagger is available during development:

```text
http://localhost:5080/swagger
```

For watch mode:

```powershell
dotnet watch
```

## Connect The Frontend

In the frontend project, set the API base URL:

```ini
VITE_API_BASE_URL=http://localhost:5080
VITE_API_LIVE=auth,manifests,transportPlans,...
```

Run both apps together:

- Backend: `http://localhost:5080`
- Frontend: `http://localhost:5700`

If the backend is not running, frontend screens that use live APIs will show a
server connection error.

## Project Map

| Path | Purpose |
| --- | --- |
| `Program.cs` | Service registration, CORS, auth, Swagger, middleware pipeline |
| `Controllers/` | HTTP endpoints; controllers unpack requests and delegate work |
| `Data/` | In-memory stores and business rules |
| `Models/` | Response/domain shapes shared with the frontend contracts |
| `Dtos/` | Request bodies accepted from clients |
| `Middleware/` | Error handling and JSON error responses |
| `Services/` | JWT key handling and token creation |
| `Database/` | EF Core context and the read path onto SQL Server |
| `tests/` | Python smoke tests and data generation helpers |
| `docs/data-model/` | SQL Server data-model notes and local DB scripts |

## Business Rules Enforced By The Backend

These rules live server-side because disabled frontend buttons are only a UI
convenience. Direct API calls must still be rejected when they break the domain.

| Rule | Main Location |
| --- | --- |
| A delivery stop can be in only one place: pending pool, plan, or manifest | `TmsStore` pool movement methods |
| A manifest cannot be confirmed until truck, driver, and route are assigned | `Manifest.IsAssigned()` |
| Manifests are editable only through `draft` and `confirmed`; `sent` locks them | `UpdateManifest` / `AssertStatus` |
| Splitting and moving stops are allowed only for `draft` manifests | `SplitManifest` / `MoveStops` |
| Invoicing is allowed only after the manifest has been sent or completed | `MarkInvoiced` |
| Completion and error status come from OMS-style status updates, not manual TMS changes | `ApplyExternalStatus` |
| Cancelling a plan or manifest returns its stops to the pending pool | `CancelPlan` / `CancelManifest` |
| Route colours are assigned and preserved by the server | `CreateManifest` / `UpdateManifest` |
| Freight cost is derived from `tripPrice + priceAdd - priceDeduct` | `FreightPricing.Total()` |
| Master codes and vehicle plates must stay unique | `Assert...Free` methods |
| One district can belong to only one delivery zone | `AssertAreasFree` |
| Integration secrets are returned masked, never as raw stored values | `IntegrationConfigStore` |

## API Smoke Tests

Start the backend first:

```powershell
dotnet run
```

Then run:

```powershell
python tests/api_smoke.py
```

Optional base URL:

```powershell
python tests/api_smoke.py --base-url http://localhost:5081
```

The smoke test checks:

- Login returns a usable access token.
- `/auth/me` reads the token.
- Seeded master endpoints return data.
- Duplicate carrier codes are rejected.
- A pending stop can move through plan, issue, assignment, confirm, send, and
  OMS status update.

Because the backend is in-memory, the transport lifecycle consumes seed stops.
Restart `dotnet run` to reset the data.

## Generate Development Data

Preview generated delivery orders as JSON:

```powershell
python tests/generate_data.py delivery-orders --count 20
```

Post generated delivery orders into a running API:

```powershell
python tests/generate_data.py delivery-orders --count 20 --post
```

Generate transport master data as carrier, driver, and vehicle sets:

```powershell
python tests/generate_data.py fleet --count 3 --post
```

Generated rows are not persisted. They disappear when the API restarts.

## Manual API Requests

The REST Client `.http` file contains endpoint examples for VS Code.

The usual flow is:

1. `POST /auth/login`
2. `GET /manifests/pending-stops`
3. `POST /transport-plans`
4. `PUT /transport-plans/{id}/stops`
5. `POST /transport-plans/{id}/issue`
6. `PUT /manifests/{id}` to assign truck, driver, and route
7. `POST /manifests/{id}/confirm`
8. `POST /manifests/{id}/send`
9. `POST /manifests/{id}/status`

## Configuration

`appsettings.json` contains non-secret defaults:

```jsonc
{
  "Jwt": { "Issuer": "...", "Audience": "..." },
  "Cors": { "Origins": ["http://localhost:5700"] },
  "Auth": { "RequireAuthentication": false }
}
```

If the frontend port changes, add the new origin to `Cors:Origins`.

### JWT Signing Key

The JWT signing key is never committed.

| Environment | Source |
| --- | --- |
| Development | Auto-generated on first run and stored in `.secrets/jwt-key` |
| Production | Required environment variable: `Jwt__Key` |

To generate a new key:

```powershell
node -e "console.log(require('crypto').randomBytes(48).toString('base64'))"
```

## Database Mode

The API runs with or without SQL Server. Which one is decided by a single
setting: a connection string named `Mmdev` in `appsettings.Development.json`.

| Connection string | Master lists come from |
| --- | --- |
| Set | `MMDEV` on SQL Server |
| Absent | The in-memory seed, as before |

It is optional rather than required so the project still starts with nothing
installed but the .NET SDK, which is what the smoke tests and the frontend
fixtures depend on.

Build the database first — see `docs/data-model/README.md` section 7:

```powershell
cd docs\data-model
.\build-local-db.ps1 -Server "(localdb)\MSSQLLocalDB" -Seed
```

Reading is wired up: `/warehouses`, `/delivery-zones`, `/routes`, `/carriers`,
`/fleet-vehicles` and `/drivers` are served from the database via
`Database/AppDbContext.cs` and `Database/MasterQueries.cs`.

### SO Means Shipment Order

`SO` in this project is the **ใบปิดบรรทุก** — `DOC_SHIPMENT_HDR`, the document a
truck runs against. It is not a sales order, and there is no sales-order table:
what a customer ordered is raised in SAP, forwarded by OMS, and reaches this
database only as a reference string in `DOC_DO_HDR.EXTERNORDERKEY`.

The name is used inconsistently in places that predate this note — the ER
diagram labels a table `DOC_SO_HDR` and means `DOC_DO_HDR`; the frontend's
`utils/shipmentOrders.ts` names a *screen*, not a document. `docs/data-model/README.md`
section 0.0 lays out every spelling and what each one actually refers to. Read
it before adding anything with SO in the name.

### Reads Only — And What That Costs

Writes still go to the in-memory stores, which own the business rules. Two
consequences follow, and both are visible rather than subtle:

- A row created by `POST /carriers` does **not** appear in `GET /carriers`. They
  are no longer the same collection.
- Master ids differ between the two sources. The database derives them from the
  real keys (`cr-CR-001`), while manifests still come from the seed and name
  `cr-1`. A manifest's `carrierId` therefore matches nothing in a database-backed
  carrier list.

Neither is a defect to be worked around; both are what a half-migrated system
looks like. They disappear when the documents move across too.

### What Is Left

1. Move `TmsStore` and `DeliveryOrderStore` from `List<T>` to `DbSet<T>`.
2. Wrap stop movement in a database transaction, so "an order is in one place
   only" survives two requests arriving together — the rule the in-memory
   `lock (_gate)` currently keeps.
3. Write masters through the same path, which removes the id mismatch above.

The store methods keep owning the rules. Only the storage changes.

## Not Done Yet

| Item | Note |
| --- | --- |
| Persistent writes | Reads come from SQL Server; every write is still in-memory |
| Real password verification | Login currently trusts email only |
| Role-level authorization | A valid token can currently call all endpoints |
| `/receipts` live backend | This is WMS inbound scope and still fixture-backed |
| Real MMX outbound integration | `SendManifest` writes an integration log only |
| Real OMS webhook | `POST /manifests/{id}/status` stands in for now |

## Production Checklist

Before deploying anywhere beyond a trusted local machine or LAN:

- Add real user storage and BCrypt password verification.
- Set a strong production `Jwt__Key`.
- Serve through HTTPS.
- Set `Cors:Origins` to the real frontend origins.
- Ensure `ASPNETCORE_ENVIRONMENT` is not `Development`.
- Add role-based `[Authorize]` policies.
- Move data storage from memory to a database.
- Store connection strings and secrets in environment variables or a secret
  manager.
- Add rate limiting to `/auth/login`.
- Do not commit real customer data or real integration credentials.

## Public Repo Rules

- Anything committed should be treated as permanently exposed, even if removed
  later.
- If a real key is committed, revoke the key. Do not rely on deleting the file.
- Keep fake secrets clearly fake, for example `EXAMPLE-NOT-A-REAL-SECRET`.
- Do not place production DDL or vendor-owned database dumps in this repository.

## References

- `docs/data-model/` - SQL Server schema notes, scripts, and ER diagrams
- The REST Client `.http` file - manual endpoint examples
- Frontend `src/features/*/api/*.mock.ts` - source fixture behavior mirrored by
  this backend

