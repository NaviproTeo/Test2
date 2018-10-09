codeunit 51307 "Sitoo Product Mgt"
{
    // version Sitoo 3.0

    // 
    // 1. Nya produkter skapas i:
    //    SerializeOutbounds -> SerializeCreateBaseProductList -> SerializeAddToBaseProductList
    //    Nya produkter skapas som inaktiva i Sitoo
    // 
    // 2. Får tillbaka Product Id som läggs läggs in i Tabellen Sitoo Product Id via ProcessProductList, event lyssnar och köar
    //    upp produkt eller variant: SerializeProduct resp SerializeVariant
    // 
    // 3. Hade produkten varianter hämtas deras produkt-id via DownloadVariantIds som sen hanteras i ProcessVariantIdList


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
          'LIST': ProcessProductList(SitooLogEntry);
          'VARIANTS': ProcessVariantIdList(SitooLogEntry);
          'DOWNLOADLIST': ProcessDownloadList(SitooLogEntry);
        end;
    end;

    procedure ProcessOutbound(var SitooLogEntry : Record "Sitoo Log Entry") : Integer;
    var
        Status : Integer;
    begin
        case SitooLogEntry."Sub Type" of
          'LIST': Status := SendProducts(SitooLogEntry);
          'ITEM': Status := SendProductUpdate(SitooLogEntry);
          'VARIANT': Status := SendVariant(SitooLogEntry);
          'IMAGE': Status := SendProductImage(SitooLogEntry);
        end;

        exit(Status);
    end;

    procedure SerializeOutbounds(var Setup : Record "Sitoo Setup");
    var
        Events : Codeunit "Sitoo Events";
        NextCheck : DateTime;
    begin

        if Setup."Send Items" then begin
          NextCheck := Setup."Last Send Items" + Setup."Send Items Interval" * 60000;
          if (CURRENTDATETIME > NextCheck) or (GUIALLOWED) then begin
            // New products
            SerializeCreateBaseProductList(Setup);

            // Product updates
            SerializeProducts(Setup);

            SerializeDeleteProducts(Setup);

            if Setup."Send Product Image" then
              SerializeProductImages(Setup);

            Setup."Last Send Items" := CURRENTDATETIME;
            Setup.MODIFY;

            Events.SitooCU51307_OnAfterSerializeOutbounds(Setup);
          end;
        end;
    end;

    local procedure SerializeProducts(var Setup : Record "Sitoo Setup");
    var
        SitooOutboundQueue : Record "Sitoo Outbound Queue";
        String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
        Common : Codeunit "Sitoo Common";
        SitooProductId : Record "Sitoo Product";
        SKU : Text;
        OK : Boolean;
    begin
        SitooOutboundQueue.SETRANGE("Market Code", Setup."Market Code");
        SitooOutboundQueue.SETRANGE(Type, 'PRODUCT');
        SitooOutboundQueue.SETRANGE("Sub Type", 'ITEM');
        SitooOutboundQueue.SETFILTER(Action, 'PUT');
        SitooOutboundQueue.SETFILTER("Retry Count", '<%1', Setup."Outbound Queue Retry Count");
        if SitooOutboundQueue.FINDSET(true, true) then begin
          repeat
            SitooProductId.SETRANGE("Market Code", SitooOutboundQueue."Market Code");
            SitooProductId.SETRANGE("No.", SitooOutboundQueue."Primary Key 1");
            if SitooOutboundQueue."Primary Key 2" <> '' then
              SitooProductId.SETRANGE("Color Code", SitooOutboundQueue."Primary Key 2");
            if SitooProductId.FINDSET then begin
              repeat
                OK := SerializeProduct(SitooProductId, SKU, String);
                if OK then
                  Common.AddOutboundLogEntry(String, 'PRODUCT', 'ITEM', 'SerializeProduct', SKU, SitooOutboundQueue.Action, Setup."Market Code");
              until (SitooProductId.NEXT = 0) or not OK;
            end else
              Common.AddQueueMessage('PRODUCT', 'ITEM', 'POST', SitooOutboundQueue."Primary Key 1", '', Setup."Market Code");

            if OK then
              SitooOutboundQueue.DELETE
            else
              Common.AddQueueError(SitooOutboundQueue);

            COMMIT;
          until SitooOutboundQueue.NEXT = 0;
        end;
    end;

    local procedure SerializeDeleteProducts(var Setup : Record "Sitoo Setup");
    var
        SitooOutboundQueue : Record "Sitoo Outbound Queue";
        String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
        Common : Codeunit "Sitoo Common";
        SitooProductId : Record "Sitoo Product";
        SKU : Text;
        OK : Boolean;
    begin
        SitooOutboundQueue.SETRANGE("Market Code", Setup."Market Code");
        SitooOutboundQueue.SETRANGE(Type, 'PRODUCT');
        SitooOutboundQueue.SETRANGE("Sub Type", 'ITEM');
        SitooOutboundQueue.SETFILTER(Action, 'DELETE');
        if SitooOutboundQueue.FINDSET(true, true) then begin
          repeat
            SitooProductId.SETRANGE("Market Code", Setup."Market Code");
            SitooProductId.SETRANGE("No.", SitooOutboundQueue."Primary Key 1");
            if SitooOutboundQueue."Primary Key 2" <> '' then
              SitooProductId.SETRANGE("Color Code", SitooOutboundQueue."Primary Key 2");
            if SitooProductId.FINDFIRST then begin

              SerializeDeleteProduct(SitooProductId, SKU, String);
              Common.AddOutboundLogEntry(String, 'PRODUCT', 'ITEM', 'SerializeDeleteProduct', SKU, 'DELETE', Setup."Market Code");
            end;
            SitooOutboundQueue.DELETE;
            COMMIT;
          until SitooOutboundQueue.NEXT = 0;
        end;
    end;

    local procedure SerializeCreateBaseProductList(var Setup : Record "Sitoo Setup");
    var
        Common : Codeunit "Sitoo Common";
        String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
        SitooOutboundQueue : Record "Sitoo Outbound Queue";
        "Count" : Integer;
        JsonMgt : Codeunit "Sitoo Json Mgt";
        QueueCount : Integer;
    begin
        SitooOutboundQueue.SETRANGE("Market Code", Setup."Market Code");
        SitooOutboundQueue.SETRANGE(Type, 'PRODUCT');
        SitooOutboundQueue.SETRANGE("Sub Type", 'ITEM');
        SitooOutboundQueue.SETRANGE(Action, 'POST');
        SitooOutboundQueue.SETFILTER("Retry Count", '<%1', Setup."Outbound Queue Retry Count");
        if SitooOutboundQueue.FINDSET(true, true) then begin
          QueueCount := SitooOutboundQueue.COUNT;
          Count := 0;

          JsonMgt.StartJSonArray;

          repeat
            if SerializeAddToBaseProductList(SitooOutboundQueue, JsonMgt) then begin
              Count += 1;
              SitooOutboundQueue.DELETE;
            end else
              Common.AddQueueError(SitooOutboundQueue);
          until ((SitooOutboundQueue.NEXT = 0) or (Count = 250));

          JsonMgt.EndJSonArray;
          String := JsonMgt.GetJSon;

          if Count > 0 then
            Common.AddOutboundLogEntry(String, 'PRODUCT', 'LIST', 'SerializeProducts', '', 'POST', Setup."Market Code");

          if Count < QueueCount then
            SerializeCreateBaseProductList(Setup);
        end;
    end;

    [TryFunction]
    local procedure SerializeAddToBaseProductList(var SitooOutboundQueue : Record "Sitoo Outbound Queue";var JsonMgt : Codeunit "Sitoo Json Mgt");
    var
        Common : Codeunit "Sitoo Common";
        Events : Codeunit "Sitoo Events";
        String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
        SitooVATProductGroup : Record "Sitoo VAT Product Group";
        SitooProductCategory : Record "Sitoo Product Category";
        ItemCrossReference : Record "Item Cross Reference";
        "Count" : Integer;
        Item : Record Item;
        SitooProductId : Record "Sitoo Product";
        Handled : Boolean;
        SKU : Text;
        POSActive : Boolean;
    begin
        if not ValidateItem(SitooOutboundQueue."Primary Key 1", SitooOutboundQueue."Market Code", POSActive) then
          exit;

        Events.SitooCU51307_OnBeforeSerializeAddToBaseProductList(SitooOutboundQueue, JsonMgt, Handled);
        if Handled then
          exit;

        if Item.GET(SitooOutboundQueue."Primary Key 1") then begin
          SitooProductId.RESET;
          SitooProductId.SETRANGE("Market Code", SitooOutboundQueue."Market Code");
          SitooProductId.SETRANGE("No.", Item."No.");
          if SitooProductId.FINDFIRST then
            ERROR('Product %1 already exists, check Sitoo Product Id %2', Item."No.", SitooProductId."Product Id");

          SKU := Item."No.";
          SKU := CONVERTSTR(SKU, ' ', '+');

          JsonMgt.BeginJsonObject;
          JsonMgt.AddToJSon('sku', SKU);
          JsonMgt.AddToJSon('title', GetItemDescription(Item."No.", '', '', SitooOutboundQueue."Market Code"));
          JsonMgt.AddBoolProperty('active', false);
          JsonMgt.AddBoolProperty('activepos', false);
          SitooVATProductGroup.SETRANGE("Market Code", SitooOutboundQueue."Market Code");
          SitooVATProductGroup.SETRANGE("VAT Prod Posting Group", Item."VAT Prod. Posting Group");
          if SitooVATProductGroup.FINDFIRST then
            JsonMgt.AddIntProperty('vatid', SitooVATProductGroup."VAT Id");

          SitooProductCategory.SETRANGE("Market Code", SitooOutboundQueue."Market Code");
          SitooProductCategory.SETRANGE("Item Category", Item."Item Category Code");
          SitooProductCategory.SETRANGE("Product Group", Item."Product Group Code");
          if SitooProductCategory.FINDFIRST then
            JsonMgt.AddIntProperty('defaultcategoryid', SitooProductCategory."Category Id");

          Events.SitooCU51307_OnAfterSerializeAddToBaseProductList(SitooOutboundQueue, JsonMgt, Handled);

          JsonMgt.EndJsonObject;
        end;
    end;

    [TryFunction]
    local procedure SerializeProduct(var SitooProductId : Record "Sitoo Product";var SKU : Text;var String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String");
    var
        Events : Codeunit "Sitoo Events";
        JsonMgt : Codeunit "Sitoo Json Mgt";
        Item : Record Item;
        Common : Codeunit "Sitoo Common";
        SitooVATProductGroup : Record "Sitoo VAT Product Group";
        SitooProductCategory : Record "Sitoo Product Category";
        ItemCrossReference : Record "Item Cross Reference";
        ItemVariant : Record "Item Variant";
        IsVariant : Boolean;
        IsParent : Boolean;
        BaseSKU : Text;
        Title : Text;
        BarCode : Text;
        Handled : Boolean;
        POSActive : Boolean;
    begin
        if not ValidateItem(SitooProductId."No.", SitooProductId."Market Code", POSActive) then
          exit;

        Item.GET(SitooProductId."No.");

        if (SitooProductId."Color Code" <> '') and (SitooProductId."Size Code" <> '') then
          IsVariant := true;

        if SitooProductId."Product Id" = SitooProductId."Parent Variant Id" then
          IsParent := true;

        JsonMgt.StartJSon;
        Events.SitooCU51307_OnBeforeSerializeProduct(SitooProductId, SKU, IsParent, IsVariant, JsonMgt, Handled);
        if not Handled then begin
          Title := GetItemDescription(Item."No.", '', '', SitooProductId."Market Code");
          SKU := SitooProductId.SKU;

          JsonMgt.AddToJSon('title', Title);
          JsonMgt.AddToJSon('sku', SKU);
        end;

        JsonMgt.AddToJSon('moneypriceorg', FORMAT(GetUnitListPrice(SKU), 0, '<Precision,2:2><Standard Format,2>'));
        JsonMgt.AddToJSon('moneyprice', FORMAT(GetUnitPriceExclVAT(SKU, SitooProductId."Market Code"), 0, '<Precision,2:2><Standard Format,2>'));
        JsonMgt.AddToJSon('moneypricein', FORMAT(Item."Unit Cost", 0, '<Precision,2:2><Standard Format,2>'));
        JsonMgt.AddToJSon('moneyofferprice', FORMAT(0.0, 0, '<Precision,2:2><Standard Format,2>'));

        if IsParent then begin
          Handled := false;
          Events.SitooCU51307_OnBeforeProductCustomFields(SitooProductId, JsonMgt, Handled);
          if not Handled then
            JsonMgt.AddToJSon('descriptionshort', GetShortDescription(SitooProductId));

          SitooProductCategory.SETRANGE("Market Code", SitooProductId."Market Code");
          SitooProductCategory.SETRANGE("Item Category", Item."Item Category Code");
          SitooProductCategory.SETRANGE("Product Group", Item."Product Group Code");
          if SitooProductCategory.FINDFIRST then
            JsonMgt.AddIntProperty('defaultcategoryid', SitooProductCategory."Category Id");
        end;

        if not IsVariant then begin
          JsonMgt.AddBoolProperty('active', POSActive);
          JsonMgt.AddBoolProperty('activepos', POSActive);

          SitooVATProductGroup.SETRANGE("Market Code", SitooProductId."Market Code");
          SitooVATProductGroup.SETRANGE("VAT Prod Posting Group", Item."VAT Prod. Posting Group");
          if SitooVATProductGroup.FINDFIRST then
            JsonMgt.AddIntProperty('vatid', SitooVATProductGroup."VAT Id");
        end;

        BarCode := GetBarcode(SitooProductId);

        if CheckBarcode(BarCode) then
          JsonMgt.AddToJSon('barcode', BarCode);

        JsonMgt.AddToJSon('deliverystatus', GetNextDeliveryDate(Item));

        JsonMgt.EndJSon;

        String := JsonMgt.GetJSon;
    end;

    local procedure SerializeDeleteProduct(var SitooProductId : Record "Sitoo Product";var SKU : Text;var String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String");
    var
        SitooOutboundQueue : Record "Sitoo Outbound Queue";
        JsonMgt : Codeunit "Sitoo Json Mgt";
        Item : Record Item;
        Common : Codeunit "Sitoo Common";
        SitooVATProductGroup : Record "Sitoo VAT Product Group";
        SitooProductCategory : Record "Sitoo Product Category";
        ItemCrossReference : Record "Item Cross Reference";
        ItemVariant : Record "Item Variant";
        OfferingPrice : Decimal;
        StartDate : Date;
        EndDate : Date;
        StartTimestampInt : BigInteger;
        EndTimestampInt : BigInteger;
        StartTimestamp : Text;
        EndTimestamp : Text;
        IsVariant : Boolean;
        IsParent : Boolean;
        BaseSKU : Text;
        Title : Text;
        BarCode : Text;
        StringBuilder : DotNet "'mscorlib'.System.Text.StringBuilder";
    begin
        StringBuilder := StringBuilder.StringBuilder;
        String := StringBuilder.ToString;

        if (SitooProductId."Size Code" <> '') or (SitooProductId."Color Code" <> '') then
          IsVariant := true;

        if IsVariant then begin
          BaseSKU := SitooProductId."No." + '_' + SitooProductId."Color Code";
          if SitooProductId."Size Code" <> '' then
            SKU := BaseSKU + '-' + SitooProductId."Size Code";
        end;

        if not IsVariant then begin
          SKU := SitooProductId."No.";
        end;
    end;

    local procedure SerializeProductImages(var Setup : Record "Sitoo Setup");
    var
        Common : Codeunit "Sitoo Common";
        String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
        SitooOutboundQueue : Record "Sitoo Outbound Queue";
        "Count" : Integer;
    begin
        SitooOutboundQueue.SETRANGE("Market Code", Setup."Market Code");
        SitooOutboundQueue.SETRANGE(Type, 'PRODUCT');
        SitooOutboundQueue.SETRANGE("Sub Type", 'IMAGE');
        SitooOutboundQueue.SETRANGE(Action, 'POST');
        SitooOutboundQueue.SETFILTER("Retry Count", '<%1', Setup."Outbound Queue Retry Count");
        if SitooOutboundQueue.FINDSET(true, true) then begin
          Count := 0;
          repeat
            if SerializeProductImage(SitooOutboundQueue."Primary Key 1", Setup."Market Code", String) then
              Common.AddOutboundLogEntry(String, 'PRODUCT', 'IMAGE', 'SerializeProductImage', SitooOutboundQueue."Primary Key 1", 'POST', Setup."Market Code");

            SitooOutboundQueue.DELETE;
            COMMIT;
            Count += 1;
          until (SitooOutboundQueue.NEXT = 0);
        end;
    end;

    local procedure SerializeProductImage(ItemNo : Code[20];MarketCode : Code[20];var String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String") : Boolean;
    var
        SitooProductId : Record "Sitoo Product";
        Filename : Text;
        FileData : Text;
        JsonMgt : Codeunit "Sitoo Json Mgt";
        Common : Codeunit "Sitoo Common";
        EntryNo : Integer;
        SitooLogEntry : Record "Sitoo Log Entry";
        Item : Record Item;
    begin
        SitooProductId.SETRANGE("Market Code", MarketCode);
        SitooProductId.SETRANGE("No.", ItemNo);
        if not SitooProductId.FINDFIRST then
          exit;

        if SitooProductId."Last Image Sync" <> 0DT then
          exit;

        Item.GET(ItemNo);

        Filename := ExportItemImage(Item);

        if Filename = '' then
          exit(false);

        FileData := GetImageFileData(Filename);

        JsonMgt.StartJSon;
        JsonMgt.AddToJSon('resourceid', ItemNo + '.jpeg');
        JsonMgt.AddToJSon('filedata', FileData);
        JsonMgt.EndJSon;
        String := JsonMgt.GetJSon;

        exit(true);
    end;

    local procedure SendProducts(var SitooLogEntry : Record "Sitoo Log Entry") : Integer;
    var
        SitooSetup : Record "Sitoo Setup";
        Common : Codeunit "Sitoo Common";
        String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
        Status : Integer;
    begin
        SitooSetup.GET(SitooLogEntry."Market Code");

        Status := Common.UploadLogEntry(SitooLogEntry, 'SendProducts', true, SitooSetup."Base URL" + 'sites/' + FORMAT(SitooSetup."Site Id") + '/products.json');

        if Status > 0 then begin
          SitooLogEntry.Status := SitooLogEntry.Status::Processed;
          SitooLogEntry.MODIFY;
        end;

        exit(Status);
    end;

    local procedure SendProductUpdate(var SitooLogEntry : Record "Sitoo Log Entry") : Integer;
    var
        SitooProductId : Record "Sitoo Product";
        Common : Codeunit "Sitoo Common";
        SitooSetup : Record "Sitoo Setup";
        Status : Integer;
        ErrorText : Text;
        ProductId : Integer;
        Pos1 : Integer;
        Pos2 : Integer;
    begin
        SitooSetup.GET(SitooLogEntry."Market Code");

        ProductId := GetProductId(SitooLogEntry."Document No.", SitooSetup."Market Code");
        if ProductId <= 0 then begin
          SitooLogEntry.Status := SitooLogEntry.Status::Processed;
          SitooLogEntry.Information := 'No Product Id found for ' + SitooLogEntry."Document No.";
          SitooLogEntry.MODIFY;
          exit(0);
        end;

        Status := Common.UploadLogEntry(SitooLogEntry, 'SendProduct', false, SitooSetup."Base URL"+ 'sites/' + FORMAT(SitooSetup."Site Id") + '/products/' + FORMAT(ProductId) + '.json');

        if Status > 0 then begin
          SitooLogEntry.Status := SitooLogEntry.Status::Processed;
          SitooLogEntry.MODIFY;
          if SitooLogEntry.Action = 'DELETE' then
            DeleteProductId(ProductId, SitooSetup."Market Code");
        end else
          HandleSendStatus(SitooLogEntry, Status);

        exit(Status);
    end;

    local procedure SendVariant(var SitooLogEntry : Record "Sitoo Log Entry") : Integer;
    var
        SitooProductId : Record "Sitoo Product";
        Common : Codeunit "Sitoo Common";
        SitooSetup : Record "Sitoo Setup";
        Status : Integer;
        ErrorText : Text;
        ProductId : Integer;
        Pos1 : Integer;
        Pos2 : Integer;
    begin
        SitooSetup.GET(SitooLogEntry."Market Code");

        ProductId := GetParentId(SitooLogEntry."Document No.", SitooSetup."Market Code");
        if ProductId <= 0 then
          exit(0);

        Status := Common.UploadLogEntry(SitooLogEntry, 'SendVariant', false, SitooSetup."Base URL"+ 'sites/' + FORMAT(SitooSetup."Site Id") + '/products/' + FORMAT(ProductId) + '/productvariants.json');

        if Status > 0 then begin
          SitooLogEntry.Status := SitooLogEntry.Status::Processed;
          SitooLogEntry.MODIFY;

          DownloadVariantIds(SitooLogEntry."Document No.", ProductId, SitooSetup."Market Code");
        end else
          HandleSendStatus(SitooLogEntry, Status);

        exit(Status);
    end;

    procedure SendProductImage(SitooLogEntry : Record "Sitoo Log Entry") : Integer;
    var
        Setup : Record "Sitoo Setup";
        Common : Codeunit "Sitoo Common";
        String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
        Status : Integer;
        SitooProductId : Record "Sitoo Product";
        ProductId : Integer;
    begin
        Setup.GET(SitooLogEntry."Market Code");

        ProductId := GetProductId(SitooLogEntry."Document No.", SitooLogEntry."Market Code");
        SitooProductId.GET(ProductId);

        Status := Common.UploadLogEntry(SitooLogEntry, 'SendProductImage', false, Setup."Base URL" + 'sites/' + FORMAT(Setup."Site Id") + '/products/' + FORMAT(ProductId) + '/images.json');

        if Status > 0 then begin
          SitooLogEntry.Status := SitooLogEntry.Status::Processed;
          CLEAR(SitooLogEntry.Information);
          SitooLogEntry.MODIFY;
          SitooProductId."Last Image Sync" := CURRENTDATETIME;
          SitooProductId.MODIFY;
        end else
          HandleSendStatus(SitooLogEntry, Status);

        exit(Status);
    end;

    procedure DownloadVariantIds(BaseSKU : Text;ParentId : Integer;MarketCode : Code[20]);
    var
        Common : Codeunit "Sitoo Common";
        ProductId : Integer;
        URL : Text;
        Setup : Record "Sitoo Setup";
    begin
        Setup.GET(MarketCode);

        if ParentId = 0 then
          exit;

        URL := Setup."Base URL"+ 'sites/' + FORMAT(Setup."Site Id") + '/products/' + FORMAT(ParentId) + '/productvariants.json';

        Common.Download(URL, 'PRODUCT', 'VARIANTS', 'DownloadVariantIds', BaseSKU, Setup."Market Code");
    end;

    local procedure ProcessProductList(var SitooLogEntry : Record "Sitoo Log Entry");
    var
        Common : Codeunit "Sitoo Common";
        XmlResponseDocument : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlDocument";
        XmlResponseNodeList : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNodeList";
        XmlResponseNode : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        XmlRequestDocument : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlDocument";
        XmlRequestNodeList : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNodeList";
        XmlRequestNode : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        XmlStatusNode : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        XmlSKUNode : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        XmlProductIdNode : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        Counter : Integer;
        Text : Text;
    begin
        Common.GetResponseXML(SitooLogEntry, XmlResponseDocument);
        Common.GetRequestXML(SitooLogEntry, XmlRequestDocument);

        XmlResponseNodeList := XmlResponseDocument.FirstChild.ChildNodes;
        XmlRequestNodeList := XmlRequestDocument.FirstChild.ChildNodes;

        while Counter < XmlResponseNodeList.Count do begin
          XmlResponseNode := XmlResponseNodeList.Item(Counter);
          XmlRequestNode := XmlRequestNodeList.Item(Counter);

          XmlStatusNode := XmlResponseNode.SelectSingleNode('statuscode');
          XmlProductIdNode := XmlResponseNode.SelectSingleNode('return');
          XmlSKUNode := XmlRequestNode.SelectSingleNode('sku');

          if XmlStatusNode.InnerText = '200' then
            SaveProduct(XmlProductIdNode, XmlSKUNode, SitooLogEntry)
          else if XmlStatusNode.InnerText = '400' then begin

          end;
          Counter += 1;
        end;

        SitooLogEntry.Status := SitooLogEntry.Status::Processed;
        SitooLogEntry.Information := FORMAT(Counter) + ' products processed';
        SitooLogEntry.MODIFY;
    end;

    local procedure SaveProduct(var XmlResponseNode : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";var XmlRequestNode : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";var LogEntry : Record "Sitoo Log Entry");
    var
        Common : Codeunit "Sitoo Common";
        ProductId : Integer;
        ItemNo : Code[20];
        ColorCode : Code[20];
        SizeCode : Code[20];
        SitooProductId : Record "Sitoo Product";
        SKU : Text;
    begin
        SKU := XmlRequestNode.InnerXml;

        EVALUATE(ProductId, XmlResponseNode.InnerXml);

        SplitSKU(SKU, ItemNo, ColorCode, SizeCode);

        if not SitooProductId.GET(ProductId, LogEntry."Market Code") then begin
          SitooProductId.INIT;
          SitooProductId."Product Id" := ProductId;
          SitooProductId."Market Code" := LogEntry."Market Code";
          SitooProductId."Parent Variant Id" := ProductId;
          SitooProductId."No." := ItemNo;
          SitooProductId."Color Code" := ColorCode;
          SitooProductId."Source Entry No." := LogEntry."Entry No.";
          SitooProductId.SKU := SKU;
          SitooProductId.INSERT(true);
        end;
    end;

    local procedure ProcessVariantIdList(var SitooLogEntry : Record "Sitoo Log Entry");
    var
        Common : Codeunit "Sitoo Common";
        Counter : Integer;
        XmlDocument : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlDocument";
        XmlNodeList : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNodeList";
        XmlNode : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
    begin
        Common.GetResponseXML(SitooLogEntry, XmlDocument);

        XmlNodeList := XmlDocument.GetElementsByTagName('variants');

        while Counter < XmlNodeList.Count do begin
          XmlNode := XmlNodeList.Item(Counter);

          SaveVariantId(XmlNode, SitooLogEntry);

          Counter += 1;
        end;

        SitooLogEntry.Status := SitooLogEntry.Status::Processed;
        SitooLogEntry.Information := FORMAT(Counter) + ' variants processed';
        SitooLogEntry.MODIFY;
    end;

    local procedure SaveVariantId(var XmlNode : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";var LogEntry : Record "Sitoo Log Entry");
    var
        Common : Codeunit "Sitoo Common";
        ItemNo : Code[20];
        ColorCode : Code[20];
        SizeCode : Code[20];
        SitooProductId : Record "Sitoo Product";
        SKU : Text;
        ProductId : Integer;
        ParentId : Integer;
    begin
        SKU := Common.GetValueXML(XmlNode, 'sku');

        EVALUATE(ProductId, Common.GetValueXML(XmlNode, 'productid'));

        SplitSKU(SKU, ItemNo, ColorCode, SizeCode);

        ParentId := GetParentId(SKU, LogEntry."Market Code");

        if ParentId = -1 then begin
          if Common.GetValueXML(XmlNode, 'variantparentid') <> '' then
            EVALUATE(ParentId, Common.GetValueXML(XmlNode, 'variantparentid'))
          else
            ParentId := ProductId;
        end;

        if not SitooProductId.GET(ProductId, LogEntry."Market Code") then begin
          SitooProductId.INIT;
          SitooProductId."Product Id" := ProductId;
          SitooProductId."Market Code" := LogEntry."Market Code";
          SitooProductId.INSERT(false);
        end;

        SitooProductId."No." := ItemNo;
        SitooProductId."Parent Variant Id" := ParentId;
        SitooProductId."Size Code" := SizeCode;
        SitooProductId."Color Code" := ColorCode;
        SitooProductId."Variant Code" := GetVariantCode(SKU);
        SitooProductId."Source Entry No." := LogEntry."Entry No.";
        SitooProductId.SKU := SKU;
        SitooProductId.MODIFY;
    end;

    procedure DownloadProducts(var Setup : Record "Sitoo Setup");
    var
        Common : Codeunit "Sitoo Common";
        URL : Text;
    begin

        URL := Setup."Base URL" + 'sites/' + FORMAT(Setup."Site Id") +
          '/products.json?includeinactive=true&num=20000&fields=productid,sku,variantparentid,variant';

        Common.Download(URL, 'PRODUCT', 'DOWNLOADLIST', 'DownloadProducts', '', Setup."Market Code");
    end;

    procedure DownloadProduct_notinuse(SKU : Text;var Setup : Record "Sitoo Setup");
    var
        Common : Codeunit "Sitoo Common";
        URL : Text;
    begin

        // URL := Setup."Base URL" + 'sites/' + FORMAT(Setup."Site Id") +
        //  '/products.json?sku=' + SKU + 'includeinactive=true&num=10000&fields=productid,sku,variantparentid,variant';
        //
        // Common.Download(URL, 'PRODUCT', 'DOWNLOAD', 'DownloadProduct', SKU, Setup."Market Code");
    end;

    local procedure ProcessDownloadList(var SitooLogEntry : Record "Sitoo Log Entry");
    var
        Common : Codeunit "Sitoo Common";
        Rows : Integer;
        Row : Integer;
        TempPostingExchField : Record "Data Exch. Field" temporary;
        GroupName : Text;
        XmlDocument : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlDocument";
        XmlNodeList : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNodeList";
        XmlNode : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        Counter : Integer;
    begin
        Common.GetResponseXML(SitooLogEntry, XmlDocument);

        XmlNodeList := XmlDocument.GetElementsByTagName('items');

        while Counter < XmlNodeList.Count do begin
          XmlNode := XmlNodeList.Item(Counter);

          SaveDownloadProduct(XmlNode, SitooLogEntry);

          Counter += 1;
        end;

        SitooLogEntry.Information := FORMAT(Counter) + ' products downloaded';
        SitooLogEntry.Status := SitooLogEntry.Status::Processed;
        SitooLogEntry.MODIFY;
    end;

    local procedure SaveDownloadProduct(var XmlNode : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";var LogEntry : Record "Sitoo Log Entry");
    var
        Common : Codeunit "Sitoo Common";
        ProductId : Integer;
        ItemNo : Code[20];
        ColorCode : Code[20];
        SizeCode : Code[20];
        SitooProductId : Record "Sitoo Product";
        SKU : Text;
        ParentId : Integer;
        Status : Text;
    begin
        SKU := Common.GetValueXML(XmlNode, 'sku');

        EVALUATE(ProductId, Common.GetValueXML(XmlNode, 'productid'));

        SplitSKU(SKU, ItemNo, ColorCode, SizeCode);

        ParentId := GetParentId(SKU, LogEntry."Market Code");

        if ParentId = -1 then begin
          if Common.GetValueXML(XmlNode, 'variantparentid') <> '' then
            EVALUATE(ParentId, Common.GetValueXML(XmlNode, 'variantparentid'))
          else
            ParentId := ProductId;
        end;

        if not SitooProductId.GET(ProductId, LogEntry."Market Code") then begin
          SitooProductId.INIT;
          SitooProductId."Product Id" := ProductId;
          SitooProductId."Market Code" := LogEntry."Market Code";
          SitooProductId.INSERT(ProductId = ParentId)
        end;

        SitooProductId."No." := ItemNo;
        SitooProductId."Parent Variant Id" := ParentId;
        SitooProductId."Size Code" := SizeCode;
        SitooProductId."Color Code" := ColorCode;
        SitooProductId."Variant Code" := GetVariantCode(SKU);
        SitooProductId."Source Entry No." := LogEntry."Entry No.";
        SitooProductId.SKU := SKU;
        SitooProductId.MODIFY;
    end;

    local procedure DeleteProductId(ProductId : Integer;MarketCode : Code[20]);
    var
        SitooProductId : Record "Sitoo Product";
    begin
        SitooProductId.SETRANGE("Market Code", MarketCode);
        SitooProductId.SETRANGE("Parent Variant Id", ProductId);
        if SitooProductId.FINDSET then
          SitooProductId.DELETEALL;
    end;

    local procedure EnqueuePriceUpdates();
    begin
    end;

    local procedure HandleSendStatus(var SitooLogEntry : Record "Sitoo Log Entry";Status : Integer);
    var
        Common : Codeunit "Sitoo Common";
        ErrorText : Text;
        Pos1 : Integer;
        Pos2 : Integer;
        ProductId : Integer;
        SitooProductId : Record "Sitoo Product";
    begin
        if Status = -400 then begin
          ErrorText := Common.GetErrorTextXML(SitooLogEntry);

          if (STRPOS(ErrorText, 'Invalid productid') > 0) or
             (STRPOS(ErrorText, 'productid does not exist') > 0) then begin
            Pos1 := STRPOS(ErrorText, '(') + 1;
            Pos2 := STRPOS(ErrorText, ')');

            EVALUATE(ProductId, COPYSTR(ErrorText, Pos1, Pos2-Pos1));

            SitooProductId.SETRANGE("Market Code", SitooLogEntry."Market Code");
            SitooProductId.SETRANGE("Parent Variant Id", ProductId);
            if SitooProductId.FINDSET then begin
              SitooProductId.DELETEALL;
              SitooLogEntry.Status := SitooLogEntry.Status::Processed;
              SitooLogEntry.Information := 'Product Id ' + FORMAT(ProductId) + ' deleted';
              SitooLogEntry.MODIFY;
            end;
          end;
        end;
    end;

    procedure SplitSKU(SKU : Text;var ItemNo : Code[20];var ColorCode : Code[20];var SizeCode : Code[20]);
    var
        ItemText : Text;
        ColorText : Text;
        SizeText : Text;
    begin
        SKU := CONVERTSTR(SKU, '+', ' ');

        ItemText := SKU;

        if STRPOS(SKU, '_') <> 0 then begin
          ItemNo := COPYSTR(SKU, 1, STRPOS(SKU, '_') - 1);
          ColorText := COPYSTR(SKU, STRPOS(SKU, '_') + 1, STRLEN(SKU)-STRPOS(SKU, '_'));
        end else
          ItemNo := ItemText;

        if STRPOS(ColorText, '-') > 0 then begin
          SizeText := COPYSTR(ColorText, STRPOS(ColorText, '-') + 1, STRLEN(ColorText)-STRPOS(ColorText, '-'));
          ColorText := COPYSTR(ColorText, 1, STRPOS(ColorText, '-') - 1);
        end;

        ColorCode := ColorText;
        SizeCode := SizeText;
    end;

    procedure GetItemDescription(ItemNo : Code[20];ColorCode : Code[20];SizeCode : Code[20];MarketCode : Code[20]) : Text;
    var
        ItemTranslation : Record "Item Translation";
        Setup : Record "Sitoo Setup";
        Item : Record Item;
        Description : Text;
        Handled : Boolean;
        SitooEvents : Codeunit "Sitoo Events";
    begin
        SitooEvents.SitoocU51307_OnBeforeGetItemDescription(ItemNo, ColorCode, SizeCode, MarketCode, Description, Handled);
        if Handled then
          exit(Description);

        Setup.GET(MarketCode);
        Item.GET(ItemNo);

        if ItemTranslation.GET(Item."No.", '', Setup."Site Language Code") then
          exit(ItemTranslation.Description);
        exit(Item.Description);
    end;

    procedure GetShortDescription(var SitooProductId : Record "Sitoo Product") : Text;
    var
        Events : Codeunit "Sitoo Events";
        ItemNo : Code[20];
        ColorCode : Code[20];
        SizeCode : Code[20];
        ShortDescription : Text;
        Handled : Boolean;
    begin
        SplitSKU(SitooProductId.SKU, ItemNo, ColorCode, SizeCode);

        Events.SitoocU51307_OnBeforeGetShortDescription(ItemNo, ColorCode, SizeCode, SitooProductId."Market Code", ShortDescription, Handled);
    end;

    procedure GetProductId(DocumentNo : Text;MarketCode : Code[20]) : Integer;
    var
        SitooProductId : Record "Sitoo Product";
        ItemNo : Code[20];
        ColorCode : Code[20];
        SizeCode : Code[20];
    begin
        SplitSKU(DocumentNo, ItemNo, ColorCode, SizeCode);

        SitooProductId.SETRANGE("Market Code", MarketCode);
        SitooProductId.SETRANGE("No.", ItemNo);
        SitooProductId.SETRANGE("Size Code", SizeCode);
        SitooProductId.SETRANGE("Color Code", ColorCode);
        if SitooProductId.FINDLAST then
          exit(SitooProductId."Product Id");

        exit(-1);
    end;

    local procedure GetParentId(DocumentNo : Text;MarketCode : Code[20]) : Integer;
    var
        SitooProductId : Record "Sitoo Product";
        ItemNo : Code[20];
        ColorCode : Code[20];
        SizeCode : Code[20];
    begin
        SplitSKU(DocumentNo, ItemNo, ColorCode, SizeCode);

        SitooProductId.SETRANGE("Market Code", MarketCode);
        SitooProductId.SETRANGE("No.", ItemNo);
        SitooProductId.SETRANGE("Color Code", ColorCode);
        SitooProductId.SETFILTER("Parent Variant Id", '>0');
        if SitooProductId.FINDFIRST then
          exit(SitooProductId."Product Id");

        exit(-1);
    end;

    procedure GetVariantCode(SKU : Text) : Code[20];
    var
        Events : Codeunit "Sitoo Events";
        VariantCode : Code[10];
        Handled : Boolean;
        ItemNo : Code[20];
        ColorCode : Code[20];
        SizeCode : Code[20];
    begin
        SplitSKU(SKU, ItemNo, ColorCode, SizeCode); //MAJO
        Events.SitoocU51307_OnBeforeGetVariantCode(ItemNo, ColorCode, SizeCode, VariantCode, Handled);
        if Handled then
          exit(VariantCode);

        exit('');
    end;

    procedure GetBarcode(SitooProductId : Record "Sitoo Product") : Text;
    var
        Events : Codeunit "Sitoo Events";
        Handled : Boolean;
        Barcode : Text;
        ItemCrossReference : Record "Item Cross Reference";
        Item : Record Item;
    begin
        Events.SitooCU51307_OnBeforeGetBarcode(SitooProductId, Barcode, Handled);
        if Handled then
          exit(Barcode);

        Item.GET(SitooProductId."No.");

        ItemCrossReference.SETRANGE("Item No.", Item."No.");
        ItemCrossReference.SETRANGE("Unit of Measure", Item."Base Unit of Measure");
        ItemCrossReference.SETRANGE("Cross-Reference Type", ItemCrossReference."Cross-Reference Type"::"Bar Code");
        if ItemCrossReference.FINDFIRST then
          exit(ItemCrossReference."Cross-Reference No.");

        exit(' ');
    end;

    [Scope('Personalization')]
    procedure GetUnitListPrice(SKU : Text) : Decimal;
    var
        SitooSetup : Record "Sitoo Setup";
        SalesPriceTEMP : Record "Sales Price" temporary;
        ItemNo : Code[20];
        ColorCode : Code[20];
        SizeCode : Code[20];
        VariantCode : Code[20];
        Item : Record Item;
        VATPostingSetup : Record "VAT Posting Setup";
        UnitPrice : Decimal;
        ExclVat : Decimal;
        SalesPriceCalcMgt : Codeunit "Sales Price Calc. Mgt.";
        CustNo : Code[20];
        CustPriceGrCode : Code[10];
        InclVAT : Boolean;
        SitooPostingSetup : Record "Sitoo Posting Setup";
        Events : Codeunit "Sitoo Events";
        Handled : Boolean;
        UnitListPrice : Decimal;
    begin
        SplitSKU(SKU, ItemNo, ColorCode, SizeCode);

        VariantCode := GetVariantCode(SKU);

        Item.GET(ItemNo);

        Events.SitooCU51307_OnGetUnitListPrice(SalesPriceTEMP, ItemNo, VariantCode, CustNo, CustPriceGrCode, UnitListPrice, Handled);
        if not Handled then
          UnitListPrice := Item."Unit List Price";

        exit(UnitListPrice);
    end;

    [Scope('Personalization')]
    procedure GetUnitPriceExclVAT(SKU : Text;MarketCode : Code[20]) : Decimal;
    var
        SitooSetup : Record "Sitoo Setup";
        SalesPriceTEMP : Record "Sales Price" temporary;
        ItemNo : Code[20];
        ColorCode : Code[20];
        SizeCode : Code[20];
        VariantCode : Code[20];
        Item : Record Item;
        VATPostingSetup : Record "VAT Posting Setup";
        UnitPrice : Decimal;
        ExclVat : Decimal;
        SalesPriceCalcMgt : Codeunit "Sales Price Calc. Mgt.";
        CustNo : Code[20];
        CustPriceGrCode : Code[10];
        InclVAT : Boolean;
        SitooPostingSetup : Record "Sitoo Posting Setup";
        Events : Codeunit "Sitoo Events";
        Handled : Boolean;
    begin
        SitooSetup.GET(MarketCode);
        SitooPostingSetup.GET(MarketCode);

        SplitSKU(SKU, ItemNo, ColorCode, SizeCode);

        VariantCode := GetVariantCode(SKU);

        Item.GET(ItemNo);

        VATPostingSetup.GET(SitooPostingSetup."VAT Bus. Posting Group", Item."VAT Prod. Posting Group");

        if SitooSetup."Product Price Use Item Card" then begin
          UnitPrice := Item."Unit Price";
          InclVAT := Item."Price Includes VAT";
        end else begin
          if SitooSetup."Product Price List Type" = SitooSetup."Product Price List Type"::Customer then
            CustNo := SitooSetup."Product Price List Code";
          if SitooSetup."Product Price List Type" = SitooSetup."Product Price List Type"::"Customer Price Group" then
            CustPriceGrCode := SitooSetup."Product Price List Code";

          Events.SitooCU51307_OnGetUnitPriceExclVAT(SalesPriceTEMP, ItemNo, VariantCode, CustNo, CustPriceGrCode, Handled);
          if not Handled then
            SalesPriceCalcMgt.FindSalesPrice(SalesPriceTEMP, CustNo, '', CustPriceGrCode, '', ItemNo, VariantCode, '', SitooSetup."Product Price List Currency", TODAY, false);
            //SalesPriceCalcMgt.FindSalesPrice(SalesPriceTEMP, CustNo, '', CustPriceGrCode, '', ItemNo, VariantCode, '', '', TODAY, FALSE);

          UnitPrice := SalesPriceTEMP."Unit Price";

          InclVAT := SalesPriceTEMP."Price Includes VAT";
        end;

        if InclVAT then begin //##20180629#MAJO
          if (UnitPrice <> 0) and (VATPostingSetup."VAT %" <> 0) then
            ExclVat := UnitPrice / ((VATPostingSetup."VAT %"/ 100) + 1);
        end else //##20180629#MAJO
          ExclVat := UnitPrice; //##20180629#MAJO

        exit(ExclVat);
    end;

    procedure CheckBarcode(BarCode : Text) : Boolean;
    var
        CheckItemCrossReference : Record "Item Cross Reference";
    begin
        if BarCode = ' ' then
          exit(true);

        CheckItemCrossReference.SETRANGE("Cross-Reference Type", CheckItemCrossReference."Cross-Reference Type"::"Bar Code");
        CheckItemCrossReference.SETRANGE("Cross-Reference No.", BarCode);
        if CheckItemCrossReference.COUNT > 1 then
          exit(false);
        exit(true);
    end;

    local procedure GetImageFileData(FilePath : Text) : Text;
    var
        File : DotNet "'mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.IO.File";
        Convert : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Convert";
        Base64 : Text;
    begin
        Base64 := Convert.ToBase64String(File.ReadAllBytes(FilePath));

        exit(Base64);
    end;

    local procedure ExportItemImage(var Item : Record Item) : Text;
    var
        InStream : InStream;
        OutStream : OutStream;
        Filename : Text;
    begin
        Filename := TEMPORARYPATH + Item."No." + '.jpg';

        Item.Picture.EXPORTFILE(Filename); // Lägger på -1 i filnamnet

        Filename := TEMPORARYPATH + Item."No." + '-1.jpg';

        if not FILE.EXISTS(Filename) then
          exit('');

        exit(Filename);
    end;

    local procedure GetNextDeliveryDate(var Item : Record Item) : Text;
    var
        PurchaseHeader : Record "Purchase Header";
        PurchaseLine : Record "Purchase Line";
    begin
        PurchaseLine.SETCURRENTKEY("Document Type",Type,"No.","Variant Code","Drop Shipment","Location Code","Expected Receipt Date");
        PurchaseLine.SETRANGE("Document Type", PurchaseLine."Document Type"::Order);
        PurchaseLine.SETRANGE(Type, PurchaseLine.Type::Item);
        PurchaseLine.SETRANGE("No.", Item."No.");
        PurchaseLine.SETFILTER("Outstanding Quantity", '<>%1', 0);
        PurchaseLine.SETRANGE("Location Code", '150');
        if PurchaseLine.FINDSET then begin
          repeat
            PurchaseHeader.GET(PurchaseLine."Document Type", PurchaseLine."Document No.");
            if PurchaseHeader.Status = PurchaseHeader.Status::Released then
              exit(FORMAT(PurchaseLine."Expected Receipt Date"));
          until PurchaseLine.NEXT = 0;
        end;
        exit('')
    end;

    local procedure ValidateItem(ItemNo : Code[20];MarketCode : Code[20];var POSActive : Boolean) : Boolean;
    var
        SitooFilterLine : Record "Sitoo Filter Line";
        Item : Record Item;
        RecRef : RecordRef;
        FieldRef : array [10] of FieldRef;
        Index : Integer;
        Valid : Boolean;
        SitooProduct : Record "Sitoo Product";
    begin
        Valid := true;
        POSActive := true;

        SitooFilterLine.SETRANGE(Type, SitooFilterLine.Type::Item);
        if SitooFilterLine.FINDSET then begin
          Index := 1;

          RecRef.OPEN(27);
          FieldRef[Index] := RecRef.FIELD(1);
          FieldRef[Index].SETFILTER(ItemNo);
          repeat
            Index += 1;
            FieldRef[Index] := RecRef.FIELD(SitooFilterLine."Field No.");
            FieldRef[Index].SETFILTER(SitooFilterLine.Filter);
          until (SitooFilterLine.NEXT = 0) or (Index = 100);

          if not RecRef.FINDSET then
            Valid := false;

          if not Valid then begin
            if GetProductId(ItemNo, MarketCode) > 0 then begin
              Valid := true;
              POSActive := false;
            end;
          end;
        end;

        exit(Valid);
    end;
}

