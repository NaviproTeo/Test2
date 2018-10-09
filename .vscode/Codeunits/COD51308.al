codeunit 51308 "Sitoo Warehouse Mgt"
{
    // version Sitoo 3.0


    trigger OnRun();
    var
        Setup : Record "Sitoo Setup";
        NextCheck : DateTime;
    begin

        Setup.SETRANGE(Active, true);
        if Setup.FINDSET then
          repeat
            if Setup."Send Complete Inventory" then begin
              NextCheck := Setup."Last Send Complete Inv" + Setup."Send Complete Inv Interval" * 60000;
              if (CURRENTDATETIME > NextCheck) or (GUIALLOWED) then begin
                EnqueueInventorySync(Setup);
                Setup."Last Send Complete Inv" := CURRENTDATETIME;
                Setup.MODIFY;
                COMMIT;
              end;
            end;

            if Setup."Get Whse. Transactions" then begin
              NextCheck := Setup."Last Get Whse. Transactions" + Setup."Get Whse. Trans. Interval" * 60000;
              if (CURRENTDATETIME > NextCheck) or (GUIALLOWED) then begin
                GetWhseTransactions(Setup);
                Setup."Last Get Whse. Transactions" := CURRENTDATETIME;
                Setup.MODIFY;
                COMMIT;
              end;
            end;

            if Setup."Get Warehouses" then begin
              NextCheck := Setup."Last Get Warehouses" + Setup."Get Warehouses Interval" * 60000;
              if (CURRENTDATETIME > NextCheck) or (GUIALLOWED) then begin
                GetWarehouses(Setup);
                Setup."Last Get Warehouses" := CURRENTDATETIME;
                Setup.MODIFY;
                COMMIT;
              end;
            end;

            if Setup."Get Complete Inventory" then begin
              NextCheck := Setup."Last Get Complete Inv" + Setup."Get Complete Inv Interval" * 60000;
              if (CURRENTDATETIME > NextCheck) or (GUIALLOWED) then begin
                GetTotalInventory(Setup);
                Setup."Last Get Complete Inv" := CURRENTDATETIME;
                Setup.MODIFY;
                COMMIT;
              end;
            end;

            SerializeOutbounds(Setup);
            COMMIT;
          until Setup.NEXT = 0;
    end;

    procedure ProcessInbound(var SitooLogEntry : Record "Sitoo Log Entry");
    begin
        case SitooLogEntry."Sub Type" of
          'TRANSACTIONS': SaveWhseTransactions(SitooLogEntry);
          'LIST': SaveWarehouses(SitooLogEntry);
          'STOCK': SaveWarehouseItems(SitooLogEntry);
        end;
    end;

    procedure ProcessOutbound(var SitooLogEntry : Record "Sitoo Log Entry") : Integer;
    begin
    end;

    procedure SerializeOutbounds(var Setup : Record "Sitoo Setup");
    var
        NextCheck : DateTime;
    begin

        if Setup."Send Inventory" then begin
          NextCheck := Setup."Last Send Inventory" + Setup."Send Inventory Interval" * 60000;
          if (CURRENTDATETIME > NextCheck) or (GUIALLOWED) then begin
            SerializeInventoryBatch(Setup);
            Setup."Last Send Inventory" := CURRENTDATETIME;
            Setup.MODIFY;
          end;
        end;
    end;

    procedure GetWhseTransactions(var Setup : Record "Sitoo Setup");
    var
        Common : Codeunit "Sitoo Common";
        NextTransId : Integer;
        URL : Text;
    begin

        NextTransId := GetNextTransId(Setup."Market Code");

        URL := Setup."Base URL"+ 'sites/' + FORMAT(Setup."Site Id") + '/warehousetransactions.json?warehousetransactionidfrom=' + FORMAT(NextTransId) + '&sort=warehousetransactionid&num=100';

        Common.Download(URL, 'WAREHOUSE', 'TRANSACTIONS', 'GetWhseTransactions', '', Setup."Market Code");
    end;

    procedure SaveWhseTransactions(var LogEntry : Record "Sitoo Log Entry");
    var
        Common : Codeunit "Sitoo Common";
        TransactionId : Integer;
        Counter : Integer;
        XmlDocument : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlDocument";
        XmlTransactionList : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNodeList";
        XmlTransactionElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        ProgressWindow : Dialog;
    begin

        Common.GetResponseXML(LogEntry, XmlDocument);

        XmlTransactionList := XmlDocument.GetElementsByTagName('items');

        if XmlTransactionList.Count > 0 then begin
          Counter := 0;

          if GUIALLOWED then
            ProgressWindow.OPEN('Processing transaction #1#######');

          repeat
            XmlTransactionElement := XmlTransactionList.Item(Counter);

            if GUIALLOWED then
              ProgressWindow.UPDATE(1, FORMAT(Counter));

            SaveWhseTransactionItems(XmlTransactionElement, LogEntry);

            Counter += 1;
          until Counter = XmlTransactionList.Count;

          if GUIALLOWED then
            ProgressWindow.CLOSE;
        end;

        LogEntry.Information := FORMAT(Counter) + ' whse transactions';
        LogEntry.Status := LogEntry.Status::Processed;
        LogEntry.MODIFY;

        if Counter = 0 then
          LogEntry.DELETE;
    end;

    local procedure SaveWhseTransactionItems(var XmlTransactionElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";var SitooLogEntry : Record "Sitoo Log Entry") : Code[20];
    var
        Common : Codeunit "Sitoo Common";
        SitooWhseTransactionItem : Record "Sitoo Whse Transaction Item";
        XmlItemList : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNodeList";
        XmlItemElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        Counter : Integer;
        TransactionId : Integer;
        WarehouseId : Integer;
        TransactionType : Integer;
        Description : Text;
        CreatedDateTime : DateTime;
        SKU : Text;
        Quantity : Decimal;
        Total : Decimal;
        ItemNo : Code[20];
        ColorCode : Code[20];
        SizeCode : Code[20];
        SitooProductMgt : Codeunit "Sitoo Product Mgt";
        ExternalId : Code[20];
        ExternalItemId : Integer;
        ShipmentId : Integer;
        ReasonCode : Code[20];
    begin
        TransactionId := Common.GetIntXML(XmlTransactionElement, 'warehousetransactionid');
        WarehouseId := Common.GetIntXML(XmlTransactionElement, 'warehouseid');
        TransactionType := Common.GetIntXML(XmlTransactionElement, 'transactiontype');
        Description := Common.GetValueXML(XmlTransactionElement, 'description');
        CreatedDateTime := Common.GetDateTimeXML(XmlTransactionElement, 'datecreated');
        ExternalId := Common.GetValueXML(XmlTransactionElement, 'externalid'); // TODO: Väntar på fältet från Sitoo, ska motsvara externalid/dokumentnr på shipment
        ExternalItemId := Common.GetIntXML(XmlTransactionElement, 'externalitemid'); // TODO: Väntar på fältet från Sitoo, ska motsvara radnr/itemid på shipment
        ShipmentId := Common.GetIntXML(XmlTransactionElement, 'shipmentid'); //DOTO: Hittade ett fäålt till //MAJO
        ReasonCode := Common.GetValueXML(XmlTransactionElement, 'reasoncode');
        XmlItemList := XmlTransactionElement.SelectNodes('items');

        if XmlItemList.Count > 0 then begin
          Counter := 0;
          repeat
            XmlItemElement := XmlItemList.Item(Counter);

            SKU := Common.GetValueXML(XmlItemElement, 'sku');
            Quantity := Common.GetDecimalXML(XmlItemElement, 'decimalquantity');
            Total := Common.GetDecimalXML(XmlItemElement, 'decimaltotal');

            SitooProductMgt.SplitSKU(SKU, ItemNo, ColorCode, SizeCode);

            SitooWhseTransactionItem."Market Code" := SitooLogEntry."Market Code";
            SitooWhseTransactionItem."Transaction Id" := TransactionId;
            SitooWhseTransactionItem."Warehouse ID" := WarehouseId;
            SitooWhseTransactionItem."Transaction Type" := TransactionType;
            SitooWhseTransactionItem.Description := Description;
            SitooWhseTransactionItem.DateTime := CreatedDateTime;
            SitooWhseTransactionItem."Item No." := ItemNo;
            SitooWhseTransactionItem."Color Code" := ColorCode;
            SitooWhseTransactionItem."Size Code" := SizeCode;
            SitooWhseTransactionItem.SKU := SKU;
            SitooWhseTransactionItem.Quantity := Quantity;
            SitooWhseTransactionItem.Total := Total;
            SitooWhseTransactionItem."External Id" := ExternalId;
            SitooWhseTransactionItem."External Item Id" := ExternalItemId;
            SitooWhseTransactionItem."shipment id" := ShipmentId;
            SitooWhseTransactionItem.reasoncode := ReasonCode;
            SitooWhseTransactionItem."Log Entry No." := SitooLogEntry."Entry No.";
            if SitooWhseTransactionItem.INSERT then;

            Counter += 1;
          until Counter = XmlItemList.Count;
        end;

        SetLastTransId(TransactionId, SitooLogEntry."Market Code");
    end;

    local procedure GetNextTransId(MarketCode : Code[20]) : Integer;
    var
        SitooSetup : Record "Sitoo Setup";
    begin
        SitooSetup.GET(MarketCode);
        exit(SitooSetup."Last Whse. Transaction Id" + 1);
    end;

    local procedure SetLastTransId(NewTransactionId : Integer;MarketCode : Code[20]);
    var
        SitooSetup : Record "Sitoo Setup";
    begin
        SitooSetup.GET(MarketCode);

        if SitooSetup."Last Whse. Transaction Id" < NewTransactionId then begin
          SitooSetup."Last Whse. Transaction Id" := NewTransactionId;
          SitooSetup.MODIFY;
        end;
    end;

    procedure GetWarehouses(var Setup : Record "Sitoo Setup");
    var
        Common : Codeunit "Sitoo Common";
        URL : Text;
    begin

        URL := Setup."Base URL" + 'sites/' + FORMAT(Setup."Site Id") + '/warehouses.json?num=100';

        Common.Download(URL, 'WAREHOUSE', 'LIST', 'GetWarehouses', '', Setup."Market Code");
    end;

    procedure SaveWarehouses(var LogEntry : Record "Sitoo Log Entry");
    var
        Common : Codeunit "Sitoo Common";
        TransactionId : Integer;
        Counter : Integer;
        XmlDocument : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlDocument";
        XmlWarehouseList : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNodeList";
        XmlWarehouseElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        ProgressWindow : Dialog;
        Name : Text;
        Updated : Integer;
    begin

        Common.GetResponseXML(LogEntry, XmlDocument);

        XmlWarehouseList:= XmlDocument.GetElementsByTagName('items');

        if XmlWarehouseList.Count > 0 then begin
          Counter := 0;

          if GUIALLOWED then
            ProgressWindow.OPEN('Processing Warehouse #1#######');

          repeat
            XmlWarehouseElement := XmlWarehouseList.Item(Counter);

            if GUIALLOWED then
              ProgressWindow.UPDATE(1, FORMAT(Counter));

            if SaveWarehouse(XmlWarehouseElement, LogEntry) then
              Updated += 1;

            Counter += 1;
          until Counter = XmlWarehouseList.Count;

          if GUIALLOWED then
            ProgressWindow.CLOSE;
        end;

        LogEntry.Information := FORMAT(Updated) + ' updated warehouses';
        LogEntry.Status := LogEntry.Status::Processed;
        LogEntry.MODIFY;

        if Updated = 0 then
          LogEntry.DELETE;
    end;

    local procedure SaveWarehouse(var XmlWarehouseElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";var LogEntry : Record "Sitoo Log Entry") : Boolean;
    var
        Common : Codeunit "Sitoo Common";
        SitooWarehouse : Record "Sitoo Warehouse";
        Location : Record Location;
        WarehouseId : Integer;
        Modified : Boolean;
        ExternalId : Code[10];
        CurrencyCode : Code[10];
    begin
        WarehouseId := Common.GetIntXML(XmlWarehouseElement, 'warehouseid');
        ExternalId := Common.GetValueXML(XmlWarehouseElement, 'externalid');
        CurrencyCode := Common.GetValueXML(XmlWarehouseElement, 'currencycode');

        if WarehouseId = 0 then
          exit(false);

        if not SitooWarehouse.GET(WarehouseId, LogEntry."Market Code") then begin
          SitooWarehouse.INIT;
          SitooWarehouse."Warehouse Id" := WarehouseId;
          SitooWarehouse."Market Code" := LogEntry."Market Code";
          SitooWarehouse."External Id" := ExternalId;
          SitooWarehouse.INSERT;
          Modified := true;
        end;

        if ExternalId <> '' then begin
          if SitooWarehouse."External Id" <> ExternalId then begin
            SitooWarehouse."External Id" := ExternalId;
            SitooWarehouse.MODIFY;
            Modified := true;
          end;

          if Location.GET(ExternalId) then begin
            if SitooWarehouse."Location Code" <> Location.Code then begin
              SitooWarehouse."Location Code" := Location.Code;
              SitooWarehouse.MODIFY;
              Modified := true;
            end;
          end;
        end;

        if CurrencyCode <> SitooWarehouse."Currency Code" then begin
          SitooWarehouse."Currency Code" := CurrencyCode;
          SitooWarehouse.MODIFY;
          Modified := true;
        end;

        exit(Modified);
    end;

    local procedure SerializeInventoryBatch(var Setup : Record "Sitoo Setup");
    var
        SitooOutboundQueue : Record "Sitoo Outbound Queue";
        SitooWarehouse : Record "Sitoo Warehouse";
        BatchId : Integer;
        CommitBatch : Boolean;
        SitooOutboundQueueTEMP : Record "Sitoo Outbound Queue" temporary;
        Counter : Integer;
        LogEntryNo : Integer;
        Item : Record Item;
        SKU : Text;
        ItemNo : Code[20];
        VertComponent : Code[10];
        HorzComponent : Code[10];
        SitooProductMgt : Codeunit "Sitoo Product Mgt";
    begin
        SitooWarehouse.SETRANGE("Market Code", Setup."Market Code");
        if SitooWarehouse.FINDSET then begin
          repeat
            SitooOutboundQueue.RESET;
            SitooOutboundQueue.SETCURRENTKEY(DateTime);
            SitooOutboundQueue.SETRANGE("Market Code", Setup."Market Code");
            SitooOutboundQueue.SETRANGE(Type, 'WAREHOUSE');
            SitooOutboundQueue.SETRANGE("Sub Type", 'STOCK');
            SitooOutboundQueue.SETRANGE("Primary Key 2", SitooWarehouse."Location Code");
            if SitooOutboundQueue.FINDSET then begin
              Counter := 0;
              repeat
                SitooProductMgt.SplitSKU(SitooOutboundQueue."Primary Key 1", ItemNo, VertComponent, HorzComponent);
                if Item.GET(ItemNo) then begin
                  SitooOutboundQueueTEMP.INIT;
                  SitooOutboundQueueTEMP.COPY(SitooOutboundQueue);
                  SitooOutboundQueueTEMP.INSERT;
                  Counter += 1;
                end else
                  SitooOutboundQueue.DELETE;
              until (SitooOutboundQueue.NEXT = 0) or (Counter = 50);

              if Counter = 0 then
                exit;

              BatchId := CreateWhseBatch(SitooWarehouse."Warehouse Id", 50, SitooWarehouse."Location Code", Setup."Market Code");

              if BatchId = 0 then
                BatchId := GetOpenBatchId(SitooWarehouse."Warehouse Id", 50, SitooWarehouse."Location Code", Setup."Market Code");

              if BatchId <> 0 then begin
                CommitBatch := AddWhseBatchItems(SitooWarehouse."Warehouse Id", SitooWarehouse."Location Code", BatchId, Setup."Market Code", SitooOutboundQueueTEMP);

                if CommitBatch then begin
                  LogEntryNo := CommitWhseBatch(SitooWarehouse."Warehouse Id", SitooWarehouse."Location Code", BatchId, Setup."Market Code");
                  if LogEntryNo > 0 then begin
                    SitooOutboundQueue.RESET;
                    SitooOutboundQueueTEMP.RESET;
                    SitooOutboundQueueTEMP.FINDSET;
                    repeat
                      if SitooOutboundQueue.GET(SitooOutboundQueueTEMP.GUID) then
                        SitooOutboundQueue.DELETE;
                    until SitooOutboundQueueTEMP.NEXT = 0;

                    SetWhseStockItemLogEntry(BatchId, LogEntryNo, Setup."Market Code");
                  end;
                end;
              end;
            end;
          until SitooWarehouse.NEXT = 0;
        end;
    end;

    local procedure CreateWhseBatch(WarehouseId : Integer;Type : Integer;LocationCode : Code[10];MarketCode : Code[20]) : Integer;
    var
        JsonMgt : Codeunit "Sitoo Json Mgt";
        Common : Codeunit "Sitoo Common";
        String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
        LogEntry : Record "Sitoo Log Entry";
        EntryNo : Integer;
        Setup : Record "Sitoo Setup";
        URL : Text;
    begin
        Setup.GET(MarketCode);

        JsonMgt.StartJSon;
        JsonMgt.AddIntProperty('transactiontype', Type);
        JsonMgt.AddToJSon('comment', LocationCode);
        JsonMgt.EndJSon;

        String := JsonMgt.GetJSon;

        EntryNo := Common.AddOutboundLogEntry(String, 'WAREHOUSE', 'BATCH', 'CreateWhseBatch', LocationCode, 'POST', Setup."Market Code");

        LogEntry.GET(EntryNo);

        URL := Setup."Base URL" + 'sites/' + FORMAT(Setup."Site Id") + '/warehouses/' + FORMAT(WarehouseId) + '/warehousebatches.json';

        EntryNo := Common.UploadLogEntry(LogEntry, 'SendWhseBatch', false, URL);

        LogEntry.Status := LogEntry.Status::Processed;
        LogEntry.MODIFY;

        if EntryNo > 0 then
          exit(GetBatchId(LogEntry));

        exit(GetOpenBatchId(WarehouseId, Type, LocationCode, MarketCode));
    end;

    local procedure AddWhseBatchItems(WarehouseId : Integer;LocationCode : Code[10];BatchId : Integer;MarketCode : Code[20];var SitooOutboundQueueTEMP : Record "Sitoo Outbound Queue" temporary) : Boolean;
    var
        Item : Record Item;
        JsonMgt : Codeunit "Sitoo Json Mgt";
        Common : Codeunit "Sitoo Common";
        SitooProductMgt : Codeunit "Sitoo Product Mgt";
        Events : Codeunit "Sitoo Events";
        String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
        LogEntry : Record "Sitoo Log Entry";
        EntryNo : Integer;
        Setup : Record "Sitoo Setup";
        Quantity : Text;
        Counter : Integer;
        SKU : Text;
        ItemNo : Code[20];
        VertComponent : Code[20];
        HorzComponent : Code[20];
        URL : Text;
    begin
        Setup.GET(MarketCode);

        SitooOutboundQueueTEMP.SETCURRENTKEY(DateTime);
        SitooOutboundQueueTEMP.SETRANGE("Market Code", MarketCode);
        SitooOutboundQueueTEMP.SETRANGE(Type, 'WAREHOUSE');
        SitooOutboundQueueTEMP.SETRANGE("Sub Type", 'STOCK');
        SitooOutboundQueueTEMP.SETRANGE("Primary Key 2", LocationCode);
        if SitooOutboundQueueTEMP.FINDSET(true, true) then begin
          JsonMgt.StartJSonArray;
          repeat
            SKU := SitooOutboundQueueTEMP."Primary Key 1";
            SitooProductMgt.SplitSKU(SKU, ItemNo, VertComponent, HorzComponent);
            if Item.GET(ItemNo) then begin
              JsonMgt.BeginJsonObject;

              Item.RESET;
              Item.SETFILTER("Location Filter", LocationCode);

              // To add extra filter on Item
              Events.SitooCU51308_OnBeforeEndAddWhseBatchItems(SitooOutboundQueueTEMP, JsonMgt, Item);

              Item.CALCFIELDS(Inventory);

              Quantity := FORMAT(Item.Inventory, 0, '<Integer><Decimals,4>');
              Quantity := CONVERTSTR(Quantity, ',', '.');

              JsonMgt.AddToJSon('sku', SKU);
              JsonMgt.AddToJSon('decimalquantity', Quantity);
              JsonMgt.EndJsonObject;

              AddWhseStockItem(WarehouseId, LocationCode, BatchId, SKU, Item.Inventory, MarketCode);

              Counter += 1;
            end;

          until (SitooOutboundQueueTEMP.NEXT = 0);

          JsonMgt.EndJSonArray;

          String := JsonMgt.GetJSon;

          if Counter = 0 then
            exit(false);

          EntryNo := Common.AddOutboundLogEntry(String, 'WAREHOUSE', 'BATCH', 'AddToWsheBatch', LocationCode, 'PUT', MarketCode);

          LogEntry.GET(EntryNo);
          LogEntry.Information := FORMAT(Counter) + ' items';
          LogEntry.MODIFY;

          URL := Setup."Base URL" + 'sites/' + FORMAT(Setup."Site Id") + '/warehouses/' + FORMAT(WarehouseId) + '/warehousebatches/' + FORMAT(BatchId) + '/warehousebatchitems.json';

          EntryNo := Common.UploadLogEntry(LogEntry, 'SendWhseBatch', false, URL);

          if EntryNo < 0 then
            exit(false);

          LogEntry.Status := LogEntry.Status::Processed;
          LogEntry.MODIFY;

          exit(true);
        end;
    end;

    local procedure CommitWhseBatch(WarehouseId : Integer;DocumentNo : Code[20];BatchId : Integer;MarketCode : Code[20]) : Integer;
    var
        JsonMgt : Codeunit "Sitoo Json Mgt";
        Common : Codeunit "Sitoo Common";
        String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
        LogEntry : Record "Sitoo Log Entry";
        EntryNo : Integer;
        Setup : Record "Sitoo Setup";
        URL : Text;
    begin
        Setup.GET(MarketCode);

        JsonMgt.StartJSon;
        JsonMgt.AddIntProperty('warehousebatchstate', 20);
        JsonMgt.EndJSon;

        String := JsonMgt.GetJSon;

        EntryNo := Common.AddOutboundLogEntry(String, 'WAREHOUSE', 'BATCH', 'CommitWhseBatch', DocumentNo, 'PUT', Setup."Market Code");

        LogEntry.GET(EntryNo);

        URL := Setup."Base URL" + 'sites/' + FORMAT(Setup."Site Id") + '/warehouses/' + FORMAT(WarehouseId) + '/warehousebatches/' + FORMAT(BatchId) + '.json';

        EntryNo := Common.UploadLogEntry(LogEntry, 'CommitWhseBatch', false, URL);

        if LogEntry.GET(EntryNo) then begin
          LogEntry.Status := LogEntry.Status::Processed;
          LogEntry.MODIFY;
          COMMIT;
          exit(EntryNo);
        end;
    end;

    local procedure GetOpenBatchId(WarehouseId : Integer;Type : Integer;LocationCode : Code[10];MarketCode : Code[20]) : Integer;
    var
        Common : Codeunit "Sitoo Common";
        String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
        LogEntry : Record "Sitoo Log Entry";
        EntryNo : Integer;
        Setup : Record "Sitoo Setup";
        URL : Text;
    begin
        Setup.GET(MarketCode);

        URL := Setup."Base URL" + 'sites/' + FORMAT(Setup."Site Id") +  '/warehouses/' + FORMAT(WarehouseId) + '/warehousebatches.json?warehousebatchstate=10&transactiontype=' + FORMAT(Type);

        EntryNo := Common.Download(URL, 'WAREHOUSE', 'BATCH', 'GetWhseBatchId', LocationCode, MarketCode);

        LogEntry.GET(EntryNo);

        LogEntry.Status := LogEntry.Status::Processed;
        LogEntry.MODIFY;

        exit(GetBatchId(LogEntry));
    end;

    local procedure GetBatchId(var SitooLogEntry : Record "Sitoo Log Entry") : Integer;
    var
        Common : Codeunit "Sitoo Common";
        XmlDocument : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlDocument";
        XmlBatchElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        XmlElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        BatchId : Integer;
    begin

        Common.GetResponseXML(SitooLogEntry, XmlDocument);

        XmlElement := XmlDocument.DocumentElement.Item('root');
        XmlBatchElement := XmlElement.SelectSingleNode('items');

        if not ISNULL(XmlBatchElement) then
          BatchId := Common.GetIntXML(XmlBatchElement, 'warehousebatchid')
        else
          EVALUATE(BatchId, XmlElement.InnerXml);

        exit(BatchId);
    end;

    local procedure AddWhseStockItem(WarehouseId : Integer;LocationCode : Code[10];BatchId : Integer;SKU : Text;Quantity : Decimal;MarketCode : Code[20]);
    var
        SitooWhseTransactionItem : Record "Sitoo Whse Transaction Item";
        EntryNo : Integer;
        SitooProductMgt : Codeunit "Sitoo Product Mgt";
        ItemNo : Code[20];
        ColorCode : Code[20];
        SizeCode : Code[20];
    begin
        SitooProductMgt.SplitSKU(SKU, ItemNo, ColorCode, SizeCode);

        SitooWhseTransactionItem."Location Code" := LocationCode;
        SitooWhseTransactionItem.Direction := SitooWhseTransactionItem.Direction::Outbound;
        SitooWhseTransactionItem.DateTime := CURRENTDATETIME;
        SitooWhseTransactionItem.Type := 'STOCK';
        SitooWhseTransactionItem."Warehouse ID" := WarehouseId;
        SitooWhseTransactionItem."Market Code" := MarketCode;
        SitooWhseTransactionItem."Item No." := ItemNo;
        SitooWhseTransactionItem.SKU := SKU;
        SitooWhseTransactionItem."Transaction Id" := BatchId;
        SitooWhseTransactionItem."Color Code" := ColorCode;
        SitooWhseTransactionItem."Size Code":= SizeCode;
        SitooWhseTransactionItem.Quantity := Quantity;
        SitooWhseTransactionItem.Total := Quantity;
        SitooWhseTransactionItem.INSERT;
    end;

    local procedure SetWhseStockItemLogEntry(BatchId : Integer;LogEntryNo : Integer;MarketCode : Code[20]);
    var
        SitooWhseTransactionItem : Record "Sitoo Whse Transaction Item";
    begin
        SitooWhseTransactionItem.SETRANGE("Market Code", MarketCode);
        SitooWhseTransactionItem.SETRANGE("Transaction Id", BatchId);
        SitooWhseTransactionItem.SETRANGE(Type, 'STOCK');
        if SitooWhseTransactionItem.FINDSET then
          SitooWhseTransactionItem.MODIFYALL("Log Entry No.", LogEntryNo);
    end;

    procedure GetTotalInventory(var Setup : Record "Sitoo Setup");
    var
        SitooWarehouse : Record "Sitoo Warehouse";
    begin
        SitooWarehouse.SETRANGE("Market Code", Setup."Market Code");
        SitooWarehouse.SETFILTER("Location Code", '<>%1', '');
        SitooWarehouse.SETRANGE("Inventory Owned By", SitooWarehouse."Inventory Owned By"::Sitoo);
        if SitooWarehouse.FINDSET then
          repeat
            GetWarehouseInventory(SitooWarehouse);
          until SitooWarehouse.NEXT = 0;
    end;

    procedure GetWarehouseInventory(var Warehouse : Record "Sitoo Warehouse");
    var
        Index : Integer;
        Num : Integer;
        Total : Integer;
    begin
        Index := 0;
        Num := 1000;

        while Index <= Total do begin
          Total := GetWarehouseItems(Warehouse."Warehouse Id", Index, Total, Warehouse."Market Code");
          Index += Num;
        end;
    end;

    local procedure GetWarehouseItems(WarehouseId : Integer;Index : Integer;Num : Integer;MarketCode : Code[20]) : Integer;
    var
        Common : Codeunit "Sitoo Common";
        Setup : Record "Sitoo Setup";
        URL : Text;
        LogEntry : Record "Sitoo Log Entry";
        EntryNo : Integer;
    begin
        Setup.GET(MarketCode);

        URL := Setup."Base URL" + 'sites/' + FORMAT(Setup."Site Id") + '/warehouses/' + FORMAT(WarehouseId)
          + '/warehouseitems.json?start=' + FORMAT(Index) + '&num=' + FORMAT(Num) + '&fields=warehouseitemid,sku,decimaltotal';

        EntryNo := Common.Download(URL, 'WAREHOUSE', 'STOCK', 'GetWarehouseItems', FORMAT(WarehouseId), Setup."Market Code");

        LogEntry.GET(EntryNo);

        exit(Common.GetTotalCount(LogEntry));
    end;

    local procedure SaveWarehouseItems(var LogEntry : Record "Sitoo Log Entry");
    var
        XmlDocument : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlDocument";
        XmlItemList : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNodeList";
        XmlItemElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        Common : Codeunit "Sitoo Common";
        WarehouseId : Integer;
        Counter : Integer;
        ProgressWindow : Dialog;
    begin
        EVALUATE(WarehouseId, LogEntry."Document No.");

        Common.GetResponseXML(LogEntry, XmlDocument);

        XmlItemList := XmlDocument.GetElementsByTagName('items');

        if XmlItemList.Count > 0 then begin
          Counter := 0;

          if GUIALLOWED then
            ProgressWindow.OPEN('Processing item #1#######');

          repeat
            XmlItemElement := XmlItemList.Item(Counter);

            if GUIALLOWED then
              ProgressWindow.UPDATE(1, FORMAT(Counter));

            SaveWarehouseItem(WarehouseId, XmlItemElement, LogEntry);

            Counter += 1;
          until Counter = XmlItemList.Count;

          if GUIALLOWED then
            ProgressWindow.CLOSE;
        end;

        LogEntry.Information := FORMAT(Counter) + ' Warehouse Items';
        LogEntry.Status := LogEntry.Status::Processed;
        LogEntry.MODIFY;

        if Counter = 0 then
          LogEntry.DELETE;
    end;

    local procedure SaveWarehouseItem(WarehouseId : Integer;var XmlItemElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";var LogEntry : Record "Sitoo Log Entry") : Integer;
    var
        Common : Codeunit "Sitoo Common";
        SitooWarehouseItem : Record "Sitoo Warehouse Item";
        ItemId : Integer;
        SKU : Text;
        DecimalAvailable : Decimal;
        DecimalTotal : Decimal;
    begin

        ItemId := Common.GetIntXML(XmlItemElement, 'warehouseitemid');
        SKU := Common.GetValueXML(XmlItemElement, 'sku');

        if not SitooWarehouseItem.GET(ItemId, WarehouseId, LogEntry."Market Code") then begin
          SitooWarehouseItem.INIT;
          SitooWarehouseItem.warehouseitemid := ItemId;
          SitooWarehouseItem."Warehouse Id" := WarehouseId;
          SitooWarehouseItem."Market Code" := LogEntry."Market Code";
          SitooWarehouseItem.sku := SKU;
          SitooWarehouseItem.INSERT;
        end;

        SitooWarehouseItem.binlocation := Common.GetValueXML(XmlItemElement, 'binlocation');
        SitooWarehouseItem.decimalthreshold := Common.GetDecimalXML(XmlItemElement, 'decimalthreshold');
        SitooWarehouseItem.decimaltotal := Common.GetDecimalXML(XmlItemElement, 'decimaltotal');
        SitooWarehouseItem.moneytotal := Common.GetDecimalXML(XmlItemElement, 'moneytotal');
        SitooWarehouseItem.datelastmodified := Common.GetDateTimeXML(XmlItemElement, 'datelastmodified');
        SitooWarehouseItem.datelaststocktaking := Common.GetDateTimeXML(XmlItemElement, 'datelaststocktaking');
        SitooWarehouseItem.decimalreserved := Common.GetDecimalXML(XmlItemElement, 'decimalreserved');
        SitooWarehouseItem.decimalavailable := Common.GetDecimalXML(XmlItemElement, 'decimalavailable');
        SitooWarehouseItem.MODIFY;
    end;

    local procedure EnqueueInventorySync(var Setup : Record "Sitoo Setup");
    var
        SitooWarehouse : Record "Sitoo Warehouse";
        Common : Codeunit "Sitoo Common";
        Item : Record Item;
        SitooProductId : Record "Sitoo Product";
        LastCompleteDate : Date;
    begin

        LastCompleteDate := DT2DATE(Setup."Last Send Complete Inv");

        if LastCompleteDate = TODAY then
          exit;

        SitooWarehouse.SETRANGE("Market Code", Setup."Market Code");
        SitooWarehouse.SETFILTER("Warehouse Id", '>0');
        if SitooWarehouse.FINDSET then begin
          repeat
            if Item.FINDSET then begin
              repeat
                SitooProductId.SETRANGE("Market Code", Setup."Market Code");
                SitooProductId.SETRANGE("No.", Item."No.");
                if SitooProductId.FINDFIRST then
                  Common.AddQueueMessage('WAREHOUSE', 'STOCK', '', Item."No.", SitooWarehouse."Location Code", SitooWarehouse."Market Code");
              until Item.NEXT = 0;
            end;
          until SitooWarehouse.NEXT = 0;
        end;

        Setup."Last Send Complete Inv" := CREATEDATETIME(TODAY, TIME);
        Setup.MODIFY;
    end;
}

