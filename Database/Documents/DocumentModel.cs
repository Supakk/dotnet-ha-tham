using Microsoft.EntityFrameworkCore;

namespace Mammod.Database.Documents;

/// <summary>
/// Fluent configuration for the document tables.
///
/// Kept out of <see cref="AppDbContext"/> so the master-data mapping stays
/// readable; <c>OnModelCreating</c> calls <see cref="Configure"/> once.
///
/// Two things here are load-bearing and easy to get wrong:
///
/// <b>Composite keys.</b> Every document is identified by <c>(WHSEID, KEY)</c>.
/// Configuring a single-column key would compile, work against one warehouse and
/// then silently mix two — so the keys are spelled out and the relationships are
/// declared with matching column lists.
///
/// <b>ROWVER.</b> Marked <c>IsRowVersion</c>, which makes EF add
/// <c>WHERE ROWVER = @original</c> to every UPDATE and DELETE and raise
/// <c>DbUpdateConcurrencyException</c> when no row matches. That exception is the
/// 409 the API returns; nothing else needs to compare versions by hand.
/// </summary>
public static class DocumentModel
{
    /// <summary>Money and weights: enough for a lorry-load, exact to two places.</summary>
    private const string Money = "decimal(18,2)";
    private const string Qty = "decimal(18,3)";
    private const string LatLng = "decimal(11,7)";

    public static void Configure(ModelBuilder b)
    {
        ConfigurePlans(b);
        ConfigureShipments(b);
        ConfigureTmsOwned(b);
    }

    private static void ConfigurePlans(ModelBuilder b)
    {
        b.Entity<TransportPlanRow>(e =>
        {
            e.ToTable("DOC_TRANSPORT_PLAN");
            e.HasKey(x => new { x.WhseId, x.PlanKey });

            e.Property(x => x.WhseId).HasColumnName("WHSEID");
            e.Property(x => x.PlanKey).HasColumnName("PLANKEY");
            e.Property(x => x.PlanDate).HasColumnName("PLANDATE");
            e.Property(x => x.DeliveryDate).HasColumnName("DELIVERYDATE");
            e.Property(x => x.Zone).HasColumnName("ZONE");
            e.Property(x => x.Route).HasColumnName("ROUTE");
            e.Property(x => x.ShipmentKey).HasColumnName("SHIPMENTKEY");
            e.Property(x => x.TotalOrder).HasColumnName("TOTALORDER");
            e.Property(x => x.TotalWeight).HasColumnName("TOTALWEIGHT").HasColumnType(Qty);
            e.Property(x => x.TotalCube).HasColumnName("TOTALCUBE").HasColumnType(Qty);
            e.Property(x => x.Status).HasColumnName("STATUS");
            e.Property(x => x.CancelReason).HasColumnName("CANCELREASON");
            e.Property(x => x.Notes).HasColumnName("NOTES");
            e.Property(x => x.AddDate).HasColumnName("ADDDATE");
            e.Property(x => x.AddWho).HasColumnName("ADDWHO");
            e.Property(x => x.EditDate).HasColumnName("EDITDATE");
            e.Property(x => x.EditWho).HasColumnName("EDITWHO");
            e.Property(x => x.RowVer).HasColumnName("ROWVER").IsRowVersion();

            // SERIALKEY is IDENTITY and unreferenced. Telling EF it exists would
            // only mean explaining every insert; the database fills it in.
            e.Ignore("SerialKey");

            e.HasMany(x => x.Lines)
                .WithOne(l => l.Plan)
                .HasForeignKey(l => new { l.WhseId, l.PlanKey })
                .HasPrincipalKey(x => new { x.WhseId, x.PlanKey })
                .OnDelete(DeleteBehavior.Restrict);
        });

        b.Entity<TransportPlanLineRow>(e =>
        {
            e.ToTable("DOC_TRANSPORT_PLAN_LINE");
            e.HasKey(x => new { x.WhseId, x.PlanKey, x.OrderKey });

            e.Property(x => x.WhseId).HasColumnName("WHSEID");
            e.Property(x => x.PlanKey).HasColumnName("PLANKEY");
            e.Property(x => x.OrderKey).HasColumnName("ORDERKEY");
            e.Property(x => x.Status).HasColumnName("STATUS");
            e.Property(x => x.AddDate).HasColumnName("ADDDATE");
            e.Property(x => x.AddWho).HasColumnName("ADDWHO");
            e.Property(x => x.EditDate).HasColumnName("EDITDATE");
            e.Property(x => x.EditWho).HasColumnName("EDITWHO");

            // The database's guarantee that an order sits on one live plan only.
            // Declared here so the model says the same thing the schema does —
            // EF will not create it (schema is owned by the SQL scripts), but a
            // reader of this file learns the rule without opening the database.
            e.HasIndex(x => x.OrderKey)
                .HasDatabaseName("UX_DOC_TRANSPORT_PLAN_LINE_ORDER")
                .IsUnique()
                .HasFilter("([STATUS]<>'CANCELLED')");
        });
    }

