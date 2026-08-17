/* =========================================================================
   004 — TMS_SHIPMENT_SEND_ATTEMPT
   =========================================================================
   One row per attempt to hand a shipment to MMX.

   The shipment's own status cannot carry this. Pressing "send" is not the same
   event as MMX accepting the load, and the old code treated them as one: it set
   STATUS = SENT the moment the button was pressed, which meant a hand-off that
   timed out looked identical to one that succeeded.

   So the attempt has its own lifecycle:

       SEND_REQUESTED -> SENDING -> ACKED -> SUCCESS
                            |         |
                            |         +-> (later callback) FAILED
                            +-> TIMEOUT
                            +-> FAILED

   The shipment becomes SENT only once an attempt reaches ACKED. A TIMEOUT does
   not make the shipment ERROR — MMX may well have taken the work and lost the
   reply — so the attempt stays TIMEOUT and the shipment stays where it was,
   waiting for a callback or reconciliation. Guessing failure there is how the
   same load gets sent twice.

   IDEMPOTENCYKEY is unique across the whole table, not per warehouse: it is
   the thing a caller repeats when a request is retried at the network level,
   and it has to identify one attempt anywhere in the system.
   EXTERNALREFERENCE is the opposite — the same value on every attempt of one
   shipment, so MMX can recognise a retry as the same document.
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
    THROW 50000, 'STOP: DOC_SHIPMENT_HDR must exist before the send-attempt table can reference it.', 1;

IF OBJECT_ID('dbo.TMS_SHIPMENT_SEND_ATTEMPT', 'U') IS NOT NULL
BEGIN
    DECLARE @missing nvarchar(600) = (
        SELECT STRING_AGG(needed.col, ', ')
        FROM (VALUES ('WHSEID'),('SHIPMENTKEY'),('ATTEMPTNO'),('IDEMPOTENCYKEY'),
                     ('STATUS'),('EXTERNALREFERENCE'),('ROWVER')) AS needed(col)
        WHERE NOT EXISTS (SELECT 1 FROM sys.columns c
                          WHERE c.object_id = OBJECT_ID('dbo.TMS_SHIPMENT_SEND_ATTEMPT')
                            AND c.name = needed.col)
    );
    IF @missing IS NOT NULL
        THROW 50002, 'STOP: TMS_SHIPMENT_SEND_ATTEMPT exists but is missing expected columns. Inspect before continuing.', 1;

    PRINT '004: TMS_SHIPMENT_SEND_ATTEMPT already present and compatible.';
END
ELSE
BEGIN
    CREATE TABLE dbo.TMS_SHIPMENT_SEND_ATTEMPT
    (
        SERIALKEY         int IDENTITY(1,1) NOT NULL,

        /* Warehouse travels with the row so an attempt can be read without
           joining back to the shipment, and so the FK matches the composite
           key the shipment table actually has. */
        WHSEID            nvarchar(30)  NOT NULL,
        SHIPMENTKEY       nvarchar(30)  NOT NULL,

        /* 1 for the first send, then 2, 3 … Unique per shipment. */
        ATTEMPTNO         int           NOT NULL,

        /* New for every attempt. Globally unique — see the header. */
        IDEMPOTENCYKEY    nvarchar(64)  NOT NULL,

        /* The same on every attempt of one shipment: the manifest number. */
        EXTERNALREFERENCE nvarchar(50)  NOT NULL,

        /* Correlates this attempt with the HTTP request that caused it. */
        REQUESTID         nvarchar(64)  NULL,

        STATUS            nvarchar(20)  NOT NULL,

        REQUESTEDAT       datetime2(3)  NOT NULL CONSTRAINT DF_TMS_SEND_ATTEMPT_REQAT DEFAULT (SYSUTCDATETIME()),
        REQUESTEDBY       nvarchar(100) NULL,
        STARTEDAT         datetime2(3)  NULL,
        ACKEDAT           datetime2(3)  NULL,
        COMPLETEDAT       datetime2(3)  NULL,
        FAILEDAT          datetime2(3)  NULL,

        LASTERRORCODE     nvarchar(50)  NULL,
        LASTERROR         nvarchar(1000) NULL,

        /* Whatever MMX sent back, kept whole. Diagnosing an integration from
           a summarised error is guesswork. */
        RESPONSEPAYLOAD   nvarchar(max) NULL,

        ADDDATE           datetime      NOT NULL CONSTRAINT DF_TMS_SEND_ATTEMPT_ADD DEFAULT (GETDATE()),
        ADDWHO            nvarchar(100) NULL,
        EDITDATE          datetime      NULL,
        EDITWHO           nvarchar(100) NULL,

        ROWVER            rowversion    NOT NULL,

        CONSTRAINT PK_TMS_SHIPMENT_SEND_ATTEMPT PRIMARY KEY CLUSTERED (SERIALKEY),

        /* Two attempts cannot claim the same number on one shipment — that is
           what makes "attempt 3" a fact rather than a label. */
        CONSTRAINT UQ_TMS_SEND_ATTEMPT_NO UNIQUE (WHSEID, SHIPMENTKEY, ATTEMPTNO),

        CONSTRAINT UQ_TMS_SEND_ATTEMPT_IDEMPOTENCY UNIQUE (IDEMPOTENCYKEY),

        CONSTRAINT FK_TMS_SEND_ATTEMPT_SHIPMENT FOREIGN KEY (WHSEID, SHIPMENTKEY)
            REFERENCES dbo.DOC_SHIPMENT_HDR (WHSEID, SHIPMENTKEY),

        CONSTRAINT CK_TMS_SEND_ATTEMPT_STATUS CHECK
            (STATUS IN ('SEND_REQUESTED','SENDING','ACKED','SUCCESS','FAILED','TIMEOUT')),

        CONSTRAINT CK_TMS_SEND_ATTEMPT_NO CHECK (ATTEMPTNO >= 1)
    );

    /* The question asked constantly: what is the newest attempt on this
       shipment, and is it still outstanding. */
    CREATE INDEX IX_TMS_SEND_ATTEMPT_SHIPMENT
        ON dbo.TMS_SHIPMENT_SEND_ATTEMPT (WHSEID, SHIPMENTKEY, ATTEMPTNO DESC);

    /* The reconciliation sweep: attempts that were requested and never
       settled. Filtered so the index stays the size of the backlog rather
       than the size of the history. */
    CREATE INDEX IX_TMS_SEND_ATTEMPT_OUTSTANDING
        ON dbo.TMS_SHIPMENT_SEND_ATTEMPT (REQUESTEDAT)
        WHERE STATUS IN ('SEND_REQUESTED','SENDING','ACKED','TIMEOUT');

    PRINT '004: created dbo.TMS_SHIPMENT_SEND_ATTEMPT.';
END
GO

/* --- verify ------------------------------------------------------------- */

IF OBJECT_ID('dbo.TMS_SHIPMENT_SEND_ATTEMPT', 'U') IS NULL
    THROW 50003, '004 verification failed: table not created.', 1;

DECLARE @needed TABLE (name sysname);
INSERT INTO @needed VALUES
    ('PK_TMS_SHIPMENT_SEND_ATTEMPT'), ('UQ_TMS_SEND_ATTEMPT_NO'),
    ('UQ_TMS_SEND_ATTEMPT_IDEMPOTENCY'), ('FK_TMS_SEND_ATTEMPT_SHIPMENT'),
    ('CK_TMS_SEND_ATTEMPT_STATUS');

IF EXISTS (SELECT 1 FROM @needed n
           WHERE NOT EXISTS (SELECT 1 FROM sys.objects o WHERE o.name = n.name)
             AND NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.name = n.name))
    THROW 50003, '004 verification failed: an expected constraint is missing.', 1;

PRINT '004: verified.';
GO

COMMIT TRANSACTION;
GO
