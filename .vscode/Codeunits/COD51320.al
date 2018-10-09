codeunit 51320 "Sitoo PFVariant Mgt"
{
    // version Sitoo 3.0,SitooPF

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
    begin
    end;

    procedure SerializeOutbounds(var Setup : Record "Sitoo Setup");
    begin
        SerializeVariants('PUT', Setup."Market Code");
    end;

    [TryFunction]
    procedure SerializeAddToBaseProductList(var SitooOutboundQueue : Record "Sitoo Outbound Queue";var JsonMgt : Codeunit "Sitoo Json Mgt");
    var
        Common : Codeunit "Sitoo Common";
        ProductMgt : Codeunit "Sitoo Product Mgt";
        String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
        SitooVATProductGroup : Record "Sitoo VAT Product Group";
        SitooProductCategory : Record "Sitoo Product Category";
        ItemCrossReference : Record "Item Cross Reference";
        ItemVariant : Record "Item Variant";
        "Count" : Integer;
        Item : Record Item;
        PFVertComponent : Record "PFVert Component";
        SitooProductId : Record "Sitoo Product";
        SKU : Text;
    begin
        if Item.GET(SitooOutboundQueue."Primary Key 1") then begin
          PFVertComponent.SETRANGE("Component Group Code", Item."PFVert Component Group");
          if SitooOutboundQueue."Primary Key 2" <> '' then
            PFVertComponent.SETRANGE("Variant Component", SitooOutboundQueue."Primary Key 2");
          if PFVertComponent.FINDSET then begin
            repeat
              ItemVariant.RESET;
              ItemVariant.SETRANGE("Item No.", Item."No.");
              ItemVariant.SETRANGE("PFVertical Component", PFVertComponent.Code);
              if ItemVariant.FINDSET then begin

              SitooProductId.RESET;
              SitooProductId.SETRANGE("No.", Item."No.");
              SitooProductId.SETRANGE("Size Code", PFVertComponent.Code);
              SitooProductId.SETRANGE("Market Code", SitooOutboundQueue."Market Code");
              if SitooProductId.FINDFIRST then
                ERROR('Product %1 already exists, check Sitoo Product Id %2', Item."No." + '_' + PFVertComponent.Code, SitooProductId."Product Id");

              SKU := Item."No." + '_' + PFVertComponent.Code;
              SKU := CONVERTSTR(SKU, ' ', '+');

              JsonMgt.BeginJsonObject;
              JsonMgt.AddToJSon('sku', SKU);
              JsonMgt.AddToJSon('title', GetItemDescription(Item."No.", PFVertComponent.Code, '', SitooOutboundQueue."Market Code"));
              JsonMgt.AddBoolProperty('active', false);
              JsonMgt.AddBoolProperty('activepos', false);
              SitooVATProductGroup.SETRANGE("VAT Prod Posting Group", Item."VAT Prod. Posting Group");
              if SitooVATProductGroup.FINDFIRST then
                JsonMgt.AddIntProperty('vatid', SitooVATProductGroup."VAT Id");

              SitooProductCategory.SETRANGE("Item Category", Item."Item Category Code");
              SitooProductCategory.SETRANGE("Product Group", Item."Product Group Code");
              if SitooProductCategory.FINDFIRST then
                JsonMgt.AddIntProperty('defaultcategoryid', SitooProductCategory."Category Id");

              JsonMgt.EndJsonObject;
              end;
            until PFVertComponent.NEXT = 0;
          end else begin
            SitooProductId.RESET;
            SitooProductId.SETRANGE("No.", Item."No.");
            SitooProductId.SETRANGE("Market Code", SitooOutboundQueue."Market Code");
            if SitooProductId.FINDFIRST then
              ERROR('Product %1 already exists, check Sitoo Product Id %2', Item."No.", SitooProductId."Product Id");

            SKU := Item."No.";
            SKU := CONVERTSTR(SKU, ' ', '+');

            JsonMgt.BeginJsonObject;
            JsonMgt.AddToJSon('sku', SKU);
            JsonMgt.AddToJSon('title', GetItemDescription(Item."No.", '', '', SitooOutboundQueue."Market Code"));
            JsonMgt.AddBoolProperty('active', false);
            JsonMgt.AddBoolProperty('activepos', false);
            SitooVATProductGroup.SETRANGE("VAT Prod Posting Group", Item."VAT Prod. Posting Group");
            SitooVATProductGroup.SETRANGE("Market Code", SitooOutboundQueue."Market Code");
            if SitooVATProductGroup.FINDFIRST then
              JsonMgt.AddIntProperty('vatid', SitooVATProductGroup."VAT Id");

            SitooProductCategory.SETRANGE("Item Category", Item."Item Category Code");
            SitooProductCategory.SETRANGE("Product Group", Item."Product Group Code");
            SitooProductCategory.SETRANGE("Market Code", SitooOutboundQueue."Market Code");
            if SitooProductCategory.FINDFIRST then
              JsonMgt.AddIntProperty('defaultcategoryid', SitooProductCategory."Category Id");

            JsonMgt.EndJsonObject;
          end;
        end;
    end;

    [TryFunction]
    procedure SerializeProduct(var SitooProductId : Record "Sitoo Product";var SKU : Text;IsParent : Boolean;IsVariant : Boolean;var JsonMgt : Codeunit "Sitoo Json Mgt");
    var
        ProductMgt : Codeunit "Sitoo Product Mgt";
        Item : Record Item;
        Common : Codeunit "Sitoo Common";
        ItemCrossReference : Record "Item Cross Reference";
        ItemVariant : Record "Item Variant";
        BaseSKU : Text;
        Title : Text;
        Brand : Text;
        PFBrand : Record PFBrand;
    begin
        Item.GET(SitooProductId."No.");

        if IsVariant then begin
          Title := GetItemDescription(Item."No.", SitooProductId."Color Code", '', SitooProductId."Market Code");
          BaseSKU := Item."No." + '_' + SitooProductId."Color Code";

          ItemVariant.SETRANGE("Item No.", Item."No.");
          ItemVariant.SETRANGE("PFVertical Component", SitooProductId."Color Code");
          ItemVariant.SETRANGE("PFHorizontal Component", SitooProductId."Size Code");
          ItemVariant.FINDFIRST;

          SKU := BaseSKU + '-' + SitooProductId."Size Code";

          Title := ItemVariant.Description + ' ' + ItemVariant."Description 2";
          Title := DELCHR(Title, '=', ',');
        end;

        if not IsVariant then begin
          Title := GetItemDescription(Item."No.", '', '', SitooProductId."Market Code");
          SKU := SitooProductId.SKU;
        end;

        JsonMgt.AddToJSon('title', Title);
        JsonMgt.AddToJSon('sku', SKU);
    end;

    local procedure SerializeVariants("Action" : Code[10];MarketCode : Code[20]);
    var
        SitooOutboundQueue : Record "Sitoo Outbound Queue";
        String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
        BaseSKU : Text;
        Common : Codeunit "Sitoo Common";
        ProductMgt : Codeunit "Sitoo Product Mgt";
    begin
        SitooOutboundQueue.SETRANGE("Market Code", MarketCode);
        SitooOutboundQueue.SETRANGE(Type, 'PRODUCT');
        SitooOutboundQueue.SETRANGE("Sub Type", 'VARIANT');
        SitooOutboundQueue.SETFILTER(Action, Action);
        if SitooOutboundQueue.FINDSET(true, true) then begin
          repeat
            if SerializeVariant(SitooOutboundQueue, String, BaseSKU) then
              Common.AddOutboundLogEntry(String, 'PRODUCT', 'VARIANT', 'SerializeVariant', BaseSKU, SitooOutboundQueue.Action, SitooOutboundQueue."Market Code")
            else if ProductMgt.GetProductId(BaseSKU, SitooOutboundQueue."Market Code") = -1 then
              Common.AddQueueMessage('PRODUCT', 'VARIANT', 'POST', SitooOutboundQueue."Primary Key 1", SitooOutboundQueue."Primary Key 2", SitooOutboundQueue."Market Code");
            SitooOutboundQueue.DELETE;
            COMMIT;
          until SitooOutboundQueue.NEXT = 0;
        end;
    end;

    [TryFunction]
    local procedure SerializeVariant(var SitooOutboundQueue : Record "Sitoo Outbound Queue";var String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";var BaseSKU : Text);
    var
        JsonMgt : Codeunit "Sitoo Json Mgt";
        ProductMgt : Codeunit "Sitoo Product Mgt";
        Item : Record Item;
        ItemVariant : Record "Item Variant";
        SitooProductId : Record "Sitoo Product";
        PFHorzComponent : Record "PFHorz Component";
        ItemCrossReference : Record "Item Cross Reference";
        Common : Codeunit "Sitoo Common";
        Events : Codeunit "Sitoo Events";
        SKU : Text;
        BarCode : Text;
        Friendly : Text;
        ProductId : Integer;
        VariantCounter : Integer;
        Title : Text;
        Handled : Boolean;
    begin
        Item.GET(SitooOutboundQueue."Primary Key 1");

        if SitooOutboundQueue."Primary Key 2" = '' then
          ERROR('No Horizontal Component');

        BaseSKU := Item."No." + '_' + SitooOutboundQueue."Primary Key 2";

        ItemVariant.SETRANGE("Item No.", Item."No.");
        ItemVariant.SETRANGE("PFVertical Component", SitooOutboundQueue."Primary Key 2");
        if not ItemVariant.FINDSET then
          ERROR('No variant found');

        if ProductMgt.GetProductId(BaseSKU, SitooOutboundQueue."Market Code") = -1 then
          ERROR('Product Id for %1 not found', BaseSKU);

        JsonMgt.StartJSon;

        PFHorzComponent.SETCURRENTKEY("Component Group Code",Sorting);
        PFHorzComponent.SETRANGE("Component Group Code", Item."PFHorz Component Group");
        if PFHorzComponent.FINDSET then begin
          JsonMgt.AddProperty('groups');
          JsonMgt.StartJSonArray;
          JsonMgt.BeginJsonObject;
          JsonMgt.AddToJSon('name', 'size');
          JsonMgt.AddProperty('options');
          JsonMgt.StartJSonArray;

          repeat
            JsonMgt.AddValue(PFHorzComponent.Description);
          until PFHorzComponent.NEXT = 0;

          JsonMgt.EndJSonArray;
          JsonMgt.EndJsonObject;
          JsonMgt.EndJSonArray;
        end;

        JsonMgt.AddProperty('variants');
        JsonMgt.StartJSonArray;

        VariantCounter := 0;

        ItemVariant.RESET;
        ItemVariant.SETCURRENTKEY("Item No.",PFSorting);
        ItemVariant.SETRANGE("Item No.", Item."No.");
        ItemVariant.SETRANGE("PFVertical Component", SitooOutboundQueue."Primary Key 2");
        if ItemVariant.FINDSET then begin
          repeat
            SKU := BaseSKU + '-' + ItemVariant."PFHorizontal Component";
            SKU := CONVERTSTR(SKU, ' ', '+');
            Title := ItemVariant.Description + ' ' + ItemVariant."Description 2";
            Title := DELCHR(Title, '=', ',');
            BarCode := ' ';

            ProductId := ProductMgt.GetProductId(SKU, SitooOutboundQueue."Market Code");
            if ProductId < 0 then
              ProductId := 0;
            if (VariantCounter = 0) and (ProductId = 0) then
              ProductId := ProductMgt.GetProductId(BaseSKU, SitooOutboundQueue."Market Code");

            PFHorzComponent.GET(Item."PFHorz Component Group", ItemVariant."PFHorizontal Component");

            ItemCrossReference.SETRANGE("Item No.", Item."No.");
            ItemCrossReference.SETRANGE("Variant Code", ItemVariant.Code);
            ItemCrossReference.SETRANGE("Unit of Measure", Item."Base Unit of Measure");
            ItemCrossReference.SETRANGE("Cross-Reference Type", ItemCrossReference."Cross-Reference Type"::"Bar Code");
            if ItemCrossReference.FINDFIRST then
              BarCode := ItemCrossReference."Cross-Reference No.";

            JsonMgt.BeginJsonObject;

            JsonMgt.AddIntProperty('productid', ProductId);
            JsonMgt.AddToJSon('title', Title);
            JsonMgt.AddToJSon('sku', SKU);
            JsonMgt.AddBoolProperty('active', true);
            JsonMgt.AddBoolProperty('activepos', true);
            JsonMgt.AddToJSon('deliverystatus', '');

            Events.SitooCU51307_OnBeforeProductCustomFields(SitooProductId, JsonMgt, Handled);
            if not Handled then begin
              JsonMgt.AddToJSon('custom1', '');
              JsonMgt.AddToJSon('custom2', '');
              JsonMgt.AddToJSon('descriptionshort', ProductMgt.GetShortDescription(SitooProductId));
            end;

            JsonMgt.AddToJSon('moneypriceorg', FORMAT(ProductMgt.GetUnitListPrice(SKU), 0, '<Precision,2:2><Standard Format,2>'));
            JsonMgt.AddToJSon('moneyprice', FORMAT(ProductMgt.GetUnitPriceExclVAT(SKU, SitooOutboundQueue."Market Code") , 0, '<Precision,2:2><Standard Format,2>'));

            JsonMgt.AddToJSon('moneypricein', FORMAT(Item."Unit Cost", 0, '<Precision,2:2><Standard Format,2>'));

            JsonMgt.AddToJSon('moneyofferprice', FORMAT(0.0, 0, '<Precision,2:2><Standard Format,2>'));

            Friendly := LOWERCASE(CONVERTSTR(Title, ' ', '-'));

            if not ProductMgt.CheckBarcode(BarCode) then
              BarCode := ' ';
            JsonMgt.AddToJSon('barcode', BarCode);
            JsonMgt.AddToJSon('friendly', Friendly);
            JsonMgt.AddProperty('attributes');
            JsonMgt.StartJSonArray;
            JsonMgt.AddValue(PFHorzComponent.Description);
            JsonMgt.EndJSonArray;

            JsonMgt.EndJsonObject;

            VariantCounter += 1;
          until ItemVariant.NEXT = 0;
        end;

        JsonMgt.WriteEnd;
        JsonMgt.EndJSon;

        String := JsonMgt.GetJSon;
    end;

    procedure GetItemDescription(ItemNo : Code[20];ColorCode : Code[20];SizeCode : Code[20];MarketCode : Code[20]) : Text;
    var
        Setup : Record "Sitoo Setup";
        ItemVariant : Record "Item Variant";
        VariantDescription : Text;
        Item : Record Item;
        PFVertComponent : Record "PFVert Component";
    begin
        Setup.GET(MarketCode);

        Item.GET(ItemNo);

        if (ColorCode <> '') and (SizeCode = '') then begin
          PFVertComponent.GET(Item."PFVert Component Group", ColorCode);
          if PFVertComponent.Description <> '' then begin
            VariantDescription := Item.Description + ' ' + PFVertComponent.Description;
            exit(VariantDescription);
          end;
        end else if (ColorCode <> '') and (SizeCode <> '') then begin
          ItemVariant.SETRANGE("Item No.", ItemNo);
          ItemVariant.SETRANGE("PFVertical Component", ColorCode);
          ItemVariant.SETRANGE("PFHorizontal Component", SizeCode);
          if ItemVariant.FINDSET then begin
            VariantDescription := ItemVariant.Description + ' ' + ItemVariant."Description 2";
            VariantDescription := DELCHR(VariantDescription, '=', ',');
            exit(VariantDescription);
          end;
        end;

        exit(Item.Description);
    end;

    procedure GetVariantCode(ItemNo : Code[20];ColorCode : Code[20];SizeCode : Code[20]) : Code[20];
    var
        ItemVariant : Record "Item Variant";
    begin
        ItemVariant.SETRANGE("Item No.", ItemNo);
        ItemVariant.SETRANGE("PFVertical Component", ColorCode);
        ItemVariant.SETRANGE("PFHorizontal Component", SizeCode);
        if ItemVariant.FINDSET then
          exit(ItemVariant.Code);
    end;

    procedure GetBarcode(var SitooProductId : Record "Sitoo Product") : Text;
    var
        ItemCrossReference : Record "Item Cross Reference";
        ItemVariant : Record "Item Variant";
        Item : Record Item;
        Barcode : Text;
    begin
        Item.GET(SitooProductId."No.");

        Barcode := ' ';

        ItemVariant.SETRANGE("Item No.", Item."No.");
        if SitooProductId."Color Code" <> '' then
          ItemVariant.SETRANGE("PFVertical Component", SitooProductId."Color Code");
        if SitooProductId."Size Code" <> '' then
          ItemVariant.SETRANGE("PFHorizontal Component", SitooProductId."Size Code");
        if ItemVariant.FINDFIRST then begin
          ItemCrossReference.SETRANGE("Item No.", Item."No.");
          ItemCrossReference.SETRANGE("Unit of Measure", Item."Base Unit of Measure");
          ItemCrossReference.SETRANGE("Cross-Reference Type", ItemCrossReference."Cross-Reference Type"::"Bar Code");
          ItemCrossReference.SETRANGE("Variant Code", ItemVariant.Code);
          if ItemCrossReference.FINDFIRST then begin
            Barcode := ItemCrossReference."Cross-Reference No.";
          end;
        end;
        exit(Barcode);
    end;

    procedure AddWhseBatchItems(var SitooOutboundQueueTEMP : Record "Sitoo Outbound Queue" temporary;var JsonMgt : Codeunit "Sitoo Json Mgt";var Item : Record Item);
    var
        SitooProductMgt : Codeunit "Sitoo Product Mgt";
        SKU : Text;
        ItemNo : Code[20];
        VertComponent : Code[20];
        HorzComponent : Code[20];
        ItemVariant : Record "Item Variant";
    begin
        SKU := SitooOutboundQueueTEMP."Primary Key 1";
        SitooProductMgt.SplitSKU(SKU, ItemNo, VertComponent, HorzComponent);

        if (VertComponent <> '') and (HorzComponent <> '') then begin
          ItemVariant.SETRANGE("Item No.", ItemNo);
          ItemVariant.SETRANGE("PFVertical Component", VertComponent);
          ItemVariant.SETRANGE("PFHorizontal Component", HorzComponent);
          ItemVariant.FINDFIRST;
          Item.SETFILTER("Variant Filter", ItemVariant.Code);
        end;
    end;
}

