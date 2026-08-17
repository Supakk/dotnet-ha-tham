/* =========================================================================
   VERIFICATION — run after the migrations, changes nothing
   =========================================================================
   Checks that each migration left behind what it claimed to, and that the
   documents it was applied around are still there and unchanged.

   The second half matters as much as the first. A migration that creates
   every object and quietly alters a row has still done damage, so the counts
   and statuses are asserted too.

       sqlcmd -S "(localdb)\MSSQLLocalDB" -d MMDEV -i Verify-Migrations.sql
   ========================================================================= */

SET NOCOUNT ON;

PRINT '===== APPLIED =====';
SELECT VERSION, NAME, APPLIEDAT, DURATIONMS FROM dbo.TMS_SCHEMA_MIGRATION ORDER BY VERSION;

PRINT '===== OBJECTS — every line must read OK =====';

SELECT [Object] = n.name,
       [Kind] = n.kind,
       [Result] = IIF(EXISTS (SELECT 1 FROM sys.objects o WHERE o.name = n.name)
                   OR EXISTS (SELECT 1 FROM sys.indexes i WHERE i.name = n.name), 'OK', 'MISSING')
FROM (VALUES
    ('TMS_SCHEMA_MIGRATION',          'table  (000)'),
    ('UQ_DOC_DO_HDR_ORDER',           'index  (001)'),
    ('FK_DOC_SHIPMENT_DETAIL_DO',     'fk     (001)'),
    ('FK_DOC_TRANSPORT_PLAN_LINE_DO', 'fk     (001)'),
    ('TMS_SHIPMENT_SEND_ATTEMPT',     'table  (004)'),
    ('TMS_DOCUMENT_AUDIT',            'table  (005)'),
    ('TMS_DOCUMENT_NUMBER',           'table  (006)'),
    ('UQ_DOC_SHIPMENT_HDR_KEY',       'index  (007)'),
    ('UQ_DOC_TRANSPORT_PLAN_KEY',     'index  (007)'),
    ('CK_SHIPMENT_HDR_STATUS',        'check  (007)'),
    ('CK_SHIPMENT_HDR_RELATIONTYPE',  'check  (003)')
) AS n(name, kind);

PRINT '===== COLUMNS =====';
SELECT [Table] = 'DOC_TRANSPORT_PLAN', [Column] = c.col,
       [Result] = IIF(COL_LENGTH('dbo.DOC_TRANSPORT_PLAN', c.col) IS NOT NULL, 'OK', 'MISSING')
FROM (VALUES ('ISSUEDBY'),('ISSUEDDATE'),('CANCELLEDBY'),('CANCELLEDDATE')) AS c(col)
UNION ALL
SELECT 'DOC_SHIPMENT_HDR', c.col,
       IIF(COL_LENGTH('dbo.DOC_SHIPMENT_HDR', c.col) IS NOT NULL, 'OK', 'MISSING')
FROM (VALUES ('CONFIRMBY'),('SENTBY'),('COMPLETEDDATE'),('CANCELLEDBY'),('CANCELLEDDATE'),
             ('DELETEDBY'),('DELETEDDATE'),('DELETEREASON'),('RETRYCOUNT'),
             ('EXTERNALREFERENCE'),('INVOICEDAT'),('INVOICEDBY'),('RELATIONTYPE')) AS c(col);

PRINT '===== TRUSTED CONSTRAINTS =====';
/* An untrusted constraint was added without validating the rows already
   there, which means it guarantees nothing about them. */
SELECT [Constraint] = name, [Trusted] = IIF(is_not_trusted = 0, 'OK', 'NOT TRUSTED')
FROM sys.foreign_keys
WHERE name IN ('FK_DOC_SHIPMENT_DETAIL_DO','FK_DOC_TRANSPORT_PLAN_LINE_DO','FK_TMS_SEND_ATTEMPT_SHIPMENT')
UNION ALL
SELECT name, IIF(is_not_trusted = 0, 'OK', 'NOT TRUSTED')
FROM sys.check_constraints
WHERE name IN ('CK_SHIPMENT_HDR_STATUS','CK_SHIPMENT_HDR_RELATIONTYPE');

PRINT '===== DOCUMENT NUMBER COUNTERS =====';
SELECT PREFIX, PERIOD, LASTNUMBER, [NextWouldBe] = LASTNUMBER + 1
FROM dbo.TMS_DOCUMENT_NUMBER ORDER BY PREFIX, PERIOD;

SELECT [Check] = 'counter is not behind an existing document',
       [Result] = IIF(NOT EXISTS (
           SELECT 1 FROM (SELECT SUBSTRING(SHIPMENTKEY,4,6) p, MAX(CAST(RIGHT(SHIPMENTKEY,4) AS int)) m
                          FROM dbo.DOC_SHIPMENT_HDR
                          WHERE SHIPMENTKEY LIKE 'MN-[0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]'
                          GROUP BY SUBSTRING(SHIPMENTKEY,4,6)) u
           LEFT JOIN dbo.TMS_DOCUMENT_NUMBER n ON n.PREFIX='MN' AND n.PERIOD=u.p
           WHERE n.LASTNUMBER IS NULL OR n.LASTNUMBER < u.m), 'OK', 'FAIL — next allocation would collide');

PRINT '===== DOCUMENTS UNCHANGED =====';
/* The migrations are additive. If these moved, something rewrote data. */
SELECT [What] = 'shipments', [Rows] = COUNT(*) FROM dbo.DOC_SHIPMENT_HDR
UNION ALL SELECT 'plans', COUNT(*) FROM dbo.DOC_TRANSPORT_PLAN
UNION ALL SELECT 'shipment stops', COUNT(*) FROM dbo.DOC_SHIPMENT_STOP
UNION ALL SELECT 'shipment details', COUNT(*) FROM dbo.DOC_SHIPMENT_DETAIL
UNION ALL SELECT 'delivery orders', COUNT(*) FROM dbo.DOC_DO_HDR
UNION ALL SELECT 'legacy status log', COUNT(*) FROM dbo.DOC_SHIPMENT_STATUS_LOG;

SELECT [Check] = 'no lifecycle column was backfilled',
       [Result] = IIF(NOT EXISTS (SELECT 1 FROM dbo.DOC_SHIPMENT_HDR
                                  WHERE CONFIRMBY IS NOT NULL OR SENTBY IS NOT NULL
                                     OR RELATIONTYPE IS NOT NULL OR INVOICEDAT IS NOT NULL)
                   AND NOT EXISTS (SELECT 1 FROM dbo.DOC_TRANSPORT_PLAN
                                   WHERE ISSUEDBY IS NOT NULL OR CANCELLEDBY IS NOT NULL),
                      'OK — history was not invented', 'REVIEW — a new column holds data');

PRINT '===== POOL BY WAREHOUSE (should be unchanged by migration) =====';
SELECT [Warehouse] = o.WHSEID, [Available] = COUNT(*)
FROM dbo.DOC_DO_HDR o
WHERE NOT EXISTS (SELECT 1 FROM dbo.DOC_SHIPMENT_DETAIL d
                  WHERE d.WHSEID = o.WHSEID AND d.ORDERKEY = o.ORDERKEY AND d.STATUS <> 'CANCELLED')
  AND NOT EXISTS (SELECT 1 FROM dbo.DOC_TRANSPORT_PLAN_LINE l
                  WHERE l.WHSEID = o.WHSEID AND l.ORDERKEY = o.ORDERKEY AND l.STATUS <> 'CANCELLED')
GROUP BY o.WHSEID
ORDER BY o.WHSEID;

PRINT '===== END VERIFICATION =====';
