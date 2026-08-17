# TMS schema migrations

Additive changes to `MMDEV`, applied in order by `Run-Migrations.ps1`.

The schema this project inherited is built by `docs/data-model/*.sql`, which
creates the database from nothing. These are different: they change a database
that already holds documents, so every one of them checks before it acts and
refuses rather than repairs.

## Rules every migration here follows

**Preflight, apply, verify — in one transaction.** SQL Server runs DDL inside a
transaction, so a migration that fails its own verification rolls back whole.
Nothing is left half-applied for someone to find later.

**`THROW` on anything unexpected.** A duplicate key, an orphan row, an object
that already exists with the wrong shape: all of them stop the run. None of them
is repaired automatically. Deleting a row to make a constraint pass would be
choosing which document to lose, and that is not a migration's decision.

**Existence is not correctness.** `IF NOT EXISTS (…) CREATE` is only used where
the check proves the object is the one wanted. Where a name could exist with a
different definition — a constraint, an index — the definition is inspected and
a mismatch stops the run.

**Additive only.** Columns are added nullable, tables are created, constraints
are added. Nothing here drops, truncates, rewrites a status or invents a
historical actor. Where history has no answer, the column stays `NULL`; a made-up
`ADDWHO` is worse than an honest blank.

## Comments are in English

Unlike the rest of the project, deliberately. `sqlcmd` reads a file as the
system code page unless it starts with a UTF-8 BOM, and a BOM is easy to lose to
an editor or a copy-paste. Thai comments that silently turn into mojibake in a
migration nobody re-reads are not worth the risk; the file names and this README
carry the explanation instead.

## Order

| Version | File | What it does |
|---|---|---|
| 000 | `000_create_migration_history.sql` | The tracking table the runner reads |
| 001 | `001_uq_do_hdr_orderkey.sql` | Delivery-order business key + the two FKs that close the last integrity gap |
| 002 | `002_add_plan_lifecycle_fields.sql` | Who issued/cancelled a plan, and when |
| 003 | `003_add_shipment_lifecycle_fields.sql` | The same for shipments, plus `RELATIONTYPE` and invoice metadata |
| 004 | `004_create_tms_send_attempt.sql` | One row per hand-off attempt to MMX |
| 005 | `005_create_tms_document_audit.sql` | Audit across plans and shipments |
| 006 | `006_create_tms_document_number.sql` | Global `MN-`/`PL-` allocation |
| 007 | `007_add_global_keys_and_status_check.sql` | Global document identity + the shipment status domain |

Rollbacks are `rollback/NNN_*.sql`, applied in **reverse** order. They undo only
what their migration created — see the header of each one.

## Running

```powershell
# what would happen, without touching anything
.\Run-Migrations.ps1 -WhatIf

# apply everything outstanding
.\Run-Migrations.ps1

# roll back to and including a version
.\Run-Migrations.ps1 -RollbackTo 004
```

The runner refuses to re-run a version whose checksum has changed since it was
applied. That is the case worth being strict about: the file on disk no longer
describes what the database actually had done to it, and guessing which is right
is how a schema and its history stop matching.
