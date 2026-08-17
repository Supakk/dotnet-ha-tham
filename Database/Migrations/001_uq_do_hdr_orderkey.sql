/* =========================================================================
   001 — delivery-order business key, and the two foreign keys it unlocks
   =========================================================================
   DOC_DO_HDR is keyed by SERIALKEY, an identity surrogate nothing references.
   The key the rest of the schema actually points at is (WHSEID, ORDERKEY) —
   and until now nothing guaranteed it was unique, so no foreign key could be
   declared against it.

   That left the one integrity gap in the document model: DOC_SHIPMENT_DETAIL
   and DOC_TRANSPORT_PLAN_LINE both carry ORDERKEY, both are the tables that
   decide whether an order is free, and neither was tied to the orders table.
   An ORDERKEY could be assigned that did not exist.

   Closing it also makes the pending-pool query safe: joining on a key that is
   not unique multiplies rows, and the pool has to be one row per order.

   Refuses rather than repairs. A duplicate or an orphan here is a data
   question — which of the two rows is real, where did the order go — and a
   migration is not entitled to answer it.
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

/* --- preflight: duplicates --------------------------------------------- */

DECLARE @dups int = (
    SELECT COUNT(*) FROM (
        SELECT WHSEID, ORDERKEY
        FROM dbo.DOC_DO_HDR
        GROUP BY WHSEID, ORDERKEY
        HAVING COUNT(*) > 1
    ) d
);

IF @dups > 0
BEGIN
    /* Name them, so the report says which rows to look at. */
    SELECT WHSEID, ORDERKEY, [Rows] = COUNT(*), SerialKeys = STRING_AGG(CAST(SERIALKEY AS varchar(12)), ',')
    FROM dbo.DOC_DO_HDR
    GROUP BY WHSEID, ORDERKEY
    HAVING COUNT(*) > 1;

    THROW 50001, 'STOP: DOC_DO_HDR has duplicate (WHSEID, ORDERKEY). The unique constraint would fail. Resolve the duplicates by hand — this migration will not delete or merge rows.', 1;
END
GO

/* --- preflight: orphans ------------------------------------------------- */

DECLARE @orphanDetail int = (
    SELECT COUNT(*) FROM dbo.DOC_SHIPMENT_DETAIL d
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DOC_DO_HDR o
                      WHERE o.WHSEID = d.WHSEID AND o.ORDERKEY = d.ORDERKEY)
);

IF @orphanDetail > 0
BEGIN
    SELECT TOP (50) d.WHSEID, d.SHIPMENTKEY, d.ORDERKEY
    FROM dbo.DOC_SHIPMENT_DETAIL d
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DOC_DO_HDR o
                      WHERE o.WHSEID = d.WHSEID AND o.ORDERKEY = d.ORDERKEY);

    THROW 50001, 'STOP: DOC_SHIPMENT_DETAIL references orders that do not exist. The foreign key would fail. Investigate before continuing — this migration will not delete rows.', 1;
END

DECLARE @orphanLine int = (
    SELECT COUNT(*) FROM dbo.DOC_TRANSPORT_PLAN_LINE l
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DOC_DO_HDR o
                      WHERE o.WHSEID = l.WHSEID AND o.ORDERKEY = l.ORDERKEY)
);

IF @orphanLine > 0
BEGIN
    SELECT TOP (50) l.WHSEID, l.PLANKEY, l.ORDERKEY
    FROM dbo.DOC_TRANSPORT_PLAN_LINE l
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DOC_DO_HDR o
                      WHERE o.WHSEID = l.WHSEID AND o.ORDERKEY = l.ORDERKEY);

    THROW 50001, 'STOP: DOC_TRANSPORT_PLAN_LINE references orders that do not exist. Investigate before continuing.', 1;
END
GO

/* --- preflight: is the name already taken by something else? ------------ */

IF EXISTS (SELECT 1 FROM sys.indexes
           WHERE name = 'UQ_DOC_DO_HDR_ORDER' AND object_id = OBJECT_ID('dbo.DOC_DO_HDR'))
