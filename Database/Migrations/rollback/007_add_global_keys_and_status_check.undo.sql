/* =========================================================================
   ROLLBACK 007 — global document identity, shipment status domain
   =========================================================================
   Drops only the three objects migration 007 created:

       UQ_DOC_SHIPMENT_HDR_KEY
       UQ_DOC_TRANSPORT_PLAN_KEY
       CK_SHIPMENT_HDR_STATUS

   Not CK_DOC_TRANSPORT_PLAN_STATUS — that shipped with the original schema and
   is nothing to do with this migration. Not the composite primary keys, which
   007 never touched.

   No business data is read or written. Dropping a constraint cannot lose a
   document; it only stops the database enforcing something the application
   still believes.

   After this runs the application must not be left creating documents: the
   global uniqueness the API's identifiers depend on is no longer guaranteed.
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

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_SHIPMENT_HDR_STATUS')
BEGIN
    ALTER TABLE dbo.DOC_SHIPMENT_HDR DROP CONSTRAINT CK_SHIPMENT_HDR_STATUS;
    PRINT 'rollback 007: dropped CK_SHIPMENT_HDR_STATUS.';
END
GO

IF EXISTS (SELECT 1 FROM sys.indexes
           WHERE name = 'UQ_DOC_TRANSPORT_PLAN_KEY' AND object_id = OBJECT_ID('dbo.DOC_TRANSPORT_PLAN'))
BEGIN
    DROP INDEX UQ_DOC_TRANSPORT_PLAN_KEY ON dbo.DOC_TRANSPORT_PLAN;
    PRINT 'rollback 007: dropped UQ_DOC_TRANSPORT_PLAN_KEY.';
END
GO

IF EXISTS (SELECT 1 FROM sys.indexes
           WHERE name = 'UQ_DOC_SHIPMENT_HDR_KEY' AND object_id = OBJECT_ID('dbo.DOC_SHIPMENT_HDR'))
BEGIN
    DROP INDEX UQ_DOC_SHIPMENT_HDR_KEY ON dbo.DOC_SHIPMENT_HDR;
    PRINT 'rollback 007: dropped UQ_DOC_SHIPMENT_HDR_KEY.';
END
GO

DELETE FROM dbo.TMS_SCHEMA_MIGRATION WHERE VERSION = '007';
GO

COMMIT TRANSACTION;
GO
