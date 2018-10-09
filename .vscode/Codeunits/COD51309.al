codeunit 51309 "Sitoo Voucher Mgt"
{
    // version Sitoo 3.0


    trigger OnRun();
    begin
        SerializeOutbounds;
        COMMIT;
    end;

    var
        Text001 : TextConst ENU='%1 for %2',SVE='%1 för %2';
        Text002 : TextConst ENU='%1 for %2 kr',SVE='%1 för %2 kr';

    [TryFunction]
    procedure SerializeOutbounds();
    begin
        SerializeVouchers('POST');
        COMMIT;
        SerializeVouchers('PUT');
        COMMIT;
        SerializeVouchers('DELETE');
        COMMIT;
    end;

    local procedure SerializeVouchers("Action" : Code[10]);
    var
        Common : Codeunit "Sitoo Common";
        JsonMgt : Codeunit "Sitoo Json Mgt";
        String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
        SitooOutboundQueue : Record "Sitoo Outbound Queue";
        "Count" : Integer;
        EntryNo : Integer;
        LogEntry : Record "Sitoo Log Entry";
        TempSitooProductId : Record "Sitoo Product" temporary;
    begin
        // Count := 0;
        // SitooOutboundQueue.SETRANGE(Type, 'OFFERING');
        // SitooOutboundQueue.SETRANGE(Action, Action);
        // IF SitooOutboundQueue.FINDSET(TRUE, TRUE) THEN BEGIN
        //  REPEAT
        //    IF SerializeOffering(SitooOutboundQueue, Action) THEN;
        //    SitooOutboundQueue.DELETE;
        //    Count += 1;
        //  UNTIL SitooOutboundQueue.NEXT = 0;
        // END;
        //
        // SitooOutboundQueue.SETRANGE(Type, 'MIX&MATCH');
        // SitooOutboundQueue.SETRANGE(Action, Action);
        // IF SitooOutboundQueue.FINDSET(TRUE, TRUE) THEN BEGIN
        //  REPEAT
        //    IF SerializeMixnMatch(SitooOutboundQueue, Action) THEN;
        //    SitooOutboundQueue.DELETE;
        //    Count += 1;
        //  UNTIL SitooOutboundQueue.NEXT = 0;
        // END;
    end;

    [TryFunction]
    local procedure SerializeOffering(var SitooOutboundQueue : Record "Sitoo Outbound Queue";"Action" : Code[10]);
    var
        SitooProductId : Record "Sitoo Product";
        JsonMgt : Codeunit "Sitoo Json Mgt";
        Common : Codeunit "Sitoo Common";
        String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
        ItemNo : Code[20];
        StartDate : Date;
        EndDate : Date;
        StartTimestamp : Integer;
        EndTimestamp : Integer;
        ProductId : Integer;
        VoucherName : Text;
    begin
        // ItemNo := SitooOutboundQueue."Primary Key 1";
        // StartDate := SitooOutboundQueue."Date 1";
        // EndDate := SitooOutboundQueue."Date 2";
        //
        // IF NOT SitooProductId.GET(ItemNo) THEN
        //  EXIT;
        //
        // VoucherName := ItemNo + ' ' + FORMAT(StartDate) + '-' + FORMAT(EndDate);
        //
        // IF StartDate <> 0D THEN
        //  EVALUATE(StartTimestamp, Common.DateToTimestamp(StartDate));
        // IF EndDate <> 0D THEN
        //  EVALUATE(EndTimestamp, Common.DateToTimestamp(EndDate));
        //
        // //IF NOT ExtendaItemPrice.GET(ItemNo, ExtendaItemPrice.Type::"1", StartDate, '') THEN
        // //  EXIT;
        //
        // ProductId := SitooProductId."Product Id";
        //
        // JsonMgt.StartJSon;
        // JsonMgt.AddIntProperty('vouchertype', 220);
        // JsonMgt.AddToJSon('vouchername', VoucherName);
        // IF StartTimestamp <> 0 THEN
        //  JsonMgt.AddIntProperty('datestart', StartTimestamp);
        // IF EndTimestamp <> 0 THEN
        //  JsonMgt.AddIntProperty('dateend', EndTimestamp);
        // JsonMgt.AddIntProperty('value_x', 1);
        // //JsonMgt.AddToJSon('money_m', FORMAT(ExtendaItemPrice."Unit Price Incl. VAT", 0, '<Precision,2:2><Standard Format,2>'));
        // JsonMgt.AddProperty('products');
        // JsonMgt.StartJSonArray;
        // JsonMgt.AddValue(ProductId);
        // JsonMgt.WriteEnd;
        // JsonMgt.EndJSon;
        //
        // String := JsonMgt.GetJSon;
        //
        // Common.AddOutboundLogEntry(String, 'VOUCHER', 'SerializeOffering', ItemNo, Action);
    end;

    [TryFunction]
    local procedure SerializeMixnMatch(var SitooOutboundQueue : Record "Sitoo Outbound Queue";"Action" : Code[10]);
    var
        SitooProductId : Record "Sitoo Product";
        JsonMgt : Codeunit "Sitoo Json Mgt";
        Common : Codeunit "Sitoo Common";
        String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
        "Code" : Code[20];
        ItemNo : Code[20];
        StartDate : Date;
        EndDate : Date;
        StartTimestamp : Integer;
        EndTimestamp : Integer;
        ProductId : Integer;
        VoucherName : Text;
        IntValue : Integer;
        Name : Text;
    begin
        /*
        Code := SitooOutboundQueue."Primary Key 1";
        
        JsonMgt.StartJSon;
        IF (Action = 'POST') OR (Action = 'PUT') THEN BEGIN
          IF NOT ExtendaMixMatchHeader.GET(Code) THEN
            EXIT;
        
          IF ExtendaMixMatchHeader."Currency Code" <> '' THEN
            EXIT;
        
          ExtendaMixMatchLine.SETRANGE("Mix & Match Code", Code);
          IF NOT ExtendaMixMatchLine.FINDSET THEN
            EXIT;
        
          StartDate := ExtendaMixMatchHeader."Starting Date";
          EndDate := ExtendaMixMatchHeader."Ending Date";
        
          IF StartDate <> 0D THEN
            EVALUATE(StartTimestamp, Common.DateToTimestamp(StartDate));
          IF EndDate <> 0D THEN
            EVALUATE(EndTimestamp, Common.DateToTimestamp(EndDate));
        
          Name := ExtendaMixMatchHeader.Description + ' - ';
          IF ExtendaMixMatchHeader.Type = ExtendaMixMatchHeader.Type::"0" THEN
            Name += STRSUBSTNO(Text001, ExtendaMixMatchHeader.Quantity, ExtendaMixMatchHeader.Value);
          IF ExtendaMixMatchHeader.Type = ExtendaMixMatchHeader.Type::"1" THEN
            Name += STRSUBSTNO(Text002, ExtendaMixMatchHeader.Quantity, ExtendaMixMatchHeader.Value);
        
          JsonMgt.AddToJSon('vouchercode', Code);
          JsonMgt.AddToJSon('vouchername', Name);
          IF StartTimestamp <> 0 THEN
            JsonMgt.AddIntProperty('datestart', StartTimestamp);
          IF EndTimestamp <> 0 THEN
            JsonMgt.AddIntProperty('dateend', EndTimestamp);
        
          IF ExtendaMixMatchHeader.Type = ExtendaMixMatchHeader.Type::"1" THEN BEGIN
            JsonMgt.AddIntProperty('vouchertype', 220);
            JsonMgt.AddIntProperty('value_x', ExtendaMixMatchHeader.Quantity);
            JsonMgt.AddToJSon('money_m', FORMAT(ExtendaMixMatchHeader.Value, 0, '<Precision,2:2><Standard Format,2>'));
          END;
        
          IF ExtendaMixMatchHeader.Type = ExtendaMixMatchHeader.Type::"0" THEN BEGIN
            JsonMgt.AddIntProperty('vouchertype', 230);
            //EVALUATE(DecValue, FORMAT(ExtendaMixMatchHeader.Value));
            IntValue := ROUND(ExtendaMixMatchHeader.Value, 1);
            JsonMgt.AddIntProperty('value_x', ExtendaMixMatchHeader.Quantity);
            JsonMgt.AddIntProperty('value_y', IntValue);
        
          END;
        
          JsonMgt.AddProperty('products');
          JsonMgt.StartJSonArray;
          ExtendaMixMatchLine.SETRANGE("Mix & Match Code", Code);
          IF ExtendaMixMatchLine.FINDSET THEN BEGIN
            REPEAT
              IF SitooProductId.GET(ExtendaMixMatchLine."Item No.") THEN
                JsonMgt.AddValue(SitooProductId."Size Code");
            UNTIL ExtendaMixMatchLine.NEXT = 0;
          END;
        
          JsonMgt.WriteEnd;
        
        END;
        
        JsonMgt.EndJSon;
        
        String := JsonMgt.GetJSon;
        
        Common.AddOutboundLogEntry(String, 'VOUCHER', 'SerializeMixnMatch', Code, Action);
        */

    end;

    procedure SendVoucher(var SitooLogEntry : Record "Sitoo Log Entry") : Integer;
    var
        Setup : Record "Sitoo Setup";
        Common : Codeunit "Sitoo Common";
        String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
        Status : Integer;
        SitooProductId : Record "Sitoo Product";
    begin
        Setup.GET;

        if SitooLogEntry.Action = 'POST' then
          Status := Common.UploadLogEntry(SitooLogEntry, 'SendVoucher', true, Setup."Base URL" + FORMAT(Setup."Site Id") + '/vouchers.json');
        if SitooLogEntry.Action = 'PUT' then
          Status := Common.UploadLogEntry(SitooLogEntry, 'SendVoucher', false, Setup."Base URL" + FORMAT(Setup."Site Id") + '/vouchers/' + FORMAT(GetVoucherId(SitooLogEntry)) + '.json');
        if SitooLogEntry.Action = 'DELETE' then
          Status := Common.UploadLogEntry(SitooLogEntry, 'SendVoucher', false, Setup."Base URL" + FORMAT(Setup."Site Id") + '/vouchers/' + SitooLogEntry."Document No." + '.json');


        if Status > 0 then begin
          SitooLogEntry.Status := SitooLogEntry.Status::Processed;
          SitooLogEntry.MODIFY;
        end;

        exit(Status);
    end;

    procedure SaveVoucherId(var SitooLogEntry : Record "Sitoo Log Entry");
    var
        Common : Codeunit "Sitoo Common";
        RequestPostingExchField : Record "Data Exch. Field" temporary;
        ResponsePostingExchField : Record "Data Exch. Field" temporary;
        SitooProductId : Record "Sitoo Product";
        Item : Record Item;
        VoucherId : Integer;
        VoucherName : Text;
        StartDateTime : DateTime;
        StartDate : Date;
        ProductId : Integer;
    begin
        /*
        Common.GetRequestRecords(SitooLogEntry, RequestPostingExchField, '');
        Common.GetResponseRecords(SitooLogEntry, ResponsePostingExchField, '');
        
        ResponsePostingExchField.FINDFIRST;
        EVALUATE(VoucherId, ResponsePostingExchField.Value);
        
        VoucherName := Common.GetValue(RequestPostingExchField, 'vouchercode');
        
        IF (STRLEN(VoucherName) <= MAXSTRLEN(ExtendaMixMatchHeader.Code)) THEN
          IF (ExtendaMixMatchHeader.GET(VoucherName)) THEN BEGIN
          ExtendaMixMatchHeader."Sitoo Voucher Id" := VoucherId;
          ExtendaMixMatchHeader.MODIFY;
        END ELSE BEGIN
          ProductId := Common.GetInt(RequestPostingExchField, 'products');
        
          Common.FieldExists(RequestPostingExchField, 'datestart');
          StartDateTime := Common.GetDateTime(RequestPostingExchField, 'datestart');
          StartDate := DT2DATE(StartDateTime);
        
          SitooProductId.SETRANGE("Size Code", ProductId);
          SitooProductId.FINDFIRST;
        
          Item.GET(SitooProductId."No.");
        
          ExtendaItemPrice.GET(Item."No.", ExtendaItemPrice.Type::"1", StartDate, '');
        
          ExtendaItemPrice."Sitoo Voucher Id" := VoucherId;
          ExtendaItemPrice.MODIFY;
        END;
        
        SitooLogEntry.Status := SitooLogEntry.Status::Processed;
        SitooLogEntry.MODIFY;
        */

    end;

    procedure GetVoucherId(var SitooLogEntry : Record "Sitoo Log Entry") : Integer;
    var
        Common : Codeunit "Sitoo Common";
        RequestPostingExchField : Record "Data Exch. Field" temporary;
        ResponsePostingExchField : Record "Data Exch. Field" temporary;
        SitooProductId : Record "Sitoo Product";
        Item : Record Item;
        VoucherId : Integer;
        VoucherName : Text;
        StartDateTime : DateTime;
        StartDate : Date;
        ProductId : Integer;
    begin
        /*
        Common.GetRequestRecords(SitooLogEntry, RequestPostingExchField, '');
        
        VoucherName := Common.GetValue(RequestPostingExchField, 'vouchercode');
        
        IF ExtendaMixMatchHeader.GET(VoucherName) THEN
          EXIT(ExtendaMixMatchHeader."Sitoo Voucher Id")
        ELSE BEGIN
          ProductId := Common.GetInt(RequestPostingExchField, 'products');
        
          Common.FieldExists(RequestPostingExchField, 'datestart');
          StartDateTime := Common.GetDateTime(RequestPostingExchField, 'datestart');
          StartDate := DT2DATE(StartDateTime);
        
          SitooProductId.SETRANGE("Size Code", ProductId);
          SitooProductId.FINDFIRST;
        
          Item.GET(SitooProductId."No.");
        
          ExtendaItemPrice.GET(Item."No.", ExtendaItemPrice.Type::"1", StartDate, '');
        
          EXIT(ExtendaItemPrice."Sitoo Voucher Id");
        END;
        
        EXIT(-1);
        */

    end;
}