    private static void ConfigureShipments(ModelBuilder b)
    {
        b.Entity<ShipmentRow>(e =>
        {
            e.ToTable("DOC_SHIPMENT_HDR");
            e.HasKey(x => new { x.WhseId, x.ShipmentKey });

            e.Property(x => x.WhseId).HasColumnName("WHSEID");
            e.Property(x => x.ShipmentKey).HasColumnName("SHIPMENTKEY");
            e.Property(x => x.ShipmentDate).HasColumnName("SHIPMENTDATE");
            e.Property(x => x.DeliveryDate).HasColumnName("DELIVERYDATE");
            e.Property(x => x.Route).HasColumnName("ROUTE");
            e.Property(x => x.Zone).HasColumnName("ZONE");
            e.Property(x => x.Door).HasColumnName("DOOR");
            e.Property(x => x.TransporterKey).HasColumnName("TRANSPORTERKEY");
            e.Property(x => x.VehicleKey).HasColumnName("VEHICLEKEY");
            e.Property(x => x.VehicleTypeKey).HasColumnName("VEHICLETYPEKEY");
            e.Property(x => x.DriverKey).HasColumnName("DRIVERKEY");
            e.Property(x => x.LicensePlate).HasColumnName("LICENSEPLATE");
            e.Property(x => x.DriverName).HasColumnName("DRIVERNAME");
            e.Property(x => x.DriverMobile).HasColumnName("DRIVERMOBILE");
            e.Property(x => x.TrailerId).HasColumnName("TRAILERID");
            e.Property(x => x.TotalStop).HasColumnName("TOTALSTOP");
            e.Property(x => x.TotalOrder).HasColumnName("TOTALORDER");
            e.Property(x => x.TotalWeight).HasColumnName("TOTALWEIGHT").HasColumnType(Qty);
            e.Property(x => x.TotalCube).HasColumnName("TOTALCUBE").HasColumnType(Qty);
            e.Property(x => x.MaxWeight).HasColumnName("MAXWEIGHT").HasColumnType(Qty);
            e.Property(x => x.MaxCube).HasColumnName("MAXCUBE").HasColumnType(Qty);
            e.Property(x => x.Status).HasColumnName("STATUS");
            e.Property(x => x.Notes).HasColumnName("NOTES");
            e.Property(x => x.PlanKey).HasColumnName("PLANKEY");
            e.Property(x => x.ParentShipmentKey).HasColumnName("PARENT_SHIPMENTKEY");
            e.Property(x => x.SealNo).HasColumnName("SEALNO");
            e.Property(x => x.AssistantCount).HasColumnName("ASSISTANTCOUNT");
            e.Property(x => x.TripPrice).HasColumnName("TRIPPRICE").HasColumnType(Money);
            e.Property(x => x.PriceAdd).HasColumnName("PRICEADD").HasColumnType(Money);
            e.Property(x => x.PriceDeduct).HasColumnName("PRICEDEDUCT").HasColumnType(Money);
            e.Property(x => x.FreightNote).HasColumnName("FREIGHTNOTE");
            e.Property(x => x.Currency).HasColumnName("CURRENCY");
            e.Property(x => x.ExpressFlag).HasColumnName("EXPRESS_FLAG");
            e.Property(x => x.ExpressRequester).HasColumnName("EXPRESS_REQUESTER");
            e.Property(x => x.ExpressApprover).HasColumnName("EXPRESS_APPROVER");
            e.Property(x => x.ConfirmDate).HasColumnName("CONFIRMDATE");
            e.Property(x => x.SentDate).HasColumnName("SENTDATE");
            e.Property(x => x.StatusMessage).HasColumnName("STATUSMESSAGE");
            e.Property(x => x.CancelReason).HasColumnName("CANCELREASON");
            e.Property(x => x.AddDate).HasColumnName("ADDDATE");
            e.Property(x => x.AddWho).HasColumnName("ADDWHO");
            e.Property(x => x.EditDate).HasColumnName("EDITDATE");
            e.Property(x => x.EditWho).HasColumnName("EDITWHO");
            e.Property(x => x.RowVer).HasColumnName("ROWVER").IsRowVersion();
            e.Ignore("SerialKey");

            e.HasOne(x => x.Plan)
                .WithMany()
                .HasForeignKey(x => new { x.WhseId, x.PlanKey })
                .HasPrincipalKey(p => new { p.WhseId, p.PlanKey })
                .OnDelete(DeleteBehavior.Restrict);

            // Lineage is a plain column, not a mapped relationship: the parent
            // may be deleted or archived independently, and a required
            // navigation would make EF try to keep them together.
        });

        b.Entity<ShipmentStopRow>(e =>
        {
            e.ToTable("DOC_SHIPMENT_STOP");
            e.HasKey(x => new { x.WhseId, x.ShipmentKey, x.ShipmentStopId });

            e.Property(x => x.WhseId).HasColumnName("WHSEID");
            e.Property(x => x.ShipmentKey).HasColumnName("SHIPMENTKEY");
            e.Property(x => x.ShipmentStopId).HasColumnName("SHIPMENTSTOPID");
            e.Property(x => x.StopSeq).HasColumnName("STOPSEQ");
            e.Property(x => x.StopType).HasColumnName("STOPTYPE");
            e.Property(x => x.CustomerKey).HasColumnName("CUSTOMERKEY");
            e.Property(x => x.ShipToKey).HasColumnName("SHIPTOKEY");
            e.Property(x => x.ShipToName).HasColumnName("SHIPTONAME");
            e.Property(x => x.Address1).HasColumnName("ADDRESS1");
            e.Property(x => x.SubDistrict).HasColumnName("SUBDISTRICT");
            e.Property(x => x.District).HasColumnName("DISTRICT");
            e.Property(x => x.Province).HasColumnName("PROVINCE");
            e.Property(x => x.PostalCode).HasColumnName("POSTALCODE");
            e.Property(x => x.Latitude).HasColumnName("LATITUDE").HasColumnType(LatLng);
            e.Property(x => x.Longitude).HasColumnName("LONGITUDE").HasColumnType(LatLng);
            e.Property(x => x.ContactName).HasColumnName("CONTACTNAME");
            e.Property(x => x.ContactPhone).HasColumnName("CONTACTPHONE");
            e.Property(x => x.TotalOrder).HasColumnName("TOTALORDER");
            e.Property(x => x.TotalWeight).HasColumnName("TOTALWEIGHT").HasColumnType(Qty);
            e.Property(x => x.TotalCube).HasColumnName("TOTALCUBE").HasColumnType(Qty);
            e.Property(x => x.CodAmount).HasColumnName("CODAMOUNT").HasColumnType(Money);
            e.Property(x => x.DueDate).HasColumnName("DUEDATE");
            e.Property(x => x.DeliverTo).HasColumnName("DELIVERTO");
            e.Property(x => x.DeliveryStatus).HasColumnName("DELIVERY_STATUS");
            e.Property(x => x.PodStatus).HasColumnName("POD_STATUS");
            e.Property(x => x.Remark).HasColumnName("REMARK");
            e.Property(x => x.Status).HasColumnName("STATUS");
            e.Property(x => x.AddDate).HasColumnName("ADDDATE");
            e.Property(x => x.AddWho).HasColumnName("ADDWHO");
            e.Property(x => x.EditDate).HasColumnName("EDITDATE");
            e.Property(x => x.EditWho).HasColumnName("EDITWHO");
            e.Property(x => x.RowVer).HasColumnName("ROWVER").IsRowVersion();
            e.Ignore("SerialKey");

            e.HasOne(x => x.Shipment)
                .WithMany(s => s.Stops)
                .HasForeignKey(x => new { x.WhseId, x.ShipmentKey })
                .HasPrincipalKey(s => new { s.WhseId, s.ShipmentKey })
                .OnDelete(DeleteBehavior.Restrict);

            e.HasIndex(x => new { x.WhseId, x.ShipmentKey, x.StopSeq })
                .HasDatabaseName("UX_SHIPMENT_STOP_SEQ")
                .IsUnique();
        });

        b.Entity<ShipmentDetailRow>(e =>
        {
            e.ToTable("DOC_SHIPMENT_DETAIL");
            e.HasKey(x => new { x.WhseId, x.ShipmentKey, x.ShipmentDetailId });

            e.Property(x => x.WhseId).HasColumnName("WHSEID");
            e.Property(x => x.ShipmentKey).HasColumnName("SHIPMENTKEY");
            e.Property(x => x.ShipmentDetailId).HasColumnName("SHIPMENTDETAILID");
            e.Property(x => x.ShipmentStopId).HasColumnName("SHIPMENTSTOPID");
            e.Property(x => x.OrderKey).HasColumnName("ORDERKEY");
            e.Property(x => x.ExternOrderKey).HasColumnName("EXTERNORDERKEY");
            e.Property(x => x.CustomerKey).HasColumnName("CUSTOMERKEY");
            e.Property(x => x.Route).HasColumnName("ROUTE");
            e.Property(x => x.Zone).HasColumnName("ZONE");
            e.Property(x => x.OrderDate).HasColumnName("ORDERDATE");
            e.Property(x => x.RequiredDeliveryDate).HasColumnName("REQUIREDDELIVERYDATE");
            e.Property(x => x.OrderStatus).HasColumnName("ORDERSTATUS");
            e.Property(x => x.OutWeight).HasColumnName("OUTWEIGHT").HasColumnType(Qty);
            e.Property(x => x.OutCube).HasColumnName("OUTCUBE").HasColumnType(Qty);
            e.Property(x => x.Status).HasColumnName("STATUS");
            e.Property(x => x.AddDate).HasColumnName("ADDDATE");
            e.Property(x => x.AddWho).HasColumnName("ADDWHO");
            e.Property(x => x.EditDate).HasColumnName("EDITDATE");
            e.Property(x => x.EditWho).HasColumnName("EDITWHO");
            e.Property(x => x.RowVer).HasColumnName("ROWVER").IsRowVersion();
            e.Ignore("SerialKey");

            e.HasOne(x => x.Shipment)
                .WithMany(s => s.Details)
                .HasForeignKey(x => new { x.WhseId, x.ShipmentKey })
                .HasPrincipalKey(s => new { s.WhseId, s.ShipmentKey })
                .OnDelete(DeleteBehavior.Restrict);

            e.HasOne(x => x.Stop)
                .WithMany()
                .HasForeignKey(x => new { x.WhseId, x.ShipmentKey, x.ShipmentStopId })
                .HasPrincipalKey(s => new { s.WhseId, s.ShipmentKey, s.ShipmentStopId })
                .OnDelete(DeleteBehavior.Restrict);

            // The one that matters: an order rides at most one live shipment.
            e.HasIndex(x => x.OrderKey)
                .HasDatabaseName("UX_SHIPMENT_DETAIL_ORDER")
                .IsUnique()
                .HasFilter("([STATUS]<>'CANCELLED')");
        });

        b.Entity<ShipmentDetailLineRow>(e =>
        {
            e.ToTable("DOC_SHIPMENT_DETAIL_LINE");
            e.HasKey(x => new { x.WhseId, x.ShipmentKey, x.ShipmentDetailId, x.ShipmentLineNo });

            e.Property(x => x.WhseId).HasColumnName("WHSEID");
            e.Property(x => x.ShipmentKey).HasColumnName("SHIPMENTKEY");
            e.Property(x => x.ShipmentDetailId).HasColumnName("SHIPMENTDETAILID");
            e.Property(x => x.ShipmentLineNo).HasColumnName("SHIPMENTLINENO");
            e.Property(x => x.OrderKey).HasColumnName("ORDERKEY");
            e.Property(x => x.OrderLineNo).HasColumnName("ORDERLINENO");
            e.Property(x => x.Sku).HasColumnName("SKU");
            e.Property(x => x.Description).HasColumnName("DESCRIPTION");
            e.Property(x => x.OrderQty).HasColumnName("ORDERQTY").HasColumnType(Qty);
            e.Property(x => x.ShipmentQty).HasColumnName("SHIPMENTQTY").HasColumnType(Qty);
            e.Property(x => x.DeliveredQty).HasColumnName("DELIVEREDQTY").HasColumnType(Qty);
            e.Property(x => x.ShortQty).HasColumnName("SHORTQTY").HasColumnType(Qty);
            e.Property(x => x.Uom).HasColumnName("UOM");
            e.Property(x => x.GrossWgt).HasColumnName("GROSSWGT").HasColumnType(Qty);
            e.Property(x => x.Cube).HasColumnName("CUBE").HasColumnType(Qty);
            e.Property(x => x.Status).HasColumnName("STATUS");
            e.Property(x => x.AddDate).HasColumnName("ADDDATE");
            e.Property(x => x.AddWho).HasColumnName("ADDWHO");
            e.Ignore("SerialKey");

            e.HasOne(x => x.Detail)
                .WithMany()
                .HasForeignKey(x => new { x.WhseId, x.ShipmentKey, x.ShipmentDetailId })
                .HasPrincipalKey(d => new { d.WhseId, d.ShipmentKey, d.ShipmentDetailId })
                .OnDelete(DeleteBehavior.Restrict);
        });

        b.Entity<ShipmentStatusLogRow>(e =>
        {
            e.ToTable("DOC_SHIPMENT_STATUS_LOG");
            e.HasKey(x => x.SerialKey);

            e.Property(x => x.SerialKey).HasColumnName("SERIALKEY").ValueGeneratedOnAdd();
            e.Property(x => x.WhseId).HasColumnName("WHSEID");
            e.Property(x => x.ShipmentKey).HasColumnName("SHIPMENTKEY");
            e.Property(x => x.FromStatus).HasColumnName("FROMSTATUS");
            e.Property(x => x.ToStatus).HasColumnName("TOSTATUS");
            e.Property(x => x.SourceSystem).HasColumnName("SOURCESYSTEM");
            e.Property(x => x.Message).HasColumnName("MESSAGE");
            e.Property(x => x.ChangeDate).HasColumnName("CHANGEDATE");
            e.Property(x => x.ChangeWho).HasColumnName("CHANGEWHO");

            e.HasOne(x => x.Shipment)
                .WithMany(s => s.StatusLogs)
                .HasForeignKey(x => new { x.WhseId, x.ShipmentKey })
                .HasPrincipalKey(s => new { s.WhseId, s.ShipmentKey })
                .OnDelete(DeleteBehavior.Restrict);
        });
    }

