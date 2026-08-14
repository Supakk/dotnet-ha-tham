# Python API Smoke Tests

These scripts keep Python as a test helper only. The backend stack stays .NET/C#.

Requires Python 3.10 or newer.

## Run

Start the API first:

```powershell
dotnet run
```

Then run the smoke test in another terminal:

```powershell
python tests/api_smoke.py
```

The default base URL is `http://localhost:5080`. Override it when needed:

```powershell
python tests/api_smoke.py --base-url http://localhost:5081
```

## What It Checks

- Login returns a bearer token and `/auth/me` can read it.
- Seeded master-data endpoints return lists.
- Duplicate carrier codes are rejected by the backend rule.
- A pending stop can move through plan, issue, assignment, confirm, send, and OMS status update.

The transport lifecycle consumes in-memory seed stops. If you run it repeatedly against the same `dotnet run` process, restart the backend to reset seed data.

## Generate Dev Data

Preview generated delivery orders as JSON:

```powershell
python tests/generate_data.py delivery-orders --count 20
```

Post them into the running API:

```powershell
python tests/generate_data.py delivery-orders --count 20 --post
```

Generate transport master data as carrier, driver, and vehicle sets:

```powershell
python tests/generate_data.py fleet --count 3 --post
```

The backend is currently in-memory, so generated rows disappear when `dotnet run` restarts.

## Generate Data Into SQL Server

`generate_data.py` POSTs at the API, so its rows live only as long as the
process. `generate_sql_data.py` writes into the `MMDEV` database instead, so the
rows survive a restart and can be inspected in VS Code next to the API.

It does not talk to SQL Server itself. Neither `pyodbc` nor `pymssql` ships with
Python, and requiring a native ODBC driver just to see demo rows is a poor trade
— `sqlcmd` is already needed to build the database at all. So the script writes
`docs/data-model/03-seed-demo-data.sql` and, with `--apply`, hands it to
`sqlcmd`. The file is worth having anyway: it can be read before it is run, or
given to somebody with database access but no Python.

Build the database first (see `docs/data-model/README.md` section 7), then:

```powershell
py -3 tests/generate_sql_data.py                  # write the .sql and show a summary
py -3 tests/generate_sql_data.py --apply          # write it and run it
py -3 tests/generate_sql_data.py --orders 500 --apply
py -3 tests/generate_sql_data.py --server ".\SQLEXPRESS" --apply
```

Or build and seed in one step:

```powershell
cd docs\data-model
.\build-local-db.ps1 -Server "(localdb)\MSSQLLocalDB" -Seed
```

### What It Writes

| Group | Tables | Rows |
| --- | --- | --- |
| Warehouses and owner | `MST_WHSE` `MST_OWNER` | 6 |
| Delivery zones | `MST_TRANSPORTATIONZONE` `MST_ZONE_COVERAGE` `MST_ROUTE_ZONE` | 63 |
| Routes | `MST_ROUTE` | 4 |
| Fleet | `MST_TRANSPORTER` `MST_VEHICLETYPE` `MST_VEHICLE` `MST_DRIVER` | 19 |
| Customers and SKUs | `MST_CUSTOMER` `MST_SKU` | 18 |
| Users | `MST_USER` `MST_USER_MODULE` | 21 |
| Delivery orders | `DOC_DO_HDR` `DOC_DO_DETAIL` | 125 at `--orders 40` |
| Transport plan | `DOC_TRANSPORT_PLAN` `_LINE` | 1 |
| Manifests | `DOC_SHIPMENT_HDR` `_STOP` `_DETAIL` `_DETAIL_LINE` `_STATUS_LOG` | 59 |

The fixed rows mirror `Data/Seed.cs` — same warehouse codes, zones, routes,
carriers, vehicles, drivers, and the five manifests parked one at each step of
ติดตามสถานะ (draft, confirmed, sent, completed, error). A screen therefore shows
the same thing whether it reads the in-memory store or the database.
`--orders` adds generated delivery orders on top for anything that needs volume
rather than a known fixture; their due dates are spread either side of the
fixture date so overdue styling has something to catch.

Re-running is safe. The script deletes the rows it owns in reverse foreign-key
order before inserting, and wraps everything in one transaction with
`XACT_ABORT ON`, so a failure leaves the database exactly as it was.

`--seed` fixes the RNG, so the same arguments always produce the same file.
Regenerate rather than editing `03-seed-demo-data.sql` by hand — the next run
overwrites it.

### All Rows Are Fictional

Company names, tax IDs, phone numbers, licence plates, and addresses are made up
and meant to look it. E-mail addresses use `.test`, which RFC 2606 reserves so it
can never be registered. **Do not replace any of it with real customer data** —
the generated file is committed to a public repository.

`MST_USER.PASSWORDHASH` holds a sentence saying passwords are not checked, not a
hash. A realistic-looking bcrypt digest there would imply a verification step
that does not exist yet.

