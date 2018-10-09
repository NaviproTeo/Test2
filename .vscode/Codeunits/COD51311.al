codeunit 51311 "Sitoo Events"
{
    // version Sitoo 3.0

    // 180919 LG PurchDoc TESTFIELD if DocType


    trigger OnRun();
    begin
    end;

    var
        Common : Codeunit "Sitoo Common";
        ReopenPO : TextConst ENU='This will cancel the shipment in Sitoo, do you wish to continue?',SVE='Detta kommer arkivera försändelsen i Sitoo, vill du fortsätta?';
        LocMusExist : TextConst ENU='Purchase Header must have a value in Location Code',SVE='Inköpshuvudet måste ha ett värde i lagerställekod';

    [EventSubscriber(ObjectType::Codeunit, 415, 'OnAfterReleasePurchaseDoc', '', false, false)]
    local procedure CU415_OnAfterReleasePurchaseDoc(var PurchaseHeader : Record "Purchase Header";PreviewMode : Boolean;LinesWereModified : Boolean);
    var
        Setup : Record "Sitoo Setup";
        SitooWarehouse : Record "Sitoo Warehouse";
    begin
        if PreviewMode then
          exit;

        if not Setup.GET(Common.GetMarketCode(PurchaseHeader."Location Code")) then
          exit;

        if not Setup."Shipment Send Purchase Order" then
          exit;

        if PurchaseHeader."Document Type" in [PurchaseHeader."Document Type"::Order,PurchaseHeader."Document Type"::"Return Order"] then // 180919 LG
          if PurchaseHeader."Location Code" = '' then
            ERROR(LocMusExist);

        Common.AddQueueMessage('SHIPMENT', 'PURCHASEORDER', 'POST', PurchaseHeader."No.", '', Setup."Market Code");
    end;

    [EventSubscriber(ObjectType::Codeunit, 415, 'OnBeforeReopenPurchaseDoc', '', false, false)]
    local procedure CU415_OnBeforeReopenPurchaseDoc(var PurchaseHeader : Record "Purchase Header");
    var
        Setup : Record "Sitoo Setup";
        SitooShipment : Record "Sitoo Shipment";
    begin
        if not Setup.GET(Common.GetMarketCode(PurchaseHeader."Location Code")) then
          exit;

        if not Setup."Shipment Send Purchase Order" then
          exit;

        if GUIALLOWED then begin
          SitooShipment.SETRANGE("Document Type", SitooShipment."Document Type"::"Purchase Order");
          SitooShipment.SETRANGE("Document No.", PurchaseHeader."No.");
          if SitooShipment.FINDFIRST then
            if not CONFIRM(ReopenPO) then
              exit;
        end;

        Common.AddQueueMessage('SHIPMENT', 'PURCHASEORDER', 'PUT', PurchaseHeader."No.", 'CANCELLED', Setup."Market Code");
    end;

    [EventSubscriber(ObjectType::Codeunit, 5704, 'OnAfterTransferOrderPostShipment', '', false, false)]
    local procedure CU5704_OnAfterTransferOrderPostShipment(var TransferHeader : Record "Transfer Header");
    var
        Setup : Record "Sitoo Setup";
    begin
        if not Setup.GET(Common.GetMarketCode(TransferHeader."Transfer-to Code")) then
          exit;

        if not Setup."Shipment Send Transfer Order" then
          exit;

        Common.AddQueueMessage('SHIPMENT', 'TRANSFERSHIPMENT', 'POST', TransferHeader."Last Shipment No.", '', Setup."Market Code");
    end;

    [EventSubscriber(ObjectType::Codeunit, 5708, 'OnAfterReleaseTransferDoc', '', false, false)]
    local procedure CU5708_OnAfterReleaseTransferDoc(var TransferHeader : Record "Transfer Header");
    var
        Setup : Record "Sitoo Setup";
    begin
        if not Setup.GET(Common.GetMarketCode(TransferHeader."Transfer-to Code")) then
          exit;

        if not Setup."Shipment Send Transfer Order" then
          exit;

        Common.AddQueueMessage('SHIPMENT', 'TRANSFERORDER', 'POST', TransferHeader."No.", '', Setup."Market Code");
    end;

    [EventSubscriber(ObjectType::Table, 27, 'OnAfterDeleteEvent', '', false, false)]
    local procedure T27_OnAfterDeleteEvent(var Rec : Record Item;RunTrigger : Boolean);
    var
        Setup : Record "Sitoo Setup";
    begin
        if Rec.ISTEMPORARY then
          exit;

        Setup.SETRANGE(Active, true);
        Setup.SETRANGE("Send Items", true);
        if Setup.FINDSET then
          repeat
            Common.AddQueueMessage('PRODUCT', 'ITEM', 'DELETE', Rec."No.", '', Setup."Market Code");
          until Setup.NEXT = 0;
    end;

    [EventSubscriber(ObjectType::Table, 27, 'OnAfterInsertEvent', '', false, false)]
    local procedure T27_OnAfterInsertEvent(var Rec : Record Item;RunTrigger : Boolean);
    var
        Setup : Record "Sitoo Setup";
    begin
        if Rec.ISTEMPORARY then
          exit;

        Setup.SETRANGE(Active, true);
        Setup.SETRANGE("Send Items", true);
        if Setup.FINDSET then
          repeat
            Common.AddQueueMessage('PRODUCT', 'ITEM', 'POST', Rec."No.", '', Setup."Market Code");
            if Setup."Send Product Image" then
              Common.AddQueueMessage('PRODUCT', 'IMAGE', 'POST', Rec."No.", '', Setup."Market Code");
          until Setup.NEXT = 0;
    end;

    [EventSubscriber(ObjectType::Table, 27, 'OnAfterModifyEvent', '', false, false)]
    local procedure T27_OnAfterModifyEvent(var Rec : Record Item;var xRec : Record Item;RunTrigger : Boolean);
    var
        Setup : Record "Sitoo Setup";
    begin
        if Rec.ISTEMPORARY then
          exit;

        Setup.SETRANGE(Active, true);
        Setup.SETRANGE("Send Items", true);
        if Setup.FINDSET then
          repeat
            Common.AddQueueMessage('PRODUCT', 'ITEM', 'PUT', Rec."No.", '', Setup."Market Code");
            if Setup."Send Product Image" then
              Common.AddQueueMessage('PRODUCT', 'IMAGE', 'POST', Rec."No.", '', Setup."Market Code");
          until Setup.NEXT = 0;
    end;

    [EventSubscriber(ObjectType::Table, 30, 'OnAfterDeleteEvent', '', false, false)]
    local procedure T30_OnAfterDeleteEvent(var Rec : Record "Item Translation";RunTrigger : Boolean);
    var
        Setup : Record "Sitoo Setup";
    begin
        Setup.SETRANGE(Active, true);
        Setup.SETRANGE("Send Items", true);
        if Setup.FINDSET then
          repeat
            Common.AddQueueMessage('PRODUCT', 'ITEM', 'PUT', Rec."Item No.", '', Setup."Market Code");
          until Setup.NEXT = 0;
    end;

    [EventSubscriber(ObjectType::Table, 30, 'OnAfterInsertEvent', '', false, false)]
    local procedure T30_OnAfterInsertEvent(var Rec : Record "Item Translation";RunTrigger : Boolean);
    var
        Setup : Record "Sitoo Setup";
    begin
        Setup.SETRANGE(Active, true);
        Setup.SETRANGE("Send Items", true);
        if Setup.FINDSET then
          repeat
            Common.AddQueueMessage('PRODUCT', 'ITEM', 'PUT', Rec."Item No.", '', Setup."Market Code");
          until Setup.NEXT = 0;
    end;

    [EventSubscriber(ObjectType::Table, 30, 'OnAfterModifyEvent', '', false, false)]
    local procedure T30_OnAfterModifyEvent(var Rec : Record "Item Translation";var xRec : Record "Item Translation";RunTrigger : Boolean);
    var
        Setup : Record "Sitoo Setup";
    begin
        Setup.SETRANGE(Active, true);
        Setup.SETRANGE("Send Items", true);
        if Setup.FINDSET then
          repeat
            Common.AddQueueMessage('PRODUCT', 'ITEM', 'PUT', Rec."Item No.", '', Setup."Market Code");
          until Setup.NEXT = 0;
    end;

    [EventSubscriber(ObjectType::Table, 32, 'OnAfterInsertEvent', '', false, false)]
    local procedure T32_OnAfterInsertEvent(var Rec : Record "Item Ledger Entry";RunTrigger : Boolean);
    var
        Setup : Record "Sitoo Setup";
        SitooWarehouse : Record "Sitoo Warehouse";
        SKU : Text;
        Handled : Boolean;
    begin
        if not Setup.GET(Common.GetMarketCode(Rec."Location Code")) then
          exit;

        if not Setup."Send Inventory" then
          exit;

        SitooT32_OnAfterInsertEvent(Rec, RunTrigger, Handled);
        if Handled then
          exit;

        SitooWarehouse.SETRANGE("Market Code", Setup."Market Code");
        SitooWarehouse.SETRANGE("Location Code", Rec."Location Code");
        if SitooWarehouse.FINDFIRST then
          Common.AddQueueMessage('WAREHOUSE', 'STOCK', '', Rec."Item No.", Rec."Location Code", Setup."Market Code");
    end;

    [EventSubscriber(ObjectType::Table, 5401, 'OnBeforeInsertEvent', '', false, false)]
    local procedure T5401_OnBeforeInsertEvent(var Rec : Record "Item Variant";RunTrigger : Boolean);
    var
        Common : Codeunit "Sitoo Common";
        Handled : Boolean;
        Setup : Record "Sitoo Setup";
    begin
        SitooT5401_OnBeforeInsertEvent(Rec, RunTrigger, Handled);
    end;

    [EventSubscriber(ObjectType::Table, 5401, 'OnAfterInsertEvent', '', false, false)]
    local procedure T5401_OnAfterInsertEvent(var Rec : Record "Item Variant";RunTrigger : Boolean);
    var
        Handled : Boolean;
        Setup : Record "Sitoo Setup";
    begin
        SitooT5401_OnAfterInsertEvent(Rec, RunTrigger, Handled);
    end;

    [EventSubscriber(ObjectType::Table, 5401, 'OnAfterDeleteEvent', '', false, false)]
    local procedure T5401_OnAfterDeleteEvent(var Rec : Record "Item Variant";RunTrigger : Boolean);
    var
        Setup : Record "Sitoo Setup";
        Handled : Boolean;
    begin
        SitooT5401_OnAfterDeleteEvent(Rec, RunTrigger, Handled);
    end;

    [EventSubscriber(ObjectType::Table, 5717, 'OnAfterDeleteEvent', '', false, false)]
    local procedure T5717_OnAfterDeleteEvent(var Rec : Record "Item Cross Reference";RunTrigger : Boolean);
    var
        ItemVariant : Record "Item Variant";
        Handled : Boolean;
        Setup : Record "Sitoo Setup";
    begin
        SitooT5717_OnAfterDeleteEvent(Rec, RunTrigger, Handled);
        if Handled then
          exit;

        Setup.SETRANGE(Active, true);
        Setup.SETRANGE("Send Items", true);
        if Setup.FINDSET then
          repeat
            Common.AddQueueMessage('PRODUCT', 'ITEM', 'DELETE', Rec."Item No.", '', Setup."Market Code");
          until Setup.NEXT = 0;
    end;

    [EventSubscriber(ObjectType::Table, 5717, 'OnAfterInsertEvent', '', false, false)]
    local procedure T5717_OnAfterInsertEvent(var Rec : Record "Item Cross Reference";RunTrigger : Boolean);
    var
        SitooProductId : Record "Sitoo Product";
        ItemVariant : Record "Item Variant";
        Handled : Boolean;
        Setup : Record "Sitoo Setup";
    begin
        SitooT5717_OnAfterInsertEvent(Rec, RunTrigger, Handled);
        if Handled then
          exit;

        Setup.SETRANGE(Active, true);
        Setup.SETRANGE("Send Items", true);
        if Setup.FINDSET then
          repeat
            Common.AddQueueMessage('PRODUCT', 'ITEM', 'PUT', Rec."Item No.", '', Setup."Market Code");
          until Setup.NEXT = 0;
    end;

    [EventSubscriber(ObjectType::Table, 5717, 'OnAfterModifyEvent', '', false, false)]
    local procedure T5717_OnAfterModifyEvent(var Rec : Record "Item Cross Reference";var xRec : Record "Item Cross Reference";RunTrigger : Boolean);
    var
        ItemVariant : Record "Item Variant";
        Handled : Boolean;
        Setup : Record "Sitoo Setup";
    begin
        SitooT5717_OnAfterModifyEvent(Rec, RunTrigger, Handled);
        if Handled then
          exit;

        Setup.SETRANGE(Active, true);
        Setup.SETRANGE("Send Items", true);
        if Setup.FINDSET then
          repeat
            Common.AddQueueMessage('PRODUCT', 'ITEM', 'PUT', Rec."Item No.", '', Setup."Market Code");
          until Setup.NEXT = 0;
    end;

    [EventSubscriber(ObjectType::Table, 5717, 'OnAfterRenameEvent', '', false, false)]
    local procedure T5717_OnAfterRenameEvent(var Rec : Record "Item Cross Reference";var xRec : Record "Item Cross Reference";RunTrigger : Boolean);
    var
        ItemVariant : Record "Item Variant";
        Setup : Record "Sitoo Setup";
        Handled : Boolean;
    begin
        SitooT5717_OnAfterRenameEvent(Rec, RunTrigger, Handled);
        if Handled then
          exit;

        Setup.SETRANGE(Active, true);
        Setup.SETRANGE("Send Items", true);
        if Setup.FINDSET then
          repeat
            Common.AddQueueMessage('PRODUCT', 'ITEM', 'PUT', Rec."Item No.", '', Setup."Market Code");
          until Setup.NEXT = 0;
    end;

    [EventSubscriber(ObjectType::Table, 5722, 'OnAfterInsertEvent', '', false, false)]
    local procedure T5722_OnAfterInsertEvent(var Rec : Record "Item Category";RunTrigger : Boolean);
    var
        Setup : Record "Sitoo Setup";
    begin

        Setup.SETRANGE(Active, true);
        Setup.SETRANGE("Send Categories", true);
        if Setup.FINDSET then
          repeat
            Common.AddQueueMessage('CATEGORY', 'ITEMCATEGORY', 'POST', Rec.Code, '', Setup."Market Code");
          until Setup.NEXT = 0;
    end;

    [EventSubscriber(ObjectType::Table, 5722, 'OnAfterModifyEvent', '', false, false)]
    local procedure T5722_OnAfterModifyEvent(var Rec : Record "Item Category";var xRec : Record "Item Category";RunTrigger : Boolean);
    var
        Setup : Record "Sitoo Setup";
    begin

        Setup.SETRANGE(Active, true);
        Setup.SETRANGE("Send Categories", true);
        if Setup.FINDSET then
          repeat
            Common.AddQueueMessage('CATEGORY', 'ITEMCATEGORY', 'PUT', Rec.Code, '', Setup."Market Code");
          until Setup.NEXT = 0;
    end;

    [EventSubscriber(ObjectType::Table, 5723, 'OnAfterInsertEvent', '', false, false)]
    local procedure T5723_OnAfterInsertEvent(var Rec : Record "Product Group";RunTrigger : Boolean);
    var
        Setup : Record "Sitoo Setup";
    begin

        Setup.SETRANGE(Active, true);
        Setup.SETRANGE("Send Categories", true);
        if Setup.FINDSET then
          repeat
            Common.AddQueueMessage('CATEGORY', 'PRODUCTGROUP', 'POST', Rec."Item Category Code", Rec.Code, Setup."Market Code");
          until Setup.NEXT = 0;
    end;

    [EventSubscriber(ObjectType::Table, 5723, 'OnAfterModifyEvent', '', false, false)]
    local procedure T5723_OnAfterModifyEvent(var Rec : Record "Product Group";var xRec : Record "Product Group";RunTrigger : Boolean);
    var
        Setup : Record "Sitoo Setup";
    begin

        Setup.SETRANGE(Active, true);
        Setup.SETRANGE("Send Categories", true);
        if Setup.FINDSET then
          repeat
            Common.AddQueueMessage('CATEGORY', 'PRODUCTGROUP', 'PUT', Rec."Item Category Code", Rec.Code, Setup."Market Code");
          until Setup.NEXT = 0;
    end;

    [EventSubscriber(ObjectType::Table, 51305, 'OnAfterInsertEvent', '', false, false)]
    local procedure T51305_OnAfterInsertEvent(var Rec : Record "Sitoo Product";RunTrigger : Boolean);
    var
        Handled : Boolean;
        Setup : Record "Sitoo Setup";
    begin
        if not RunTrigger then
          exit;

        SitooT51305_OnAfterInsertEvent(Rec, RunTrigger, Handled);
        if Handled then
          exit;

        if not Setup.GET(Rec."Market Code") then
          exit;

        if not Setup."Send Items" then
          exit;

        Common.AddQueueMessage('PRODUCT', 'ITEM', 'PUT', Rec."No.", '', Setup."Market Code")
    end;

    [BusinessEvent(false)]
    procedure SitooT32_OnAfterInsertEvent(var Rec : Record "Item Ledger Entry";RunTrigger : Boolean;var Handled : Boolean);
    begin
    end;

    [BusinessEvent(false)]
    procedure SitooT5401_OnBeforeInsertEvent(var Rec : Record "Item Variant";RunTrigger : Boolean;var Handled : Boolean);
    begin
    end;

    [BusinessEvent(false)]
    procedure SitooT5401_OnAfterInsertEvent(var Rec : Record "Item Variant";RunTrigger : Boolean;var Handled : Boolean);
    begin
    end;

    [BusinessEvent(false)]
    procedure SitooT5401_OnAfterDeleteEvent(var Rec : Record "Item Variant";RunTrigger : Boolean;var Handled : Boolean);
    begin
    end;

    [BusinessEvent(false)]
    procedure SitooT5717_OnAfterDeleteEvent(var Rec : Record "Item Cross Reference";RunTrigger : Boolean;var Handled : Boolean);
    begin
    end;

    [BusinessEvent(false)]
    procedure SitooT5717_OnAfterInsertEvent(var Rec : Record "Item Cross Reference";RunTrigger : Boolean;var Handled : Boolean);
    begin
    end;

    [BusinessEvent(false)]
    procedure SitooT5717_OnAfterModifyEvent(var Rec : Record "Item Cross Reference";RunTrigger : Boolean;var Handled : Boolean);
    begin
    end;

    [BusinessEvent(false)]
    procedure SitooT5717_OnAfterRenameEvent(var Rec : Record "Item Cross Reference";RunTrigger : Boolean;var Handled : Boolean);
    begin
    end;

    [BusinessEvent(false)]
    procedure SitooT51305_OnAfterInsertEvent(var Rec : Record "Sitoo Product";RunTrigger : Boolean;var Handled : Boolean);
    begin
    end;

    [BusinessEvent(false)]
    procedure SitooCU51301_OnBeforeGetMarketCode(LocationCode : Code[10];var MarketCode : Code[20];var Handled : Boolean);
    begin
        // Override GetMarketCode
    end;

    [BusinessEvent(false)]
    procedure SitooCU51301_OnBeforeGetComment(TableName : Option "G/L Account",Customer,Vendor,Item,Resource,Job,,"Resource Group","Bank Account",Campaign,"Fixed Asset",Insurance,"Nonstock Item","IC Partner";No : Code[20];var Comments : Text;var Handled : Boolean);
    begin
        // Override GetComment
    end;

    [BusinessEvent(false)]
    procedure SitooCU51307_OnBeforeSerializeAddToBaseProductList(var SitooOutboundQueue : Record "Sitoo Outbound Queue";var JsonMgt : Codeunit "Sitoo Json Mgt";var Handled : Boolean);
    begin
        // Use for overriding default product list
    end;

    [BusinessEvent(false)]
    procedure SitooCU51307_OnAfterSerializeAddToBaseProductList(var SitooOutboundQueue : Record "Sitoo Outbound Queue";var JsonMgt : Codeunit "Sitoo Json Mgt";var Handled : Boolean);
    begin
        // Use for adding extra Json when serializing default product list
    end;

    [BusinessEvent(false)]
    procedure SitooCU51307_OnBeforeSerializeProduct(var SitooProductId : Record "Sitoo Product";var SKU : Text;IsParent : Boolean;IsVariant : Boolean;var JsonMgt : Codeunit "Sitoo Json Mgt";var Handled : Boolean);
    begin
        // Use for adding extra Json when serializing default product
    end;

    [BusinessEvent(false)]
    procedure SitooCU51307_OnBeforeProductCustomFields(var SitooProductId : Record "Sitoo Product";var JsonMgt : Codeunit "Sitoo Json Mgt";var Handled : Boolean);
    begin
        // Adds extra fields for products
    end;

    [BusinessEvent(false)]
    procedure SitooCU51307_OnAfterSerializeOutbounds(var Setup : Record "Sitoo Setup");
    begin
        // Trigger extra SerializeOutbounds
    end;

    [BusinessEvent(false)]
    procedure SitoocU51307_OnBeforeGetItemDescription(ItemNo : Code[20];ColorCode : Code[20];SizeCode : Code[20];MarketCode : Code[20];var Description : Text;var Handled : Boolean);
    begin
        // Use for overriding GetVariantCode logic
    end;

    [BusinessEvent(false)]
    procedure SitoocU51307_OnBeforeGetShortDescription(ItemNo : Code[20];ColorCode : Code[20];SizeCode : Code[20];MarketCode : Code[20];var ShortDescription : Text;var Handled : Boolean);
    begin
        // Use for overriding GetVariantCode logic
    end;

    [BusinessEvent(false)]
    procedure SitoocU51307_OnBeforeGetVariantCode(ItemNo : Code[20];ColorCode : Code[20];SizeCode : Code[20];var VariantCode : Code[10];var Handled : Boolean);
    begin
        // Use for overriding GetVariantCode logic
    end;

    [BusinessEvent(false)]
    procedure SitooCU51307_OnBeforeGetBarcode(var SitooProductId : Record "Sitoo Product";var Barcode : Text;var Handled : Boolean);
    begin
        // Use for overriding GetBarcode logic
    end;

    [BusinessEvent(false)]
    procedure SitooCU51307_OnGetUnitListPrice(var SalesPriceTEMP : Record "Sales Price" temporary;ItemNo : Code[20];VariantCode : Code[20];CustNo : Code[20];CustPriceGrCode : Code[10];var UnitListPrice : Decimal;var Handled : Boolean);
    begin
        //
    end;

    [BusinessEvent(false)]
    procedure SitooCU51307_OnGetUnitPriceExclVAT(var SalesPriceTEMP : Record "Sales Price" temporary;ItemNo : Code[20];VariantCode : Code[20];CustNo : Code[20];CustPriceGrCode : Code[10];var Handled : Boolean);
    begin
        //
    end;

    [BusinessEvent(false)]
    procedure SitooCU51308_OnBeforeEndAddWhseBatchItems(var SitooOutboundQueueTEMP : Record "Sitoo Outbound Queue" temporary;var JsonMgt : Codeunit "Sitoo Json Mgt";var Item : Record Item);
    begin
        // Use for adding extra filters on Item
        // Use for adding extra Json
    end;
}

