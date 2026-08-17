/* =========================================================================
   005 — TMS_DOCUMENT_AUDIT
   =========================================================================
   The audit trail for things DOC_SHIPMENT_STATUS_LOG cannot hold.

   That table stays exactly as it is: it already records shipment status
   changes, it already has fourteen rows of real history, and duplicating those
   events here would leave two accounts of the same thing to drift apart. It has
   no room for a plan, though, and no room for why — no reason, no request id,
   no metadata.

   So the split is by what each can answer:

     DOC_SHIPMENT_STATUS_LOG   what a shipment's status did
     TMS_DOCUMENT_AUDIT        what a person did, to which document, and why

   DOCUMENTKEY holds the business key — MN-202608-0043, PL-202608-0001 — not
   SERIALKEY. It is what appears on the screen and in the message, and it does
   not change when a row is rebuilt.

   No foreign key to either document table. An audit row has to outlive what it
   describes: a deleted draft still needs to say who deleted it, and a
   constraint pointing at the row that is gone would prevent exactly that.
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

IF OBJECT_ID('dbo.TMS_DOCUMENT_AUDIT', 'U') IS NOT NULL
BEGIN
    DECLARE @missing nvarchar(600) = (
        SELECT STRING_AGG(needed.col, ', ')
        FROM (VALUES ('WHSEID'),('DOCUMENTTYPE'),('DOCUMENTKEY'),('ACTION'),
                     ('FROMSTATUS'),('TOSTATUS'),('ACTOR'),('CHANGEDAT')) AS needed(col)
        WHERE NOT EXISTS (SELECT 1 FROM sys.columns c
                          WHERE c.object_id = OBJECT_ID('dbo.TMS_DOCUMENT_AUDIT')
                            AND c.name = needed.col)
    );
    IF @missing IS NOT NULL
        THROW 50002, 'STOP: TMS_DOCUMENT_AUDIT exists but is missing expected columns. Inspect before continuing.', 1;

    PRINT '005: TMS_DOCUMENT_AUDIT already present and compatible.';
END
ELSE
BEGIN
    CREATE TABLE dbo.TMS_DOCUMENT_AUDIT
    (
        AUDITID       bigint IDENTITY(1,1) NOT NULL,

        WHSEID        nvarchar(30)  NOT NULL,

        /* PLAN | SHIPMENT | SEND_ATTEMPT — bounded, because an audit trail
           that can be filtered by document type is worth far more than one
           where the type is free text nobody spells the same way twice. */
        DOCUMENTTYPE  nvarchar(20)  NOT NULL,

        /* The business key: PLANKEY or SHIPMENTKEY. */
        DOCUMENTKEY   nvarchar(50)  NOT NULL,

        ACTION        nvarchar(30)  NOT NULL,

        FROMSTATUS    nvarchar(20)  NULL,
        TOSTATUS      nvarchar(20)  NULL,

        /* Why, in the actor's words. The column that makes a cancellation
           readable a month later. */
        REASON        nvarchar(500) NULL,

        /* Ties every row written by one HTTP request together. */
        REQUESTID     nvarchar(64)  NULL,

        /* The MMX side of an integration event, when there is one. */
        EXTERNALREFERENCE nvarchar(50) NULL,

        ACTOR         nvarchar(100) NOT NULL,
        CHANGEDAT     datetime2(3)  NOT NULL CONSTRAINT DF_TMS_DOCUMENT_AUDIT_AT DEFAULT (SYSUTCDATETIME()),

        /* JSON, for whatever a particular action needs that does not deserve
           a column: how many stops moved, which orders came back. */
        METADATA      nvarchar(max) NULL,

        CONSTRAINT PK_TMS_DOCUMENT_AUDIT PRIMARY KEY CLUSTERED (AUDITID),

        CONSTRAINT CK_TMS_DOCUMENT_AUDIT_TYPE CHECK
            (DOCUMENTTYPE IN ('PLAN','SHIPMENT','SEND_ATTEMPT'))
    );

    /* The timeline of one document, newest first — the query the history
       panel makes every time it opens. */
    CREATE INDEX IX_TMS_DOCUMENT_AUDIT_DOC
        ON dbo.TMS_DOCUMENT_AUDIT (WHSEID, DOCUMENTTYPE, DOCUMENTKEY, CHANGEDAT DESC);

    /* Everything one request did, for tracing a failure across documents. */
    CREATE INDEX IX_TMS_DOCUMENT_AUDIT_REQUEST
        ON dbo.TMS_DOCUMENT_AUDIT (REQUESTID)
        WHERE REQUESTID IS NOT NULL;

    PRINT '005: created dbo.TMS_DOCUMENT_AUDIT.';
END
GO

/* --- verify ------------------------------------------------------------- */

IF OBJECT_ID('dbo.TMS_DOCUMENT_AUDIT', 'U') IS NULL
    THROW 50003, '005 verification failed: table not created.', 1;

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_TMS_DOCUMENT_AUDIT_TYPE')
    THROW 50003, '005 verification failed: CK_TMS_DOCUMENT_AUDIT_TYPE missing.', 1;

/* The existing shipment history must be untouched — this migration adds a
   table beside it, it does not migrate it. */
IF (SELECT COUNT(*) FROM dbo.DOC_SHIPMENT_STATUS_LOG) = 0
    THROW 50003, '005 verification failed: DOC_SHIPMENT_STATUS_LOG is empty. It held rows before this migration and must still.', 1;

PRINT '005: verified — legacy status log left intact.';
GO

COMMIT TRANSACTION;
GO
