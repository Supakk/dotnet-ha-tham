/* =========================================================================
   003 — shipment lifecycle, lineage and invoice metadata
   =========================================================================
   Three groups of columns, all nullable, none backfilled.

   1. Lifecycle actors and timestamps. CONFIRMDATE and SENTDATE already exist;
      who did it did not, and neither did the moment a shipment completed.

   2. Lineage. PARENT_SHIPMENTKEY already records which shipment a new one came
      out of — but not why. A split and a reissue produce the same shape of row
      and mean opposite things: a split divides a load across two trucks, a
      reissue replaces a document that was cancelled. RELATIONTYPE is what tells
      them apart, from the row itself rather than by cross-referencing an audit
      log.

   3. Invoicing. INVOICEDAT/INVOICEDBY exist so that invoicing stops being a
      lifecycle status. Overwriting SENT or COMPLETED with INVOICED destroyed
      the answer to "did this load actually arrive" — a document that was
      invoiced and one that was delivered are different facts, and a shipment
      can be both.

   EXTERNALREFERENCE is what MMX knows the document as. Identical across every
   send attempt of the same shipment, which is what makes a retry recognisable
   to them as the same work rather than a second job.
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

IF OBJECT_ID('dbo.DOC_SHIPMENT_HDR', 'U') IS NULL
    THROW 50000, 'STOP: DOC_SHIPMENT_HDR does not exist.', 1;

DECLARE @wrongType nvarchar(400) = (
    SELECT STRING_AGG(c.name + ' is ' + t.name, ', ')
    FROM sys.columns c
    JOIN sys.types t ON t.user_type_id = c.user_type_id
    WHERE c.object_id = OBJECT_ID('dbo.DOC_SHIPMENT_HDR')
      AND ((c.name IN ('CONFIRMBY','SENTBY','CANCELLEDBY','DELETEDBY','INVOICEDBY',
                       'DELETEREASON','EXTERNALREFERENCE','RELATIONTYPE') AND t.name <> 'nvarchar')
        OR (c.name IN ('COMPLETEDDATE','CANCELLEDDATE','DELETEDDATE','INVOICEDAT')
            AND t.name NOT IN ('datetime','datetime2'))
        OR (c.name = 'RETRYCOUNT' AND t.name <> 'int'))
);

IF @wrongType IS NOT NULL
    THROW 50002, 'STOP: a column of one of these names already exists on DOC_SHIPMENT_HDR with an unexpected type. Inspect before continuing.', 1;
GO

/* --- apply: lifecycle actors and timestamps ----------------------------- */

IF COL_LENGTH('dbo.DOC_SHIPMENT_HDR', 'CONFIRMBY') IS NULL
    ALTER TABLE dbo.DOC_SHIPMENT_HDR ADD CONFIRMBY nvarchar(100) NULL;
GO
IF COL_LENGTH('dbo.DOC_SHIPMENT_HDR', 'SENTBY') IS NULL
    ALTER TABLE dbo.DOC_SHIPMENT_HDR ADD SENTBY nvarchar(100) NULL;
GO
IF COL_LENGTH('dbo.DOC_SHIPMENT_HDR', 'COMPLETEDDATE') IS NULL
    ALTER TABLE dbo.DOC_SHIPMENT_HDR ADD COMPLETEDDATE datetime NULL;
GO
IF COL_LENGTH('dbo.DOC_SHIPMENT_HDR', 'CANCELLEDBY') IS NULL
    ALTER TABLE dbo.DOC_SHIPMENT_HDR ADD CANCELLEDBY nvarchar(100) NULL;
GO
IF COL_LENGTH('dbo.DOC_SHIPMENT_HDR', 'CANCELLEDDATE') IS NULL
    ALTER TABLE dbo.DOC_SHIPMENT_HDR ADD CANCELLEDDATE datetime NULL;
GO

/* --- apply: soft delete -------------------------------------------------
   Separate from cancellation on purpose. A delete removes a document raised
   by mistake and should not count as a cancelled run; a cancellation is a
   business decision with a reason attached. Reporting that cannot tell them
   apart will overstate how often runs are called off. */

IF COL_LENGTH('dbo.DOC_SHIPMENT_HDR', 'DELETEDBY') IS NULL
    ALTER TABLE dbo.DOC_SHIPMENT_HDR ADD DELETEDBY nvarchar(100) NULL;