    /// <summary>
    /// The three tables TMS owns. None exists in MMDEV yet — migrations 004–006
    /// create them. Mapping them now costs nothing at runtime (EF only touches a
    /// table when something queries it) and means Phase 4 has nothing left to
    /// wire up.
    /// </summary>
    private static void ConfigureTmsOwned(ModelBuilder b)
    {
        b.Entity<ShipmentSendAttemptRow>(e =>
        {
            e.ToTable("TMS_SHIPMENT_SEND_ATTEMPT");
            e.HasKey(x => x.SerialKey);

            e.Property(x => x.SerialKey).HasColumnName("SERIALKEY").ValueGeneratedOnAdd();
            e.Property(x => x.WhseId).HasColumnName("WHSEID");
            e.Property(x => x.ShipmentKey).HasColumnName("SHIPMENTKEY");
            e.Property(x => x.AttemptNumber).HasColumnName("ATTEMPTNUMBER");
            e.Property(x => x.IdempotencyKey).HasColumnName("IDEMPOTENCYKEY");
            e.Property(x => x.ExternalReference).HasColumnName("EXTERNALREFERENCE");
            e.Property(x => x.RequestId).HasColumnName("REQUESTID");
            e.Property(x => x.Outcome).HasColumnName("OUTCOME");
            e.Property(x => x.CreatedAt).HasColumnName("CREATEDAT");
            e.Property(x => x.CreatedBy).HasColumnName("CREATEDBY");
            e.Property(x => x.SentAt).HasColumnName("SENTAT");
            e.Property(x => x.ResponseAt).HasColumnName("RESPONSEAT");
            e.Property(x => x.ErrorCode).HasColumnName("ERRORCODE");
            e.Property(x => x.ErrorMessage).HasColumnName("ERRORMESSAGE");
            e.Property(x => x.ResponsePayload).HasColumnName("RESPONSEPAYLOAD");

            e.HasOne(x => x.Shipment)
                .WithMany()
                .HasForeignKey(x => new { x.WhseId, x.ShipmentKey })
                .HasPrincipalKey(s => new { s.WhseId, s.ShipmentKey })
                .OnDelete(DeleteBehavior.Restrict);

            // One attempt number per shipment, and one idempotency key in the
            // whole table: both are what make a repeated call safe.
            e.HasIndex(x => new { x.WhseId, x.ShipmentKey, x.AttemptNumber }).IsUnique();
            e.HasIndex(x => x.IdempotencyKey).IsUnique();
        });

        b.Entity<DocumentAuditRow>(e =>
        {
            e.ToTable("TMS_DOCUMENT_AUDIT");
            e.HasKey(x => x.SerialKey);

            e.Property(x => x.SerialKey).HasColumnName("SERIALKEY").ValueGeneratedOnAdd();
            e.Property(x => x.WhseId).HasColumnName("WHSEID");
            e.Property(x => x.EntityType).HasColumnName("ENTITYTYPE");
            e.Property(x => x.EntityKey).HasColumnName("ENTITYKEY");
            e.Property(x => x.Action).HasColumnName("ACTION");
            e.Property(x => x.FromStatus).HasColumnName("FROMSTATUS");
            e.Property(x => x.ToStatus).HasColumnName("TOSTATUS");
            e.Property(x => x.PerformedBy).HasColumnName("PERFORMEDBY");
            e.Property(x => x.PerformedAt).HasColumnName("PERFORMEDAT");
            e.Property(x => x.Reason).HasColumnName("REASON");
            e.Property(x => x.RequestId).HasColumnName("REQUESTID");
            e.Property(x => x.ExternalReference).HasColumnName("EXTERNALREFERENCE");
            e.Property(x => x.Metadata).HasColumnName("METADATA");

            e.HasIndex(x => new { x.WhseId, x.EntityType, x.EntityKey, x.PerformedAt });
        });

        b.Entity<DocumentNumberRow>(e =>
        {
            e.ToTable("TMS_DOCUMENT_NUMBER");
            e.HasKey(x => new { x.WhseId, x.Prefix, x.Period });

            e.Property(x => x.WhseId).HasColumnName("WHSEID");
            e.Property(x => x.Prefix).HasColumnName("PREFIX");
            e.Property(x => x.Period).HasColumnName("PERIOD");
            e.Property(x => x.LastNumber).HasColumnName("LASTNUMBER");
            e.Property(x => x.RowVer).HasColumnName("ROWVER").IsRowVersion();
        });
    }
}
