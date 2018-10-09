codeunit 51321 "Sitoo PFVariant Events"
{
    // version Sitoo 3.0,SitooPF


    trigger OnRun();
    begin
    end;

    var
        Common : Codeunit "Sitoo Common";

    [EventSubscriber(ObjectType::Codeunit, 51311, 'SitooT32_OnAfterInsertEvent', '', false, false)]
    local procedure SitooT32_OnAfterInsertEvent(var Rec : Record "Item Ledger Entry";RunTrigger : Boolean;var Handled : Boolean);
    var
        Setup : Record "Sitoo Setup";
        SitooWarehouse : Record "Sitoo Warehouse";
        SKU : Text;
    begin
        if not Setup.GET(Common.GetMarketCode(Rec."Location Code")) then
          exit;

        if not UseVariants(Setup."Market Code") then
          exit;

        SitooWarehouse.SETRANGE("Market Code", Setup."Market Code");
        SitooWarehouse.SETRANGE("Location Code", Rec."Location Code");
        if SitooWarehouse.FINDFIRST then begin
          if Rec."Variant Code" <> '' then
            SKU := Rec."Item No." + '_' + Rec."PFVertical Component" + '-' + Rec."PFHorizontal Component"
          else
            SKU := Rec."Item No.";

          Common.AddQueueMessage('WAREHOUSE', 'STOCK', '', SKU, Rec."Location Code", Setup."Market Code");
        end;

        Handled := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, 51311, 'SitooT5401_OnAfterDeleteEvent', '', false, false)]
    local procedure SitooT5401_OnAfterDeleteEvent(var Rec : Record "Item Variant";RunTrigger : Boolean;var Handled : Boolean);
    var
        PFVertComponentBase : Record "PFVert Component Base";
        Setup : Record "Sitoo Setup";
    begin
        if PFVertComponentBase.GET(Rec."PFVertical Component") then begin
          Setup.SETRANGE(Active, true);
          Setup.SETRANGE("Send Items", true);
          Setup.SETRANGE("Use Variants", true);
          if Setup.FINDSET then
            repeat
              Common.AddQueueMessage('PRODUCT', 'ITEM', 'DELETE', Rec."Item No.", Rec."PFVertical Component", Setup."Market Code");
            until Setup.NEXT = 0;
        end;

        Handled := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, 51311, 'SitooT5401_OnAfterInsertEvent', '', false, false)]
    local procedure SitooT5401_OnAfterInsertEvent(var Rec : Record "Item Variant";RunTrigger : Boolean;var Handled : Boolean);
    var
        PFVertComponentBase : Record "PFVert Component Base";
        Setup : Record "Sitoo Setup";
    begin
        if PFVertComponentBase.GET(Rec."PFVertical Component") then begin
          Setup.SETRANGE(Active, true);
          Setup.SETRANGE("Send Items", true);
          Setup.SETRANGE("Use Variants", true);
          if Setup.FINDSET then
            repeat
              Common.AddQueueMessage('PRODUCT', 'ITEM', 'POST', Rec."Item No.", Rec."PFVertical Component", Setup."Market Code");
            until Setup.NEXT = 0;
        end;

        Handled := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, 51311, 'SitooT5401_OnBeforeInsertEvent', '', false, false)]
    local procedure SitooT5401_OnBeforeInsertEvent(var Rec : Record "Item Variant";RunTrigger : Boolean;var Handled : Boolean);
    var
        Common : Codeunit "Sitoo Common";
        Setup : Record "Sitoo Setup";
    begin
        Setup.SETRANGE(Active, true);
        Setup.SETRANGE("Send Items", true);
        Setup.SETRANGE("Use Variants", true);
        if Setup.FINDFIRST then
          Common.CheckVariant(Rec.Code);

        Handled := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, 51311, 'SitooT5717_OnAfterDeleteEvent', '', false, false)]
    local procedure SitooT5717_OnAfterDeleteEvent(var Rec : Record "Item Cross Reference";RunTrigger : Boolean;var Handled : Boolean);
    var
        ItemVariant : Record "Item Variant";
        Setup : Record "Sitoo Setup";
    begin
        Setup.SETRANGE(Active, true);
        Setup.SETRANGE("Send Items", true);
        Setup.SETRANGE("Use Variants", true);
        if Setup.FINDSET then
          repeat
            if ItemVariant.GET(Rec."Item No.", Rec."Variant Code") then
              Common.AddQueueMessage('PRODUCT', 'VARIANT', 'PUT', ItemVariant."Item No.", ItemVariant."PFVertical Component", Setup."Market Code")
            else
              Common.AddQueueMessage('PRODUCT', 'ITEM', 'PUT', Rec."Item No.", '', Setup."Market Code");
          until Setup.NEXT = 0;

        Handled := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, 51311, 'SitooT5717_OnAfterInsertEvent', '', false, false)]
    local procedure SitooT5717_OnAfterInsertEvent(var Rec : Record "Item Cross Reference";RunTrigger : Boolean;var Handled : Boolean);
    var
        ItemVariant : Record "Item Variant";
        Setup : Record "Sitoo Setup";
    begin
        Setup.SETRANGE(Active, true);
        Setup.SETRANGE("Send Items", true);
        Setup.SETRANGE("Use Variants", true);
        if Setup.FINDSET then
          repeat
            if ItemVariant.GET(Rec."Item No.", Rec."Variant Code") then
              Common.AddQueueMessage('PRODUCT', 'VARIANT', 'PUT', ItemVariant."Item No.", ItemVariant."PFVertical Component", Setup."Market Code")
            else
              Common.AddQueueMessage('PRODUCT', 'ITEM', 'PUT', Rec."Item No.", '', Setup."Market Code");
          until Setup.NEXT = 0;

        Handled := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, 51311, 'SitooT5717_OnAfterModifyEvent', '', false, false)]
    local procedure SitooT5717_OnAfterModifyEvent(var Rec : Record "Item Cross Reference";RunTrigger : Boolean;var Handled : Boolean);
    var
        ItemVariant : Record "Item Variant";
        Setup : Record "Sitoo Setup";
    begin
        Setup.SETRANGE(Active, true);
        Setup.SETRANGE("Send Items", true);
        Setup.SETRANGE("Use Variants", true);
        if Setup.FINDSET then
          repeat
            if ItemVariant.GET(Rec."Item No.", Rec."Variant Code") then
              Common.AddQueueMessage('PRODUCT', 'VARIANT', 'PUT', ItemVariant."Item No.", ItemVariant."PFVertical Component", Setup."Market Code")
            else
              Common.AddQueueMessage('PRODUCT', 'ITEM', 'PUT', Rec."Item No.", '', Setup."Market Code");
          until Setup.NEXT = 0;

        Handled := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, 51311, 'SitooT5717_OnAfterRenameEvent', '', false, false)]
    local procedure SitooT5717_OnAfterRenameEvent(var Rec : Record "Item Cross Reference";RunTrigger : Boolean;var Handled : Boolean);
    var
        ItemVariant : Record "Item Variant";
        Setup : Record "Sitoo Setup";
    begin
        Setup.SETRANGE(Active, true);
        Setup.SETRANGE("Send Items", true);
        Setup.SETRANGE("Use Variants", true);
        if Setup.FINDSET then
          repeat
            if ItemVariant.GET(Rec."Item No.", Rec."Variant Code") then
              Common.AddQueueMessage('PRODUCT', 'VARIANT', 'PUT', ItemVariant."Item No.", ItemVariant."PFVertical Component", Setup."Market Code")
            else
              Common.AddQueueMessage('PRODUCT', 'ITEM', 'PUT', Rec."Item No.", '', Setup."Market Code");
          until Setup.NEXT = 0;

        Handled := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, 51311, 'SitooT51305_OnAfterInsertEvent', '', false, false)]
    local procedure SitooT51305_OnAfterInsertEvent(var Rec : Record "Sitoo Product";RunTrigger : Boolean;var Handled : Boolean);
    var
        PFVertComponentGroup : Record "PFVert Component Group";
    begin
        if not UseVariants(Rec."Market Code") then
          exit;

        if RunTrigger then begin
          if Rec."Color Code" <> '' then
            Common.AddQueueMessage('PRODUCT', 'VARIANT', 'PUT', Rec."No.", Rec."Color Code", Rec."Market Code")
          else
            Common.AddQueueMessage('PRODUCT', 'ITEM', 'PUT', Rec."No.", '', Rec."Market Code")
        end;

        Handled := true;
    end;

    local procedure UseVariants(MarketCode : Code[20]) : Boolean;
    var
        Setup : Record "Sitoo Setup";
    begin
        if Setup.GET(MarketCode) then
          exit(Setup."Use Variants");
    end;

    [EventSubscriber(ObjectType::Codeunit, 51311, 'SitooCU51307_OnBeforeSerializeAddToBaseProductList', '', false, false)]
    local procedure SitooCU51307_OnBeforeSerializeAddToBaseProductList(var SitooOutboundQueue : Record "Sitoo Outbound Queue";var JsonMgt : Codeunit "Sitoo Json Mgt";var Handled : Boolean);
    var
        SitooPFVariantMgt : Codeunit "Sitoo PFVariant Mgt";
    begin
        SitooPFVariantMgt.SerializeAddToBaseProductList(SitooOutboundQueue, JsonMgt);
        Handled := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, 51311, 'SitooCU51307_OnBeforeSerializeProduct', '', false, false)]
    local procedure SitooCU51307_OnBeforeSerializeProduct(var SitooProductId : Record "Sitoo Product";var SKU : Text;IsParent : Boolean;IsVariant : Boolean;var JsonMgt : Codeunit "Sitoo Json Mgt";var Handled : Boolean);
    var
        SitooPFVariantMgt : Codeunit "Sitoo PFVariant Mgt";
    begin
        SitooPFVariantMgt.SerializeProduct(SitooProductId, SKU, IsParent, IsVariant, JsonMgt);
        Handled := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, 51311, 'SitooCU51307_OnAfterSerializeOutbounds', '', false, false)]
    local procedure SitooCU51307_OnAfterSerializeOutbounds(var Setup : Record "Sitoo Setup");
    var
        SitooPFVariantMgt : Codeunit "Sitoo PFVariant Mgt";
    begin
        SitooPFVariantMgt.SerializeOutbounds(Setup);
    end;

    [EventSubscriber(ObjectType::Codeunit, 51311, 'SitooCU51307_OnBeforeGetBarcode', '', false, false)]
    local procedure SitooCU51307_OnBeforeGetBarcode(var SitooProductId : Record "Sitoo Product";var Barcode : Text;var Handled : Boolean);
    var
        SitooPFVariantMgt : Codeunit "Sitoo PFVariant Mgt";
    begin
        Barcode := SitooPFVariantMgt.GetBarcode(SitooProductId);
        Handled := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, 51311, 'SitooCU51308_OnBeforeEndAddWhseBatchItems', '', false, false)]
    local procedure SitooCU51308_OnBeforeEndAddWhseBatchItems(var SitooOutboundQueueTEMP : Record "Sitoo Outbound Queue" temporary;var JsonMgt : Codeunit "Sitoo Json Mgt";var Item : Record Item);
    var
        SitooPFVariantMgt : Codeunit "Sitoo PFVariant Mgt";
    begin
        SitooPFVariantMgt.AddWhseBatchItems(SitooOutboundQueueTEMP, JsonMgt, Item);
    end;

    [EventSubscriber(ObjectType::Codeunit, 51311, 'SitoocU51307_OnBeforeGetVariantCode', '', false, false)]
    local procedure SitooCU51307_OnBeforeGetVariantCode(ItemNo : Code[20];ColorCode : Code[20];SizeCode : Code[20];var VariantCode : Code[10];var Handled : Boolean);
    var
        SitooPFVariantMgt : Codeunit "Sitoo PFVariant Mgt";
    begin
        VariantCode := SitooPFVariantMgt.GetVariantCode(ItemNo, ColorCode, SizeCode);
        Handled := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, 51311, 'SitoocU51307_OnBeforeGetItemDescription', '', false, false)]
    local procedure SitoocU51307_OnBeforeGetItemDescription(ItemNo : Code[20];ColorCode : Code[20];SizeCode : Code[20];MarketCode : Code[20];var Description : Text;var Handled : Boolean);
    var
        SitooPFVariantMgt : Codeunit "Sitoo PFVariant Mgt";
    begin
        Description := SitooPFVariantMgt.GetItemDescription(ItemNo, ColorCode, SizeCode, MarketCode);
        Handled := true;
    end;
}

