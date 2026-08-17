/* =========================================================================
   006 — TMS_DOCUMENT_NUMBER
   =========================================================================
   Where MN-YYYYMM-NNNN and PL-YYYYMM-NNNN come from.

   Keyed by (PREFIX, PERIOD) — deliberately not by warehouse. The numbers in
   this database run continuously across warehouses:

       MN-202608-0039  WWP
       MN-202608-0040  WPD
       MN-202608-0041  WSK
       MN-202608-0042  WPD
       MN-202608-0043  WSK

   and the public API identifies a manifest by that number alone. A
   per-warehouse counter would hand WSK and WPD the same MN-202608-0044 and
   make the identifier ambiguous, so warehouse is context for the allocation,
   not part of its uniqueness.

   Seeded from the numbers already issued, so the next allocation continues the
   sequence instead of colliding with a document that exists. That seed is read
   from the tables themselves, once, here — not computed at runtime. MAX+1 as
   an allocation strategy is exactly what this table replaces: two requests
   reading the same maximum both get the same number.

   Allocation is a single UPDATE with OUTPUT, run inside the caller's
   transaction. The row lock that UPDATE takes is what serialises two
   concurrent callers; whoever waits gets the next number, and a rollback puts
   the number back rather than burning it.
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

IF OBJECT_ID('dbo.TMS_DOCUMENT_NUMBER', 'U') IS NOT NULL
BEGIN
    DECLARE @missing nvarchar(400) = (
        SELECT STRING_AGG(needed.col, ', ')
        FROM (VALUES ('PREFIX'),('PERIOD'),('LASTNUMBER')) AS needed(col)
        WHERE NOT EXISTS (SELECT 1 FROM sys.columns c
                          WHERE c.object_id = OBJECT_ID('dbo.TMS_DOCUMENT_NUMBER')
                            AND c.name = needed.col)
    );
    IF @missing IS NOT NULL
        THROW 50002, 'STOP: TMS_DOCUMENT_NUMBER exists but is missing expected columns. Inspect before continuing.', 1;

    PRINT '006: TMS_DOCUMENT_NUMBER already present and compatible.';
END
ELSE
BEGIN
    CREATE TABLE dbo.TMS_DOCUMENT_NUMBER
    (
        PREFIX      nvarchar(4)  NOT NULL,   /* MN | PL */
        PERIOD      nvarchar(6)  NOT NULL,   /* YYYYMM  */

        /* The last number handed out. The next allocation is this plus one. */
        LASTNUMBER  int          NOT NULL CONSTRAINT DF_TMS_DOCUMENT_NUMBER_LAST DEFAULT (0),

        EDITDATE    datetime     NULL,
        EDITWHO     nvarchar(100) NULL,

        ROWVER      rowversion   NOT NULL,

        CONSTRAINT PK_TMS_DOCUMENT_NUMBER PRIMARY KEY CLUSTERED (PREFIX, PERIOD),
        CONSTRAINT CK_TMS_DOCUMENT_NUMBER_PREFIX CHECK (PREFIX IN ('MN','PL')),
        CONSTRAINT CK_TMS_DOCUMENT_NUMBER_PERIOD CHECK (PERIOD LIKE '[0-9][0-9][0-9][0-9][0-9][0-9]'),
        CONSTRAINT CK_TMS_DOCUMENT_NUMBER_LAST CHECK (LASTNUMBER >= 0)
    );

    PRINT '006: created dbo.TMS_DOCUMENT_NUMBER.';
END
GO

/* --- seed from documents already issued ---------------------------------
   Only for periods that have documents, and only where no counter row exists
   yet. Re-running finds the rows present and does nothing. */

INSERT INTO dbo.TMS_DOCUMENT_NUMBER (PREFIX, PERIOD, LASTNUMBER, EDITDATE, EDITWHO)
SELECT 'MN', SUBSTRING(SHIPMENTKEY, 4, 6), MAX(CAST(RIGHT(SHIPMENTKEY, 4) AS int)), GETDATE(), 'migration-006'
FROM dbo.DOC_SHIPMENT_HDR
WHERE SHIPMENTKEY LIKE 'MN-[0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]'
GROUP BY SUBSTRING(SHIPMENTKEY, 4, 6)
HAVING NOT EXISTS (SELECT 1 FROM dbo.TMS_DOCUMENT_NUMBER n
                   WHERE n.PREFIX = 'MN' AND n.PERIOD = SUBSTRING(SHIPMENTKEY, 4, 6));
GO

INSERT INTO dbo.TMS_DOCUMENT_NUMBER (PREFIX, PERIOD, LASTNUMBER, EDITDATE, EDITWHO)
SELECT 'PL', SUBSTRING(PLANKEY, 4, 6), MAX(CAST(RIGHT(PLANKEY, 4) AS int)), GETDATE(), 'migration-006'
FROM dbo.DOC_TRANSPORT_PLAN
WHERE PLANKEY LIKE 'PL-[0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]'
GROUP BY SUBSTRING(PLANKEY, 4, 6)
HAVING NOT EXISTS (SELECT 1 FROM dbo.TMS_DOCUMENT_NUMBER n
                   WHERE n.PREFIX = 'PL' AND n.PERIOD = SUBSTRING(PLANKEY, 4, 6));
GO

/* --- verify -------------------------------------------------------------
   The seed has to be at least the highest number already used, or the next
   allocation would return a number that is on a document. */

IF EXISTS (
    SELECT 1
    FROM (SELECT SUBSTRING(SHIPMENTKEY,4,6) AS PERIOD, MAX(CAST(RIGHT(SHIPMENTKEY,4) AS int)) AS MaxNo
          FROM dbo.DOC_SHIPMENT_HDR
          WHERE SHIPMENTKEY LIKE 'MN-[0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]'
          GROUP BY SUBSTRING(SHIPMENTKEY,4,6)) used
    LEFT JOIN dbo.TMS_DOCUMENT_NUMBER n ON n.PREFIX = 'MN' AND n.PERIOD = used.PERIOD
    WHERE n.LASTNUMBER IS NULL OR n.LASTNUMBER < used.MaxNo)
    THROW 50003, '006 verification failed: the MN counter is behind a manifest that already exists. The next allocation would collide.', 1;

IF EXISTS (
    SELECT 1
    FROM (SELECT SUBSTRING(PLANKEY,4,6) AS PERIOD, MAX(CAST(RIGHT(PLANKEY,4) AS int)) AS MaxNo
          FROM dbo.DOC_TRANSPORT_PLAN
          WHERE PLANKEY LIKE 'PL-[0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]'
          GROUP BY SUBSTRING(PLANKEY,4,6)) used
    LEFT JOIN dbo.TMS_DOCUMENT_NUMBER n ON n.PREFIX = 'PL' AND n.PERIOD = used.PERIOD
    WHERE n.LASTNUMBER IS NULL OR n.LASTNUMBER < used.MaxNo)
    THROW 50003, '006 verification failed: the PL counter is behind a plan that already exists.', 1;

SELECT '006 seeded: ' + PREFIX + '-' + PERIOD + ' last=' + CAST(LASTNUMBER AS varchar(9))
FROM dbo.TMS_DOCUMENT_NUMBER;

PRINT '006: verified.';
GO

COMMIT TRANSACTION;
GO
