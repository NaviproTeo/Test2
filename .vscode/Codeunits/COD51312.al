codeunit 51312 "Sitoo Shipment Mgt"
{
    // version Sitoo 3.0


    trigger OnRun();
    var
        Setup : Record "Sitoo Setup";
    begin
        Setup.SETRANGE(Active, true);
        if Setup.FINDSET then
          repeat
            SerializeOutbounds(Setup);
            COMMIT;
          until Setup.NEXT = 0;
    end;

    procedure ProcessInbound(var SitooLogEntry : Record "Sitoo Log Entry");
    begin
        case SitooLogEntry."Sub Type" of
          'PURCHASEORDER': SaveShipmentUpdate(SitooLogEntry);
          'TRANSFERORDER': SaveShipmentUpdate(SitooLogEntry);
          'NEW': SaveShipment(SitooLogEntry);
          'LIST': SaveShipments(SitooLogEntry);
        end;
    end;

    procedure ProcessOutbound(var SitooLogEntry : Record "Sitoo Log Entry") : Integer;
    var
        Status : Integer;
    begin
        case SitooLogEntry."Sub Type" of
          'PURCHASEORDER': Status := SendShipment(SitooLogEntry);
          'TRANSFERORDER': Status := SendShipment(SitooLogEntry);
        end;

        exit(Status);
    end;

    procedure SerializeOutbounds(var Setup : Record "Sitoo Setup");
    var
        NextCheck : DateTime;
    begin
        if Setup."Send Shipments" then begin
          NextCheck := Setup."Last Send Shipments" + Setup."Send Shipments Interval" * 60000;
          if (CURRENTDATETIME > NextCheck) or (GUIALLOWED) then begin
            SerializeShipments(Setup);
            Setup."Last Send Shipments" := CURRENTDATETIME;
            Setup.MODIFY;
          end;
        end;
    end;

    local procedure SerializeShipments(var Setup : Record "Sitoo Setup");
    var
        String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
        SitooOutboundQueue : Record "Sitoo Outbound Queue";
        Common : Codeunit "Sitoo Common";
        SitooShipmentTEMP : Record "Sitoo Shipment" temporary;
        SitooShipmentItemTEMP : Record "Sitoo Shipment Item" temporary;
        DeleteQueue : Boolean;
    begin
        if Setup."Shipment Send Purchase Order" then begin
          SitooOutboundQueue.RESET;
          SitooOutboundQueue.SETCURRENTKEY(DateTime);
          SitooOutboundQueue.SETRANGE("Market Code", Setup."Market Code");
          SitooOutboundQueue.SETRANGE(Type, 'SHIPMENT');
          SitooOutboundQueue.SETRANGE("Sub Type", 'PURCHASEORDER');
          SitooOutboundQueue.SETFILTER("Retry Count", '<%1', Setup."Outbound Queue Retry Count");
          if SitooOutboundQueue.FINDSET then begin
            repeat
              if ValidateShipment(SitooOutboundQueue) then begin
                if (SitooOutboundQueue."Primary Key 2" = 'CANCELLED') and ArchiveShipment(SitooOutboundQueue, String) then begin
                  Common.AddOutboundLogEntry(String, 'SHIPMENT', 'PURCHASEORDER', 'ArchiveShipment', SitooOutboundQueue."Primary Key 1", 'PUT', Setup."Market Code");
                  SitooOutboundQueue.DELETE;
                end else if SerializePurchaseOrder(SitooOutboundQueue."Primary Key 1", String, SitooShipmentTEMP, SitooShipmentItemTEMP, Setup."Market Code") then begin
                  Common.AddOutboundLogEntry(String, 'SHIPMENT', 'PURCHASEORDER', 'SerializePurchaseOrder', SitooOutboundQueue."Primary Key 1", 'POST', Setup."Market Code");
                  AddShipment(SitooShipmentTEMP, SitooShipmentItemTEMP);
                  SitooOutboundQueue.DELETE;
                end else
                  Common.AddQueueError(SitooOutboundQueue);
              end else
                SitooOutboundQueue.DELETE;
            until SitooOutboundQueue.NEXT = 0;
          end;
        end;

        if Setup."Shipment Send Transfer Order" then begin
          SitooOutboundQueue.RESET;
          SitooOutboundQueue.SETCURRENTKEY(DateTime);
          SitooOutboundQueue.SETRANGE("Market Code", Setup."Market Code");
          SitooOutboundQueue.SETRANGE(Type, 'SHIPMENT');
          SitooOutboundQueue.SETRANGE("Sub Type", 'TRANSFERORDER');
          SitooOutboundQueue.SETFILTER("Retry Count", '<%1', Setup."Outbound Queue Retry Count");
          if SitooOutboundQueue.FINDSET then begin
            repeat
              if ValidateShipment(SitooOutboundQueue) then begin
                if SerializeTransferOrder(SitooOutboundQueue."Primary Key 1", String, SitooShipmentTEMP, SitooShipmentItemTEMP, Setup."Market Code") then begin
                  Common.AddOutboundLogEntry(String, 'SHIPMENT', 'TRANSFERORDER', 'SerializeTransferOrder', SitooOutboundQueue."Primary Key 1", 'POST', Setup."Market Code");
                  AddShipment(SitooShipmentTEMP, SitooShipmentItemTEMP);
                  SitooOutboundQueue.DELETE;
                end else
                  Common.AddQueueError(SitooOutboundQueue);
              end else
                SitooOutboundQueue.DELETE;
            until SitooOutboundQueue.NEXT = 0;
          end;
        end;

        if Setup."Shipment Send Transfer Order" then begin
          SitooOutboundQueue.RESET;
          SitooOutboundQueue.SETCURRENTKEY(DateTime);
          SitooOutboundQueue.SETRANGE("Market Code", Setup."Market Code");
          SitooOutboundQueue.SETRANGE(Type, 'SHIPMENT');
          SitooOutboundQueue.SETRANGE("Sub Type", 'TRANSFERSHIPMENT');
          SitooOutboundQueue.SETFILTER("Retry Count", '<%1', Setup."Outbound Queue Retry Count");
          if SitooOutboundQueue.FINDSET then begin
            repeat
              if ValidateShipment(SitooOutboundQueue) then begin
                if SerializeTransferShipment(SitooOutboundQueue."Primary Key 1", String, SitooShipmentTEMP, SitooShipmentItemTEMP, Setup."Market Code") then begin
                  Common.AddOutboundLogEntry(String, 'SHIPMENT', 'TRANSFERORDER', 'SerializeTransferOrder', SitooOutboundQueue."Primary Key 1", 'POST', Setup."Market Code");
                  AddShipment(SitooShipmentTEMP, SitooShipmentItemTEMP);
                  SitooOutboundQueue.DELETE;
                end else
                  Common.AddQueueError(SitooOutboundQueue);
              end else
                SitooOutboundQueue.DELETE;
            until SitooOutboundQueue.NEXT = 0;
          end;
        end;
    end;

    [TryFunction]
    local procedure SerializePurchaseOrder(DocumentNo : Code[20];var String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";var SitooShipmentTEMP : Record "Sitoo Shipment" temporary;var SitooShipmentItemTEMP : Record "Sitoo Shipment Item" temporary;MarketCode : Code[20]);
    var
        PurchaseHeader : Record "Purchase Header";
        PurchaseLine : Record "Purchase Line";
        SitooWarehouse : Record "Sitoo Warehouse";
        SitooProductId : Record "Sitoo Product";
        Location : Record Location;
        Vendor : Record Vendor;
        JsonMgt : Codeunit "Sitoo Json Mgt";
        SitooProductMgt : Codeunit "Sitoo Product Mgt";
        ItemId : Integer;
    begin

        SitooShipmentTEMP.DELETEALL;
        SitooShipmentItemTEMP.DELETEALL;

        SitooShipmentTEMP."Entry No." := GetNextShipmentEntryNo(MarketCode);
        SitooShipmentTEMP."Document Type" := SitooShipmentTEMP."Document Type"::"Purchase Order";
        SitooShipmentTEMP."Document No." := DocumentNo;
        SitooShipmentTEMP."Market Code" := MarketCode;
        SitooShipmentTEMP.shipmentstate := 10; // 0 = New, 10 = InTransit
        SitooShipmentTEMP.INSERT;

        PurchaseHeader.GET(PurchaseHeader."Document Type"::Order, DocumentNo);

        SitooWarehouse.SETRANGE("Market Code", MarketCode);
        SitooWarehouse.SETRANGE("Location Code", PurchaseHeader."Location Code");
        SitooWarehouse.FINDFIRST;
        Location.GET(SitooWarehouse."Location Code");

        JsonMgt.StartJSon;

        JsonMgt.AddIntProperty('shipmentstate', SitooShipmentTEMP.shipmentstate);
        JsonMgt.AddIntProperty('receiver_warehouseid', SitooWarehouse."Warehouse Id");
        JsonMgt.AddToJSon('sender_name', PurchaseHeader."Buy-from Vendor Name");
        JsonMgt.AddToJSon('receiver_name', Location.Name);
        JsonMgt.AddToJSon('externalid', DocumentNo);
        //JsonMgt.AddToJSon('comment', DocumentNo);

        SitooShipmentTEMP.receiver_warehouseid := SitooWarehouse."Warehouse Id";
        SitooShipmentTEMP.externalid := DocumentNo;
        SitooShipmentTEMP."From Location" := PurchaseHeader."Buy-from Vendor No.";
        SitooShipmentTEMP."To Location" := PurchaseHeader."Location Code";
        SitooShipmentTEMP.MODIFY;

        PurchaseLine.SETRANGE("Document No.", PurchaseHeader."No.");
        PurchaseLine.SETRANGE(Type,  PurchaseLine.Type::Item);
        PurchaseLine.SETFILTER("Outstanding Quantity", '>0');
        if PurchaseLine.FINDSET then begin
          ItemId := 1;

          JsonMgt.AddProperty('shipmentitems');
          JsonMgt.StartJSonArray;
          repeat
            SitooProductId.SETRANGE("No.", PurchaseLine."No.");
            SitooProductId.SETRANGE("Variant Code", PurchaseLine."Variant Code");
            SitooProductId.SETRANGE("Market Code", MarketCode);
            SitooProductId.FINDFIRST;

            SitooShipmentItemTEMP.INIT;
            SitooShipmentItemTEMP."Shipment Entry No." := SitooShipmentTEMP."Entry No.";
            SitooShipmentItemTEMP."Shipment Item Id" := ItemId;
            SitooShipmentItemTEMP."Document Type" := SitooShipmentItemTEMP."Document Type"::"Purchase Order";
            SitooShipmentItemTEMP."Document No." := SitooShipmentTEMP."Document No.";
            SitooShipmentItemTEMP."Line No." := PurchaseLine."Line No.";
            SitooShipmentItemTEMP."Market Code" := SitooShipmentTEMP."Market Code";

            JsonMgt.BeginJsonObject;

            SitooShipmentItemTEMP.shipmentitemid := ItemId;

            JsonMgt.AddIntProperty('shipmentitemid', SitooShipmentItemTEMP.shipmentitemid);

            JsonMgt.AddToJSon('sku', SitooProductId.SKU);
            JsonMgt.AddToJSon('productname', SitooProductMgt.GetItemDescription(SitooProductId."No.", SitooProductId."Color Code", SitooProductId."Size Code", MarketCode));
            JsonMgt.AddIntProperty('quantity', PurchaseLine."Outstanding Quantity");
            JsonMgt.EndJsonObject;

            SitooShipmentItemTEMP.sku := SitooProductId.SKU;
            SitooShipmentItemTEMP.quantity := PurchaseLine."Outstanding Quantity";
            SitooShipmentItemTEMP.INSERT;

            ItemId += 1;
          until PurchaseLine.NEXT = 0;
          JsonMgt.EndJSonArray;

        end;
        JsonMgt.EndJSon;
        String := JsonMgt.GetJSon;
    end;

    [TryFunction]
    local procedure SerializeTransferOrder(DocumentNo : Code[20];var String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";var SitooShipmentTEMP : Record "Sitoo Shipment" temporary;var SitooShipmentItemTEMP : Record "Sitoo Shipment Item" temporary;MarketCode : Code[20]);
    var
        TransferHeader : Record "Transfer Header";
        TransferLine : Record "Transfer Line";
        SitooWarehouse : Record "Sitoo Warehouse";
        SitooProductId : Record "Sitoo Product";
        JsonMgt : Codeunit "Sitoo Json Mgt";
        SenderId : Integer;
        ReceiverId : Integer;
        SenderName : Text;
        ReceiverName : Text;
        Location : Record Location;
        ItemId : Integer;
        SitooProductMgt : Codeunit "Sitoo Product Mgt";
    begin

        SitooShipmentTEMP.DELETEALL;
        SitooShipmentItemTEMP.DELETEALL;

        SitooShipmentTEMP."Entry No." := GetNextShipmentEntryNo(MarketCode);
        SitooShipmentTEMP."Document Type" := SitooShipmentTEMP."Document Type"::"Transfer Order";
        SitooShipmentTEMP."Document No." := DocumentNo;
        SitooShipmentTEMP."Market Code" := MarketCode;
        SitooShipmentTEMP.shipmentstate := 0;
        SitooShipmentTEMP.INSERT;

        TransferHeader.GET(DocumentNo);

        SitooWarehouse.RESET;
        SitooWarehouse.SETRANGE("Location Code", TransferHeader."Transfer-from Code");
        if SitooWarehouse.FINDFIRST then begin
          Location.GET(SitooWarehouse."Location Code");
          SenderId := SitooWarehouse."Warehouse Id";
        end else
          Location.GET(TransferHeader."Transfer-from Code");

        SenderName := Location.Name;

        SitooWarehouse.RESET;
        SitooWarehouse.SETRANGE("Location Code", TransferHeader."Transfer-to Code");
        if SitooWarehouse.FINDFIRST then begin
          Location.GET(SitooWarehouse."Location Code");
          ReceiverId := SitooWarehouse."Warehouse Id";
        end else
          Location.GET(TransferHeader."Transfer-to Code");

        ReceiverName := Location.Name;

        JsonMgt.StartJSon;
        JsonMgt.AddIntProperty('shipmentstate', SitooShipmentTEMP.shipmentstate); // 0 = New, 10 = InTransit
        if SenderId <> 0 then
          JsonMgt.AddIntProperty('sender_warehouseid', SenderId);
        if ReceiverId <> 0 then
          JsonMgt.AddIntProperty('receiver_warehouseid', ReceiverId);
        JsonMgt.AddToJSon('sender_name', SenderName);
        JsonMgt.AddToJSon('receiver_name', ReceiverName);
        JsonMgt.AddToJSon('externalid', DocumentNo);
        //JsonMgt.AddToJSon('comment', DocumentNo);

        SitooShipmentTEMP.receiver_warehouseid := ReceiverId;
        SitooShipmentTEMP.sender_warehouseid := SenderId;
        SitooShipmentTEMP.externalid := DocumentNo;
        SitooShipmentTEMP."From Location" := TransferHeader."Transfer-from Code";
        SitooShipmentTEMP."To Location" := TransferHeader."Transfer-to Code";
        SitooShipmentTEMP.MODIFY;

        TransferLine.SETRANGE("Document No.", DocumentNo);
        TransferLine.SETRANGE("Derived From Line No.", 0);
        if TransferLine.FINDSET then begin
          ItemId := 1;

          JsonMgt.AddProperty('shipmentitems');
          JsonMgt.StartJSonArray;
          repeat
            SitooProductId.SETRANGE("No.", TransferLine."Item No.");
            SitooProductId.SETRANGE("Variant Code", TransferLine."Variant Code");
            SitooProductId.FINDFIRST;

            SitooShipmentItemTEMP.INIT;
            SitooShipmentItemTEMP."Market Code" := SitooShipmentTEMP."Market Code";
            SitooShipmentItemTEMP."Shipment Item Id" := ItemId;
            SitooShipmentItemTEMP."Shipment Entry No." := SitooShipmentTEMP."Entry No.";
            SitooShipmentItemTEMP."Document Type" := SitooShipmentItemTEMP."Document Type"::"Transfer Order";
            SitooShipmentItemTEMP."Document No." := SitooShipmentTEMP."Document No.";
            SitooShipmentItemTEMP."Line No." := TransferLine."Line No.";

            JsonMgt.BeginJsonObject;

            SitooShipmentItemTEMP.shipmentitemid := ItemId;

            JsonMgt.AddIntProperty('shipmentitemid', SitooShipmentItemTEMP.shipmentitemid);
            JsonMgt.AddToJSon('sku', SitooProductId.SKU);
            JsonMgt.AddToJSon('productname', SitooProductMgt.GetItemDescription(SitooProductId."No.", SitooProductId."Color Code", SitooProductId."Size Code", MarketCode));
            JsonMgt.AddIntProperty('quantity', TransferLine.Quantity);
            JsonMgt.EndJsonObject;

            SitooShipmentItemTEMP.sku := SitooProductId.SKU;
            SitooShipmentItemTEMP.quantity := TransferLine.Quantity;
            SitooShipmentItemTEMP.INSERT;

            ItemId += 1;
          until TransferLine.NEXT = 0;
          JsonMgt.EndJSonArray;
        end;

        JsonMgt.EndJSon;
        String := JsonMgt.GetJSon;
    end;

    [TryFunction]
    local procedure SerializeTransferShipment(DocumentNo : Code[20];var String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";var SitooShipmentTEMP : Record "Sitoo Shipment" temporary;var SitooShipmentItemTEMP : Record "Sitoo Shipment Item" temporary;MarketCode : Code[20]);
    var
        SitooWarehouse : Record "Sitoo Warehouse";
        SitooProductId : Record "Sitoo Product";
        JsonMgt : Codeunit "Sitoo Json Mgt";
        SenderId : Integer;
        ReceiverId : Integer;
        SenderName : Text;
        ReceiverName : Text;
        Location : Record Location;
        ItemId : Integer;
        SitooProductMgt : Codeunit "Sitoo Product Mgt";
        TransferShipmentHeader : Record "Transfer Shipment Header";
        TransferShipmentLine : Record "Transfer Shipment Line";
    begin

        TransferShipmentHeader.GET(DocumentNo);

        SitooShipmentTEMP.DELETEALL;
        SitooShipmentItemTEMP.DELETEALL;

        SitooShipmentTEMP."Entry No." := GetNextShipmentEntryNo(MarketCode);
        SitooShipmentTEMP."Document Type" := SitooShipmentTEMP."Document Type"::"Transfer Order";
        SitooShipmentTEMP."Market Code" := MarketCode;
        SitooShipmentTEMP."Document No." := TransferShipmentHeader."Transfer Order No.";
        SitooShipmentTEMP.shipmentstate := 10;
        SitooShipmentTEMP.INSERT;

        Location.GET(TransferShipmentHeader."Transfer-from Code");
        SenderName := Location.Name;

        SitooWarehouse.RESET;
        SitooWarehouse.SETRANGE("Location Code", TransferShipmentHeader."Transfer-to Code");
        if not SitooWarehouse.FINDFIRST then
          ERROR('Receiver must be Sitoo Warehouse');

        Location.GET(SitooWarehouse."Location Code");
        ReceiverId := SitooWarehouse."Warehouse Id";
        ReceiverName := Location.Name;

        JsonMgt.StartJSon;
        JsonMgt.AddIntProperty('shipmentstate', SitooShipmentTEMP.shipmentstate); // 0 = New, 10 = InTransit
        JsonMgt.AddIntProperty('receiver_warehouseid', ReceiverId);
        JsonMgt.AddToJSon('sender_name', SenderName);
        JsonMgt.AddToJSon('receiver_name', ReceiverName);
        JsonMgt.AddToJSon('externalid', DocumentNo);
        //JsonMgt.AddToJSon('comment', DocumentNo);

        SitooShipmentTEMP.receiver_warehouseid := ReceiverId;
        SitooShipmentTEMP.externalid := DocumentNo;
        SitooShipmentTEMP."From Location" := TransferShipmentHeader."Transfer-from Code";
        SitooShipmentTEMP."To Location" := TransferShipmentHeader."Transfer-to Code";
        SitooShipmentTEMP.MODIFY;

        TransferShipmentLine.SETRANGE("Document No.", DocumentNo);
        TransferShipmentLine.SETFILTER(Quantity, '<>%1', 0);
        if TransferShipmentLine.FINDSET then begin
          ItemId := 1;

          JsonMgt.AddProperty('shipmentitems');
          JsonMgt.StartJSonArray;
          repeat
            SitooProductId.SETRANGE("No.", TransferShipmentLine."Item No.");
            SitooProductId.SETRANGE("Variant Code", TransferShipmentLine."Variant Code");
            SitooProductId.FINDFIRST;

            SitooShipmentItemTEMP.INIT;
            SitooShipmentItemTEMP."Market Code" := SitooShipmentTEMP."Market Code";
            SitooShipmentItemTEMP."Shipment Item Id" := ItemId;
            SitooShipmentItemTEMP."Shipment Entry No." := SitooShipmentTEMP."Entry No.";
            SitooShipmentItemTEMP."Document Type" := SitooShipmentItemTEMP."Document Type"::"Transfer Order";
            SitooShipmentItemTEMP."Document No." := SitooShipmentTEMP."Document No.";
            SitooShipmentItemTEMP."Line No." := TransferShipmentLine."Line No.";

            JsonMgt.BeginJsonObject;

            if SitooShipmentItemTEMP.shipmentitemid = 0 then
              SitooShipmentItemTEMP.shipmentitemid := ItemId;

            JsonMgt.AddIntProperty('shipmentitemid', SitooShipmentItemTEMP.shipmentitemid);
            JsonMgt.AddToJSon('sku', SitooProductId.SKU);
            JsonMgt.AddToJSon('productname', SitooProductMgt.GetItemDescription(SitooProductId."No.", SitooProductId."Color Code", SitooProductId."Size Code", MarketCode));
            JsonMgt.AddIntProperty('quantity', TransferShipmentLine.Quantity);
            JsonMgt.EndJsonObject;

            SitooShipmentItemTEMP.sku := SitooProductId.SKU;
            SitooShipmentItemTEMP.quantity := TransferShipmentLine.Quantity;
            SitooShipmentItemTEMP.INSERT;

            ItemId += 1;
          until TransferShipmentLine.NEXT = 0;
          JsonMgt.EndJSonArray;
        end;

        JsonMgt.EndJSon;
        String := JsonMgt.GetJSon;
    end;

    [TryFunction]
    local procedure ArchiveShipment(var SitooOutboundQueue : Record "Sitoo Outbound Queue";var String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String");
    var
        JsonMgt : Codeunit "Sitoo Json Mgt";
    begin
        JsonMgt.StartJSon;
        JsonMgt.AddIntProperty('shipmentstate', 100); // cancelled
        JsonMgt.AddBoolProperty('archived', true);
        JsonMgt.AddToJSon('comment', 'Reopened');
        JsonMgt.EndJSon;

        String := JsonMgt.GetJSon;
    end;

    local procedure SendShipment(var SitooLogEntry : Record "Sitoo Log Entry") : Integer;
    var
        Common : Codeunit "Sitoo Common";
        Setup : Record "Sitoo Setup";
        Status : Integer;
        URL : Text;
    begin
        Setup.GET(SitooLogEntry."Market Code");

        if SitooLogEntry.Action = 'POST' then
          if GetShipmentId(SitooLogEntry) > 0 then
            SitooLogEntry.Action := 'PUT';

        if SitooLogEntry.Action = 'POST' then
          URL := Setup."Base URL" + 'shipments.json';
        if SitooLogEntry.Action = 'PUT' then
          URL := Setup."Base URL" + 'shipments/' + FORMAT(GetShipmentId(SitooLogEntry)) + '.json';
        if SitooLogEntry.Action = 'DELETE' then
          URL := Setup."Base URL" + 'shipments/' + FORMAT(GetShipmentId(SitooLogEntry)) + '.json';

        Status := Common.UploadLogEntry(SitooLogEntry, 'SendShipment', true, URL);

        if Status > 0 then begin
          SitooLogEntry.Status := SitooLogEntry.Status::Processed;
          SitooLogEntry.MODIFY;
        end;

        exit(Status);
    end;

    local procedure SaveShipmentUpdate(var SitooLogEntry : Record "Sitoo Log Entry");
    var
        Common : Codeunit "Sitoo Common";
        XmlDocument : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlDocument";
        XmlElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        ShipmentId : Integer;
        SitooShipment : Record "Sitoo Shipment";
        Archived : Boolean;
    begin
        SitooShipment.SETRANGE("Market Code", SitooLogEntry."Market Code");
        SitooShipment.SETRANGE(externalid, SitooLogEntry."Document No.");
        SitooShipment.SETRANGE(archived, false);
        if not SitooShipment.FINDFIRST then
          exit;

        Common.GetResponseXML(SitooLogEntry, XmlDocument);

        XmlElement := XmlDocument.DocumentElement.Item('root');

        if EVALUATE(ShipmentId, XmlElement.InnerXml) then begin
          SitooShipment.shipmentid := ShipmentId;
          SitooLogEntry.Information := FORMAT(ShipmentId);
          SitooShipment.MODIFY;
        end else if EVALUATE(Archived, UPPERCASE(XmlElement.InnerXml)) then begin
          SitooShipment.archived := Archived;
          SitooLogEntry.Information := FORMAT(SitooShipment.shipmentid) + ' cancelled';
          SitooShipment.MODIFY;
        end;

        SitooLogEntry.Status := SitooLogEntry.Status::Processed;
        SitooLogEntry.MODIFY;
    end;

    procedure CheckForShipments();
    var
        Setup : Record "Sitoo Setup";
        SitooShipment : Record "Sitoo Shipment";
        ShipmentId : Integer;
        PrevId : Integer;
        NextId : Integer;
        LastId : Integer;
    begin
        // Setup.GET;
        //
        // LastId := Setup."Last Shipment Id";
        //
        // IF SitooShipment.FINDSET THEN BEGIN
        //  REPEAT
        //
        //  UNTIL SitooShipment.NEXT = 0;
        // END;
    end;

    procedure GetShipments(var Setup : Record "Sitoo Setup");
    var
        SitooShipment : Record "Sitoo Shipment";
        Common : Codeunit "Sitoo Common";
        Index : Integer;
        URL : Text;
    begin

        Index := SitooShipment.COUNT;

        URL := Setup."Base URL"  + 'shipments.json?start=' + FORMAT(Index) + '&num=100';

        Common.Download(URL, 'SHIPMENT', 'LIST', 'GetShipments', '', Setup."Market Code");
    end;

    procedure GetShipment(ShipmentId : Integer;MarketCode : Code[20]);
    var
        Setup : Record "Sitoo Setup";
        URL : Text;
        Common : Codeunit "Sitoo Common";
    begin
        Setup.GET(MarketCode);

        URL := Setup."Base URL" + 'shipments/' + FORMAT(ShipmentId) + '.json';

        Common.Download(URL, 'SHIPMENT', 'NEW', 'GetShipment', FORMAT(ShipmentId), MarketCode);
    end;

    local procedure SaveShipments(var SitooLogEntry : Record "Sitoo Log Entry");
    var
        Common : Codeunit "Sitoo Common";
        Counter : Integer;
        ShipmentId : Integer;
        XmlDocument : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlDocument";
        XmlShipmentList : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNodeList";
        XmlShipmentElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        ProgressWindow : Dialog;
    begin
        Common.GetResponseXML(SitooLogEntry, XmlDocument);

        XmlShipmentList := XmlDocument.GetElementsByTagName('items');

        if XmlShipmentList.Count > 0 then begin
          Counter := 0;

          if GUIALLOWED then
            ProgressWindow.OPEN('Processing shipment #1#######');

          repeat
            XmlShipmentElement := XmlShipmentList.Item(Counter);

            ShipmentId := Common.GetIntXML(XmlShipmentElement, 'shipmentid');

            if GUIALLOWED then
              ProgressWindow.UPDATE(1, FORMAT(ShipmentId));

            SaveShipmentFromList(ShipmentId, XmlShipmentElement, SitooLogEntry);

            Counter += 1;
          until Counter = XmlShipmentList.Count;

          if GUIALLOWED then
            ProgressWindow.CLOSE;
        end;

        SitooLogEntry.Information := FORMAT(Counter) + ' shipments';
        SitooLogEntry.Status := SitooLogEntry.Status::Processed;
        SitooLogEntry.MODIFY;

        if Counter = 0 then
          SitooLogEntry.DELETE;
    end;

    local procedure SaveShipmentFromList(ShipmentId : Integer;var XmlShipmentElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";var LogEntry : Record "Sitoo Log Entry");
    var
        Common : Codeunit "Sitoo Common";
        SitooShipment : Record "Sitoo Shipment";
    begin
        if not SitooShipment.GET(ShipmentId, LogEntry."Market Code") then begin
          SitooShipment.INIT;
          SitooShipment.shipmentid := ShipmentId;
          SitooShipment."Market Code" := LogEntry."Market Code";
          SitooShipment.Source := SitooShipment.Source::POS;
          SitooShipment.INSERT;

          GetShipment(ShipmentId, LogEntry."Market Code");
        end;

        SitooShipment.externalid := Common.GetValueXML(XmlShipmentElement, 'externalid');
        SitooShipment.shipmentstate := Common.GetIntXML(XmlShipmentElement, 'shipmentstate');
        SitooShipment.datenew := Common.GetDateTimeXML(XmlShipmentElement, 'datenew');
        SitooShipment.dateintransit := Common.GetDateTimeXML(XmlShipmentElement, 'dateinstransit');
        SitooShipment.datereceived := Common.GetDateTimeXML(XmlShipmentElement, 'datereceived');
        SitooShipment.datecancelled := Common.GetDateTimeXML(XmlShipmentElement, 'datecancelled');
        SitooShipment.sender_warehouseid := Common.GetIntXML(XmlShipmentElement,'sender_warehouseid');
        SitooShipment.sender_name := Common.GetValueXML(XmlShipmentElement,'sender_name');
        SitooShipment.receiver_warehouseid := Common.GetIntXML(XmlShipmentElement,'receiver_warehouseid');

        if (SitooShipment.sender_warehouseid <> 0) and (SitooShipment.receiver_warehouseid <> 0) then
          SitooShipment."Document Type" := SitooShipment."Document Type"::"Transfer Order"
        else
          SitooShipment."Document Type" := SitooShipment."Document Type"::"Purchase Order";

        SitooShipment.MODIFY;
    end;

    local procedure SaveShipment(var SitooLogEntry : Record "Sitoo Log Entry");
    var
        Common : Codeunit "Sitoo Common";
        XmlDocument : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlDocument";
        XmlShipmentElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        ShipmentId : Integer;
        SitooShipment : Record "Sitoo Shipment";
        SKU : Text;
        ItemId : Integer;
    begin
        Common.GetResponseXML(SitooLogEntry, XmlDocument);

        XmlShipmentElement := XmlDocument.DocumentElement;

        ShipmentId := Common.GetIntXML(XmlShipmentElement, 'root/shipmentid');

        SitooShipment.SETRANGE(shipmentid, ShipmentId);
        SitooShipment.SETRANGE("Market Code", SitooLogEntry."Market Code");
        if not SitooShipment.FINDFIRST then begin
          SitooShipment.INIT;
          SitooShipment."Entry No." := GetNextShipmentEntryNo(SitooLogEntry."Market Code");
          SitooShipment.shipmentid := ShipmentId;
          SitooShipment."Market Code" := SitooLogEntry."Market Code";
          SitooShipment.Source := SitooShipment.Source::POS;
          SitooShipment.INSERT;
        end;

        SitooShipment.externalid := Common.GetValueXML(XmlShipmentElement, 'root/externalid');
        SitooShipment.shipmentstate := Common.GetIntXML(XmlShipmentElement, 'root/shipmentstate');
        SitooShipment.datenew := Common.GetDateTimeXML(XmlShipmentElement, 'root/datenew');
        SitooShipment.dateintransit := Common.GetDateTimeXML(XmlShipmentElement, 'root/dateinstransit');
        SitooShipment.datereceived := Common.GetDateTimeXML(XmlShipmentElement, 'root/datereceived');
        SitooShipment.datecancelled := Common.GetDateTimeXML(XmlShipmentElement, 'root/datecancelled');
        SitooShipment.sender_warehouseid := Common.GetIntXML(XmlShipmentElement, 'root/sender_warehouseid');
        SitooShipment.sender_name := Common.GetValueXML(XmlShipmentElement, 'root/sender_name');
        SitooShipment.receiver_warehouseid := Common.GetIntXML(XmlShipmentElement, 'root/receiver_warehouseid');

        SitooShipment.archived := Common.GetBoolXML(XmlShipmentElement, 'root/archived');
        SitooShipment.comment := Common.GetValueXML(XmlShipmentElement, 'root/comment');

        if (SitooShipment.sender_warehouseid <> 0) and (SitooShipment.receiver_warehouseid <> 0) then
          SitooShipment."Document Type" := SitooShipment."Document Type"::"Transfer Order"
        else
          SitooShipment."Document Type" := SitooShipment."Document Type"::"Purchase Order";

        SitooShipment.MODIFY;

        SaveShipmentItems(SitooShipment, XmlShipmentElement);

        SitooLogEntry."Document No." := FORMAT(ShipmentId);
        SitooLogEntry.Status := SitooLogEntry.Status::Processed;
        SitooLogEntry.MODIFY;
    end;

    local procedure SaveShipmentItems(SitooShipment : Record "Sitoo Shipment";var XmlShipmentElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode");
    var
        Common : Codeunit "Sitoo Common";
        ShipmentItem : Record "Sitoo Shipment Item";
        XmlItemList : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNodeList";
        XmlItemElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        Counter : Integer;
        ItemId : Integer;
    begin

        XmlItemList := XmlShipmentElement.SelectNodes('root/shipmentitems');

        if XmlItemList.Count > 0 then begin
          Counter := 0;
          repeat
            XmlItemElement := XmlItemList.Item(Counter);
            ItemId := Common.GetIntXML(XmlItemElement, 'shipmentitemid');
            if not ShipmentItem.GET(SitooShipment."Entry No.", ItemId, SitooShipment."Market Code") then begin
              ShipmentItem.INIT;
              ShipmentItem."Shipment Entry No." := SitooShipment."Entry No.";
              ShipmentItem."Shipment Item Id" := ItemId;
              ShipmentItem."Market Code" := SitooShipment."Market Code";
              ShipmentItem.shipmentid := SitooShipment.shipmentid;
              ShipmentItem.shipmentitemid := ItemId;
              ShipmentItem."Document No." := SitooShipment."Document No.";
              ShipmentItem."Document Type" := SitooShipment."Document Type";
              ShipmentItem."Line No." := ItemId * 10000;
              ShipmentItem.INSERT;
            end;

            ShipmentItem.sku := Common.GetValueXML(XmlItemElement, 'sku');
            ShipmentItem.quantity := Common.GetIntXML(XmlItemElement, 'quantity');
            ShipmentItem.MODIFY;

            Counter += 1;
          until Counter = XmlItemList.Count;
        end;
    end;

    local procedure AddShipment(var SitooShipmentTEMP : Record "Sitoo Shipment" temporary;var SitooShipmentItemTEMP : Record "Sitoo Shipment Item" temporary);
    var
        SitooShipment : Record "Sitoo Shipment";
        SitooShipmentItem : Record "Sitoo Shipment Item";
    begin
        if SitooShipmentTEMP.FINDFIRST then begin
          SitooShipment.RESET;
        //  SitooShipment.SETRANGE("Document Type", SitooShipmentTEMP."Document Type");
        //  SitooShipment.SETRANGE("Document No.", SitooShipmentTEMP."Document No.");
        //  SitooShipment.SETRANGE(archived, FALSE);
        //  IF SitooShipment.FINDFIRST THEN BEGIN
          if SitooShipment.GET(SitooShipmentTEMP."Entry No.", SitooShipmentTEMP."Market Code") then begin
            SitooShipment.COPY(SitooShipmentTEMP);
            SitooShipment.MODIFY;
          end else begin
            SitooShipment.INIT;
            SitooShipment.COPY(SitooShipmentTEMP);
            SitooShipment.INSERT;
          end;

          if SitooShipmentItemTEMP.FINDSET then begin
            repeat
              SitooShipmentItem.RESET;
        //      SitooShipmentItem.SETRANGE("Document Type", SitooShipmentItemTEMP."Document Type");
        //      SitooShipmentItem.SETRANGE("Document No.", SitooShipmentItemTEMP."Document No.");
        //      SitooShipmentItem.SETRANGE("Line No.", SitooShipmentItemTEMP."Line No.");
        //      SitooShipmentItem.SETRANGE("Shipment Entry No.", SitooShipment."Entry No.");
        //      IF SitooShipmentItem.FINDFIRST THEN BEGIN
              if SitooShipmentItem.GET(SitooShipmentItemTEMP."Shipment Entry No.", SitooShipmentItemTEMP."Shipment Item Id", SitooShipmentItemTEMP."Market Code") then begin
                SitooShipmentItem.COPY(SitooShipmentItemTEMP);
                SitooShipmentItem.MODIFY;
              end else begin
                SitooShipmentItem.INIT;
                SitooShipmentItem.COPY(SitooShipmentItemTEMP);
                SitooShipmentItem.INSERT;
              end;
            until SitooShipmentItemTEMP.NEXT = 0;
          end;
        end;
    end;

    local procedure GetShipmentId(var SitooLogEntry : Record "Sitoo Log Entry") : Integer;
    var
        SitooShipment : Record "Sitoo Shipment";
    begin
        if SitooLogEntry."Sub Type" = 'PURCHASEORDER' then
          SitooShipment.SETRANGE("Document Type", SitooShipment."Document Type"::"Purchase Order");
        if SitooLogEntry."Sub Type" = 'TRANSFERORDER' then
          SitooShipment.SETRANGE("Document Type", SitooShipment."Document Type"::"Transfer Order");
        SitooShipment.SETRANGE("Document No.", SitooLogEntry."Document No.");
        SitooShipment.SETRANGE(archived, false);
        SitooShipment.SETRANGE("Market Code", SitooLogEntry."Market Code");
        if SitooShipment.FINDFIRST then
          exit(SitooShipment.shipmentid);
        exit(0);
    end;

    local procedure GetNextShipmentId(MarketCode : Code[20]) : Integer;
    var
        ShipmentId : Integer;
        SitooSetup : Record "Sitoo Setup";
    begin
        SitooSetup.GET(MarketCode);

        exit(SitooSetup."Last Shipment Id" + 1);
    end;

    local procedure SetLastShipmentId(NewShipmentId : Integer;MarketCode : Code[20]);
    var
        SitooSetup : Record "Sitoo Setup";
    begin
        SitooSetup.GET(MarketCode);

        if SitooSetup."Last Shipment Id" < NewShipmentId then begin
          SitooSetup."Last Shipment Id" := NewShipmentId;
          SitooSetup.MODIFY;
        end;
    end;

    local procedure GetNextShipmentEntryNo(MarketCode : Code[20]) : Integer;
    var
        SitooShipment : Record "Sitoo Shipment";
    begin
        SitooShipment.SETRANGE("Market Code", MarketCode);
        if SitooShipment.FINDLAST then;

        exit(SitooShipment."Entry No." + 1);
    end;

    local procedure ValidateShipment(SitooOutboundQueue : Record "Sitoo Outbound Queue") : Boolean;
    var
        PurchaseHeader : Record "Purchase Header";
        TransferHeader : Record "Transfer Header";
        TransferShipmentHeader : Record "Transfer Shipment Header";
        SitooWarehouse : Record "Sitoo Warehouse";
    begin
        if SitooOutboundQueue.Type <> 'SHIPMENT' then
          exit(false);

        case SitooOutboundQueue."Sub Type" of
          // Mottagaren ska vara ett Sitoo Warehouse
          'PURCHASEORDER': begin
            if not PurchaseHeader.GET(PurchaseHeader."Document Type"::Order, SitooOutboundQueue."Primary Key 1") then
              exit(false);
            SitooWarehouse.SETRANGE("Location Code", PurchaseHeader."Location Code");
            if SitooWarehouse.FINDFIRST then
              exit(true)
            else
              exit(false);
          end;
          // Avsändaren ska vara ett Sitoo Warehouse
          'TRANSFERORDER': begin
            if not TransferHeader.GET(SitooOutboundQueue."Primary Key 1") then
              exit(false);
            SitooWarehouse.SETRANGE("Location Code", TransferHeader."Transfer-from Code");
            if SitooWarehouse.FINDFIRST then
              exit(true)
            else
              exit(false);
          end;
          // Avsändaren ska inte vara ett Sitoo Warehouse
          // Mottagaren ska vara ett Sitoo Warehouse
          'TRANSFERSHIPMENT': begin
            if not TransferShipmentHeader.GET(SitooOutboundQueue."Primary Key 1") then
              exit(false);
            SitooWarehouse.SETRANGE("Location Code", TransferShipmentHeader."Transfer-from Code");
            if SitooWarehouse.FINDFIRST then
              exit(false);
            SitooWarehouse.SETRANGE("Location Code", TransferShipmentHeader."Transfer-to Code");
            if SitooWarehouse.FINDFIRST then
              exit(true);
          end;
        end;
    end;
}

