/* =========================================================================
   007 — global document identity, and the shipment status domain
   =========================================================================
   Two invariants the application now depends on, made true by the database
   rather than by convention.

   1. SHIPMENTKEY and PLANKEY are globally unique.

      The composite primary keys stay as they are — (WHSEID, SHIPMENTKEY) is
      still what identifies a row, and warehouse still scopes every query. But
      the public API identifies a manifest by its number alone:

          GET /manifests/MN-202608-0041

      For that to resolve to one document, the number has to be unique across
      warehouses, not within one. The data already works this way; these
      constraints stop it quietly ceasing to.

   2. STATUS is one of seven values.

      DOC_TRANSPORT_PLAN has had a status check since it was created.
      DOC_SHIPMENT_HDR never did, so a typo in any code path that wrote it
      would have produced a document in a state nothing could handle.

      The seven are the target lifecycle. INVOICED is deliberately absent —
      migration 003 made invoicing a pair of columns instead, so that a
      shipment can be both delivered and invoiced rather than having to choose
      which fact its status records.

   Existing values are verified first. Anything outside the seven stops the
   migration; rewriting a historical status to make a constraint pass would be
   falsifying the record to fit the schema.
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

/* --- preflight: global uniqueness --------------------------------------- */

IF EXISTS (SELECT 1 FROM dbo.DOC_SHIPMENT_HDR GROUP BY SHIPMENTKEY HAVING COUNT(*) > 1)
BEGIN
    SELECT SHIPMENTKEY, [Rows] = COUNT(*), Warehouses = STRING_AGG(WHSEID, ',')
    FROM dbo.DOC_SHIPMENT_HDR GROUP BY SHIPMENTKEY HAVING COUNT(*) > 1;

    THROW 50001, 'STOP: the same SHIPMENTKEY exists in more than one warehouse. Global uniqueness cannot be applied, and the public API identifier would be ambiguous. Resolve by hand.', 1;
END

IF EXISTS (SELECT 1 FROM dbo.DOC_TRANSPORT_PLAN GROUP BY PLANKEY HAVING COUNT(*) > 1)
BEGIN
    SELECT PLANKEY, [Rows] = COUNT(*), Warehouses = STRING_AGG(WHSEID, ',')
    FROM dbo.DOC_TRANSPORT_PLAN GROUP BY PLANKEY HAVING COUNT(*) > 1;

    THROW 50001, 'STOP: the same PLANKEY exists in more than one warehouse. Resolve by hand.', 1;
END
GO

/* --- preflight: status values ------------------------------------------- */

IF EXISTS (SELECT 1 FROM dbo.DOC_SHIPMENT_HDR
           WHERE STATUS NOT IN ('DRAFT','CONFIRMED','SENT','ERROR','COMPLETED','CANCELLED','DELETED'))
BEGIN
    SELECT STATUS, [Rows] = COUNT(*), Examples = STRING_AGG(SHIPMENTKEY, ',')
    FROM dbo.DOC_SHIPMENT_HDR
    WHERE STATUS NOT IN ('DRAFT','CONFIRMED','SENT','ERROR','COMPLETED','CANCELLED','DELETED')
    GROUP BY STATUS;

    THROW 50001, 'STOP: DOC_SHIPMENT_HDR holds a status outside the target set. It will not be rewritten to fit the constraint — decide what the value means first.', 1;
END
GO

/* --- apply: global unique constraints ----------------------------------- */

IF EXISTS (SELECT 1 FROM sys.indexes
           WHERE name = 'UQ_DOC_SHIPMENT_HDR_KEY' AND object_id = OBJECT_ID('dbo.DOC_SHIPMENT_HDR'))
