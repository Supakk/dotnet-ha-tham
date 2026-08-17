/* =========================================================================
   000 — migration tracking
   =========================================================================
   Creates the table the runner reads to decide what still has to be applied.
   Touches no business table.

   Safe on a database that has never seen it. On one that has, the existing
   table is inspected rather than assumed: a table of this name with different
   columns belongs to something else, and quietly writing our rows into it
   would corrupt whatever that is.
   ========================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;
/* sqlcmd connects with QUOTED_IDENTIFIER OFF, which makes it impossible to
   create a filtered index. Set both explicitly so this file behaves the same
   however it is run - from sqlcmd, from SSMS, or from the runner. */
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

BEGIN TRANSACTION;
GO

/* --- preflight ---------------------------------------------------------- */

IF OBJECT_ID('dbo.TMS_SCHEMA_MIGRATION', 'U') IS NOT NULL
BEGIN
    /* It exists. Prove it is ours before using it. Missing any column we
       depend on means this is a different table wearing the same name. */
    DECLARE @missing nvarchar(400) = (
        SELECT STRING_AGG(needed.col, ', ')
        FROM (VALUES ('VERSION'), ('NAME'), ('CHECKSUM'), ('APPLIEDAT'),
                     ('APPLIEDBY'), ('SUCCESS')) AS needed(col)
        WHERE NOT EXISTS (
            SELECT 1 FROM sys.columns c
            WHERE c.object_id = OBJECT_ID('dbo.TMS_SCHEMA_MIGRATION')
              AND c.name = needed.col)
    );

    IF @missing IS NOT NULL
        THROW 50000, 'TMS_SCHEMA_MIGRATION already exists but is missing expected columns. Inspect it before continuing — this migration will not alter a table it does not recognise.', 1;

    PRINT '000: TMS_SCHEMA_MIGRATION already present and compatible — nothing to do.';
END
ELSE
BEGIN
    CREATE TABLE dbo.TMS_SCHEMA_MIGRATION
    (
        MIGRATIONID int IDENTITY(1,1) NOT NULL,

        /* The three-digit file prefix. Unique: a version is applied once. */
        VERSION     nvarchar(10)  NOT NULL,
        NAME        nvarchar(200) NOT NULL,

        /* SHA2_256 of the file as applied, hex. What makes an edited
           migration detectable instead of silently re-run. */
        CHECKSUM    nvarchar(64)  NOT NULL,

        APPLIEDAT   datetime2(3)  NOT NULL CONSTRAINT DF_TMS_SCHEMA_MIGRATION_AT DEFAULT (SYSUTCDATETIME()),
        APPLIEDBY   nvarchar(128) NOT NULL CONSTRAINT DF_TMS_SCHEMA_MIGRATION_BY DEFAULT (SUSER_SNAME()),

        /* Rows are only written after verification passes, so this is 1 in
           practice. Kept so a runner that records failures has somewhere to
           put them rather than inventing a column later. */
        SUCCESS     bit           NOT NULL CONSTRAINT DF_TMS_SCHEMA_MIGRATION_OK DEFAULT (1),

        DURATIONMS  int           NULL,
        NOTES       nvarchar(1000) NULL,

        CONSTRAINT PK_TMS_SCHEMA_MIGRATION PRIMARY KEY CLUSTERED (MIGRATIONID),
        CONSTRAINT UQ_TMS_SCHEMA_MIGRATION_VERSION UNIQUE (VERSION)
    );

    PRINT '000: created dbo.TMS_SCHEMA_MIGRATION.';
END
GO

/* --- verify ------------------------------------------------------------- */

IF OBJECT_ID('dbo.TMS_SCHEMA_MIGRATION', 'U') IS NULL
    THROW 50000, '000 verification failed: TMS_SCHEMA_MIGRATION was not created.', 1;

IF NOT EXISTS (SELECT 1 FROM sys.key_constraints
               WHERE name = 'UQ_TMS_SCHEMA_MIGRATION_VERSION'
                 AND parent_object_id = OBJECT_ID('dbo.TMS_SCHEMA_MIGRATION'))
   AND NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE name = 'UQ_TMS_SCHEMA_MIGRATION_VERSION'
                     AND object_id = OBJECT_ID('dbo.TMS_SCHEMA_MIGRATION'))
    THROW 50000, '000 verification failed: VERSION is not unique. A duplicate version would let one migration be recorded twice.', 1;

PRINT '000: verified.';
GO

COMMIT TRANSACTION;
GO