GO
IF COL_LENGTH('dbo.DOC_SHIPMENT_HDR', 'DELETEDDATE') IS NULL
    ALTER TABLE dbo.DOC_SHIPMENT_HDR ADD DELETEDDATE datetime NULL;
GO
IF COL_LENGTH('dbo.DOC_SHIPMENT_HDR', 'DELETEREASON') IS NULL
    ALTER TABLE dbo.DOC_SHIPMENT_HDR ADD DELETEREASON nvarchar(500) NULL;
GO

/* --- apply: integration ------------------------------------------------- */

IF COL_LENGTH('dbo.DOC_SHIPMENT_HDR', 'RETRYCOUNT') IS NULL
    ALTER TABLE dbo.DOC_SHIPMENT_HDR ADD RETRYCOUNT int NULL;
GO
IF COL_LENGTH('dbo.DOC_SHIPMENT_HDR', 'EXTERNALREFERENCE') IS NULL
    ALTER TABLE dbo.DOC_SHIPMENT_HDR ADD EXTERNALREFERENCE nvarchar(50) NULL;
GO

/* --- apply: invoice metadata -------------------------------------------- */

IF COL_LENGTH('dbo.DOC_SHIPMENT_HDR', 'INVOICEDAT') IS NULL
    ALTER TABLE dbo.DOC_SHIPMENT_HDR ADD INVOICEDAT datetime NULL;
GO
IF COL_LENGTH('dbo.DOC_SHIPMENT_HDR', 'INVOICEDBY') IS NULL
    ALTER TABLE dbo.DOC_SHIPMENT_HDR ADD INVOICEDBY nvarchar(100) NULL;
GO

/* --- apply: lineage ----------------------------------------------------- */

IF COL_LENGTH('dbo.DOC_SHIPMENT_HDR', 'RELATIONTYPE') IS NULL
    ALTER TABLE dbo.DOC_SHIPMENT_HDR ADD RELATIONTYPE nvarchar(20) NULL;
GO

/* NULL for an original document; REISSUE or SPLIT for one with a parent.
   The constraint also refuses a relation type with no parent to point at,
   which would be a lineage that names a reason and no relative. */
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_SHIPMENT_HDR_RELATIONTYPE')
    ALTER TABLE dbo.DOC_SHIPMENT_HDR WITH CHECK
        ADD CONSTRAINT CK_SHIPMENT_HDR_RELATIONTYPE CHECK
        (
            (RELATIONTYPE IS NULL)
            OR (RELATIONTYPE IN ('REISSUE', 'SPLIT') AND PARENT_SHIPMENTKEY IS NOT NULL)
        );
GO

/* --- verify ------------------------------------------------------------- */

DECLARE @missing nvarchar(600) = (
    SELECT STRING_AGG(needed.col, ', ')
    FROM (VALUES ('CONFIRMBY'),('SENTBY'),('COMPLETEDDATE'),('CANCELLEDBY'),('CANCELLEDDATE'),
                 ('DELETEDBY'),('DELETEDDATE'),('DELETEREASON'),('RETRYCOUNT'),
                 ('EXTERNALREFERENCE'),('INVOICEDAT'),('INVOICEDBY'),('RELATIONTYPE')) AS needed(col)
    WHERE COL_LENGTH('dbo.DOC_SHIPMENT_HDR', needed.col) IS NULL
);

IF @missing IS NOT NULL
    THROW 50003, '003 verification failed: columns missing after apply.', 1;

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_SHIPMENT_HDR_RELATIONTYPE')
    THROW 50003, '003 verification failed: CK_SHIPMENT_HDR_RELATIONTYPE missing.', 1;

IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = 'CK_SHIPMENT_HDR_RELATIONTYPE' AND is_not_trusted = 1)
    THROW 50003, '003 verification failed: CK_SHIPMENT_HDR_RELATIONTYPE was not validated against existing rows.', 1;

IF EXISTS (SELECT 1 FROM dbo.DOC_SHIPMENT_HDR
           WHERE RELATIONTYPE IS NOT NULL OR INVOICEDAT IS NOT NULL OR RETRYCOUNT IS NOT NULL
              OR CONFIRMBY IS NOT NULL OR SENTBY IS NOT NULL OR DELETEDBY IS NOT NULL)
    THROW 50003, '003 verification failed: a new column already holds data. This migration backfills nothing.', 1;

PRINT '003: verified — 13 columns and 1 check constraint added, no data written.';
GO

COMMIT TRANSACTION;
GO