BEGIN
    /* Present already. Only acceptable if it is unique and on exactly the two
       columns we mean — anything else is a different index with our name. */
    DECLARE @cols nvarchar(200) = (
        SELECT STRING_AGG(c.name, ',') WITHIN GROUP (ORDER BY ic.key_ordinal)
        FROM sys.index_columns ic
        JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
        WHERE ic.object_id = OBJECT_ID('dbo.DOC_DO_HDR')
          AND ic.index_id = (SELECT index_id FROM sys.indexes
                             WHERE name = 'UQ_DOC_DO_HDR_ORDER' AND object_id = OBJECT_ID('dbo.DOC_DO_HDR'))
          AND ic.is_included_column = 0
    );
    DECLARE @isUnique bit = (SELECT is_unique FROM sys.indexes
                             WHERE name = 'UQ_DOC_DO_HDR_ORDER' AND object_id = OBJECT_ID('dbo.DOC_DO_HDR'));

    IF @isUnique = 0 OR @cols <> 'WHSEID,ORDERKEY'
        THROW 50002, 'STOP: an index named UQ_DOC_DO_HDR_ORDER exists with a different definition. Inspect it — this migration will not drop and recreate an object it did not create.', 1;

    PRINT '001: UQ_DOC_DO_HDR_ORDER already present and correct.';
END
ELSE
BEGIN
    CREATE UNIQUE INDEX UQ_DOC_DO_HDR_ORDER
        ON dbo.DOC_DO_HDR (WHSEID, ORDERKEY);
    PRINT '001: created UQ_DOC_DO_HDR_ORDER.';
END
GO

/* --- apply: the two foreign keys ---------------------------------------- */

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_DOC_SHIPMENT_DETAIL_DO')
BEGIN
    ALTER TABLE dbo.DOC_SHIPMENT_DETAIL WITH CHECK
        ADD CONSTRAINT FK_DOC_SHIPMENT_DETAIL_DO
        FOREIGN KEY (WHSEID, ORDERKEY)
        REFERENCES dbo.DOC_DO_HDR (WHSEID, ORDERKEY);
    PRINT '001: created FK_DOC_SHIPMENT_DETAIL_DO.';
END
ELSE
    PRINT '001: FK_DOC_SHIPMENT_DETAIL_DO already present.';
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_DOC_TRANSPORT_PLAN_LINE_DO')
BEGIN
    ALTER TABLE dbo.DOC_TRANSPORT_PLAN_LINE WITH CHECK
        ADD CONSTRAINT FK_DOC_TRANSPORT_PLAN_LINE_DO
        FOREIGN KEY (WHSEID, ORDERKEY)
        REFERENCES dbo.DOC_DO_HDR (WHSEID, ORDERKEY);
    PRINT '001: created FK_DOC_TRANSPORT_PLAN_LINE_DO.';
END
ELSE
    PRINT '001: FK_DOC_TRANSPORT_PLAN_LINE_DO already present.';
GO

/* --- verify ------------------------------------------------------------- */

IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = 'UQ_DOC_DO_HDR_ORDER' AND object_id = OBJECT_ID('dbo.DOC_DO_HDR'))
    THROW 50003, '001 verification failed: UQ_DOC_DO_HDR_ORDER missing.', 1;

/* WITH CHECK above means SQL Server validated every existing row. is_not_trusted
   would mean it skipped that, which defeats the point of adding the key. */
IF EXISTS (SELECT 1 FROM sys.foreign_keys
           WHERE name IN ('FK_DOC_SHIPMENT_DETAIL_DO', 'FK_DOC_TRANSPORT_PLAN_LINE_DO')
             AND is_not_trusted = 1)
    THROW 50003, '001 verification failed: a foreign key was created untrusted — existing rows were not validated.', 1;

IF (SELECT COUNT(*) FROM sys.foreign_keys
    WHERE name IN ('FK_DOC_SHIPMENT_DETAIL_DO', 'FK_DOC_TRANSPORT_PLAN_LINE_DO')) <> 2
    THROW 50003, '001 verification failed: expected both foreign keys to exist.', 1;

PRINT '001: verified.';
GO

COMMIT TRANSACTION;
GO
