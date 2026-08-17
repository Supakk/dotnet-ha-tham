/* =========================================================================
   ROLLBACK 000 — migration tracking
   =========================================================================
   Drops TMS_SCHEMA_MIGRATION.

   Last in the rollback order, and it refuses while any other migration is
   still recorded as applied. Dropping the history while 001–007 are in the
   database would leave a schema nobody can reason about: the objects are
   there, the record that they were applied is not, and the next run would try
   to create them again.

   In practice this is only ever run to undo a migration setup that was never
   used.
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

IF OBJECT_ID('dbo.TMS_SCHEMA_MIGRATION', 'U') IS NOT NULL
BEGIN
    DECLARE @applied int = (SELECT COUNT(*) FROM dbo.TMS_SCHEMA_MIGRATION WHERE VERSION <> '000');

    IF @applied > 0
    BEGIN
        SELECT VERSION, NAME, APPLIEDAT FROM dbo.TMS_SCHEMA_MIGRATION
        WHERE VERSION <> '000' ORDER BY VERSION;

        THROW 50004, 'STOP: migrations are still recorded as applied. Roll those back first — dropping the history now would leave the schema and its record disagreeing.', 1;
    END

    DROP TABLE dbo.TMS_SCHEMA_MIGRATION;
    PRINT 'rollback 000: dropped dbo.TMS_SCHEMA_MIGRATION.';
END
ELSE
    PRINT 'rollback 000: TMS_SCHEMA_MIGRATION already absent.';
GO

COMMIT TRANSACTION;
GO