BEGIN
    DECLARE @shipCols nvarchar(200) = (
        SELECT STRING_AGG(c.name, ',') WITHIN GROUP (ORDER BY ic.key_ordinal)
        FROM sys.index_columns ic
        JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
        WHERE ic.object_id = OBJECT_ID('dbo.DOC_SHIPMENT_HDR')
          AND ic.index_id = (SELECT index_id FROM sys.indexes
                             WHERE name = 'UQ_DOC_SHIPMENT_HDR_KEY' AND object_id = OBJECT_ID('dbo.DOC_SHIPMENT_HDR'))
          AND ic.is_included_column = 0);

    IF @shipCols <> 'SHIPMENTKEY'
        THROW 50002, 'STOP: UQ_DOC_SHIPMENT_HDR_KEY exists on different columns. Inspect before continuing.', 1;

    PRINT '007: UQ_DOC_SHIPMENT_HDR_KEY already present and correct.';
END
ELSE
BEGIN
    CREATE UNIQUE INDEX UQ_DOC_SHIPMENT_HDR_KEY ON dbo.DOC_SHIPMENT_HDR (SHIPMENTKEY);
    PRINT '007: created UQ_DOC_SHIPMENT_HDR_KEY.';
END
GO

IF EXISTS (SELECT 1 FROM sys.indexes
           WHERE name = 'UQ_DOC_TRANSPORT_PLAN_KEY' AND object_id = OBJECT_ID('dbo.DOC_TRANSPORT_PLAN'))
BEGIN
    DECLARE @planCols nvarchar(200) = (
        SELECT STRING_AGG(c.name, ',') WITHIN GROUP (ORDER BY ic.key_ordinal)
        FROM sys.index_columns ic
        JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
        WHERE ic.object_id = OBJECT_ID('dbo.DOC_TRANSPORT_PLAN')
          AND ic.index_id = (SELECT index_id FROM sys.indexes
                             WHERE name = 'UQ_DOC_TRANSPORT_PLAN_KEY' AND object_id = OBJECT_ID('dbo.DOC_TRANSPORT_PLAN'))
          AND ic.is_included_column = 0);

    IF @planCols <> 'PLANKEY'
        THROW 50002, 'STOP: UQ_DOC_TRANSPORT_PLAN_KEY exists on different columns. Inspect before continuing.', 1;

    PRINT '007: UQ_DOC_TRANSPORT_PLAN_KEY already present and correct.';
END
ELSE
BEGIN
    CREATE UNIQUE INDEX UQ_DOC_TRANSPORT_PLAN_KEY ON dbo.DOC_TRANSPORT_PLAN (PLANKEY);
    PRINT '007: created UQ_DOC_TRANSPORT_PLAN_KEY.';
END
GO

/* --- apply: shipment status domain -------------------------------------- */

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_SHIPMENT_HDR_STATUS')
    ALTER TABLE dbo.DOC_SHIPMENT_HDR WITH CHECK
        ADD CONSTRAINT CK_SHIPMENT_HDR_STATUS CHECK
        (STATUS IN ('DRAFT','CONFIRMED','SENT','ERROR','COMPLETED','CANCELLED','DELETED'));
GO

/* --- verify ------------------------------------------------------------- */

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_DOC_SHIPMENT_HDR_KEY')
    THROW 50003, '007 verification failed: UQ_DOC_SHIPMENT_HDR_KEY missing.', 1;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_DOC_TRANSPORT_PLAN_KEY')
    THROW 50003, '007 verification failed: UQ_DOC_TRANSPORT_PLAN_KEY missing.', 1;

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_SHIPMENT_HDR_STATUS')
    THROW 50003, '007 verification failed: CK_SHIPMENT_HDR_STATUS missing.', 1;

IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = 'CK_SHIPMENT_HDR_STATUS' AND is_not_trusted = 1)
    THROW 50003, '007 verification failed: CK_SHIPMENT_HDR_STATUS was not validated against existing rows.', 1;

/* Nothing was rewritten to make the constraint pass. */
IF (SELECT COUNT(*) FROM dbo.DOC_SHIPMENT_HDR) <> 5
    PRINT '007 note: shipment count differs from the 5 rows seen at preflight — expected if documents were created since.';

PRINT '007: verified.';
GO

COMMIT TRANSACTION;
GO
