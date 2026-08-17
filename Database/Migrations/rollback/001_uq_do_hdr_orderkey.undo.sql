/* =========================================================================
   ROLLBACK 001 — delivery-order business key and its foreign keys
   =========================================================================
   Drops, in dependency order:

       FK_DOC_TRANSPORT_PLAN_LINE_DO
       FK_DOC_SHIPMENT_DETAIL_DO
       UQ_DOC_DO_HDR_ORDER

   The foreign keys go first: the unique index is what they reference, and
   SQL Server will not drop it while they exist.

   No rows are read or written. This removes enforcement, not data — but that
   is the point worth understanding before running it. Afterwards nothing
   stops a shipment detail naming an order that does not exist, and nothing
   stops two delivery orders sharing a business key. The pending-pool query
   would then be able to return the same order twice.

   Does not touch UX_SHIPMENT_DETAIL_ORDER or
   UX_DOC_TRANSPORT_PLAN_LINE_ORDER — those filtered unique indexes came with
   the original schema and are what keep an order on one live document.
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

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_DOC_TRANSPORT_PLAN_LINE_DO')
BEGIN
    ALTER TABLE dbo.DOC_TRANSPORT_PLAN_LINE DROP CONSTRAINT FK_DOC_TRANSPORT_PLAN_LINE_DO;
    PRINT 'rollback 001: dropped FK_DOC_TRANSPORT_PLAN_LINE_DO.';
END
GO

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_DOC_SHIPMENT_DETAIL_DO')
BEGIN
    ALTER TABLE dbo.DOC_SHIPMENT_DETAIL DROP CONSTRAINT FK_DOC_SHIPMENT_DETAIL_DO;
    PRINT 'rollback 001: dropped FK_DOC_SHIPMENT_DETAIL_DO.';
END
GO

IF EXISTS (SELECT 1 FROM sys.indexes
           WHERE name = 'UQ_DOC_DO_HDR_ORDER' AND object_id = OBJECT_ID('dbo.DOC_DO_HDR'))
BEGIN
    DROP INDEX UQ_DOC_DO_HDR_ORDER ON dbo.DOC_DO_HDR;
    PRINT 'rollback 001: dropped UQ_DOC_DO_HDR_ORDER.';
END
GO

/* The schema's own guarantees must be untouched. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_SHIPMENT_DETAIL_ORDER')
    THROW 50004, 'rollback 001 verification failed: UX_SHIPMENT_DETAIL_ORDER is gone. It predates this migration.', 1;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_DOC_TRANSPORT_PLAN_LINE_ORDER')
    THROW 50004, 'rollback 001 verification failed: UX_DOC_TRANSPORT_PLAN_LINE_ORDER is gone. It predates this migration.', 1;
GO

DELETE FROM dbo.TMS_SCHEMA_MIGRATION WHERE VERSION = '001';
GO

COMMIT TRANSACTION;
GO
