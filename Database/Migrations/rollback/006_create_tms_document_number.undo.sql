/* =========================================================================
   ROLLBACK 006 — TMS_DOCUMENT_NUMBER
   =========================================================================
   Drops the allocator table.

   The rows in it are counters, not documents: dropping them loses the record
   of which numbers have been handed out, not the documents that carry those
   numbers. Re-running migration 006 rebuilds the counters from the documents
   themselves, so the sequence resumes correctly.

   The one thing this cannot restore is a number allocated to a transaction
   that then rolled back — a gap. Gaps are harmless; a repeat would not be,
   and re-seeding from MAX() cannot produce one.

   Refuses if anything now references the table, which nothing should: it has
   no dependents by design.
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

IF OBJECT_ID('dbo.TMS_DOCUMENT_NUMBER', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM sys.foreign_keys
               WHERE referenced_object_id = OBJECT_ID('dbo.TMS_DOCUMENT_NUMBER'))
        THROW 50004, 'STOP: something now references TMS_DOCUMENT_NUMBER. Drop the dependent constraint first.', 1;

    DROP TABLE dbo.TMS_DOCUMENT_NUMBER;
    PRINT 'rollback 006: dropped dbo.TMS_DOCUMENT_NUMBER.';
END
ELSE
    PRINT 'rollback 006: TMS_DOCUMENT_NUMBER already absent.';
GO

DELETE FROM dbo.TMS_SCHEMA_MIGRATION WHERE VERSION = '006';
GO

COMMIT TRANSACTION;
GO
