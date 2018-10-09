codeunit 51305 "Sitoo Order Mgt"
{
    // version Sitoo 3.0


    trigger OnRun();
    var
        Setup : Record "Sitoo Setup";
        Common : Codeunit "Sitoo Common";
        NextCheck : DateTime;
    begin
        Setup.SETRANGE(Active, true);
        if Setup.FINDSET then
          repeat
            if Setup."Get Sales Orders" then begin
              NextCheck := Setup."Last Get Sales Orders" + Setup."Get Sales Orders Interval" * 60000;
              if (CURRENTDATETIME > NextCheck) or (GUIALLOWED) then begin
                GetOrders(Setup);
                Setup."Last Get Sales Orders" := CURRENTDATETIME;
                Setup.MODIFY;
              end;
            end;

            if Setup."Get Sales Invoices" then begin
              NextCheck := Setup."Last Get Sales Invoices" + Setup."Get Sales Invoices Interval" * 60000;
              if (CURRENTDATETIME > NextCheck) or (GUIALLOWED) then begin
                GetInvoices(Setup);
                Setup."Last Get Sales Invoices" := CURRENTDATETIME;
                Setup.MODIFY;
              end;
            end;
            COMMIT;
          until Setup.NEXT = 0;
    end;

    procedure ProcessInbound(var SitooLogEntry : Record "Sitoo Log Entry");
    begin
        case SitooLogEntry."Sub Type" of
          'LIST': ParseOrderList(SitooLogEntry);
          'ORDER': ParseOrder(SitooLogEntry);
        end;
    end;

    procedure ProcessOutbound(var SitooLogEntry : Record "Sitoo Log Entry") : Integer;
    begin
    end;

    procedure GetOrders(var Setup : Record "Sitoo Setup");
    var
        Common : Codeunit "Sitoo Common";
        NextOrderId : Integer;
        URL : Text;
    begin

        NextOrderId := GetNextOrderId(Setup);

        URL := Setup."Base URL" + 'sites/' + FORMAT(Setup."Site Id") + '/orders.json?orderidfrom=' + FORMAT(NextOrderId) +
          '&num=' + FORMAT(Setup."Number of Sales Orders to Get") + Setup."Order Filter" + '&sort=orderid';

        Common.Download(URL, 'ORDER', 'LIST', 'GetOrders', '', Setup."Market Code");
    end;

    procedure GetInvoices(var Setup : Record "Sitoo Setup");
    var
        Common : Codeunit "Sitoo Common";
        NextOrderId : Integer;
        URL : Text;
    begin

        NextOrderId := GetNextInvoiceId(Setup);

        URL := Setup."Base URL" + 'sites/' + FORMAT(Setup."Site Id") + '/orders.json?orderidfrom=' + FORMAT(NextOrderId) +
          '&num=' + FORMAT(Setup."Number of Sales Inv. to Get") + Setup."Invoice Filter" + '&sort=orderid';

        Common.Download(URL, 'ORDER', 'LIST', 'GetInvoices', '', Setup."Market Code");
    end;

    procedure GetOrder(var SitooOrder : Record "Sitoo Order");
    var
        Setup : Record "Sitoo Setup";
        Common : Codeunit "Sitoo Common";
        EntryNo : Integer;
        LogEntry : Record "Sitoo Log Entry";
        URL : Text;
    begin

        Setup.GET(SitooOrder."Market Code");

        if SitooOrder."Nav Status" = SitooOrder."Nav Status"::Posted then
          ERROR('Order is already posted');

        URL := Setup."Base URL"+ 'sites/' + FORMAT(Setup."Site Id") +  '/orders/' + FORMAT(SitooOrder.orderid) + '.json';

        EntryNo := Common.Download(URL, 'ORDER', 'ORDER', 'GetOrders', '', Setup."Market Code");

        LogEntry.GET(EntryNo);

        ParseOrder(LogEntry);
    end;

    procedure ParseOrderList(var LogEntry : Record "Sitoo Log Entry");
    var
        Common : Codeunit "Sitoo Common";
        Counter : Integer;
        OrderId : Integer;
        XmlDocument : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlDocument";
        XmlOrderList : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNodeList";
        XmlOrderElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        ProgressWindow : Dialog;
        SitooOrder : Record "Sitoo Order";
    begin
        Common.GetResponseXML(LogEntry, XmlDocument);

        XmlOrderList := XmlDocument.GetElementsByTagName('items');

        if XmlOrderList.Count > 0 then begin
          Counter := 0;

          if GUIALLOWED then
            ProgressWindow.OPEN('Processing order #1#######');

          repeat
            XmlOrderElement := XmlOrderList.Item(Counter);

            if GUIALLOWED then
              ProgressWindow.UPDATE(1, FORMAT(OrderId));

            SaveOrder(XmlOrderElement, LogEntry);

            Counter += 1;
          until Counter = XmlOrderList.Count;

          if GUIALLOWED then
            ProgressWindow.CLOSE;
        end;

        LogEntry.Information := FORMAT(Counter) + ' orders';
        LogEntry.Status := LogEntry.Status::Processed;
        LogEntry.MODIFY;

        if Counter = 0 then
          LogEntry.DELETE;
    end;

    local procedure ParseOrder(var LogEntry : Record "Sitoo Log Entry");
    var
        Common : Codeunit "Sitoo Common";
        XmlDocument : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlDocument";
        XmlRootElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        XmlOrderElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        ProgressWindow : Dialog;
        OrderId : Integer;
    begin
        Common.GetResponseXML(LogEntry, XmlDocument);

        if GUIALLOWED then
          ProgressWindow.OPEN('Processing order #1#######');

        XmlRootElement := XmlDocument.DocumentElement;

        XmlOrderElement := XmlRootElement.SelectSingleNode('root');

        OrderId := Common.GetIntXML(XmlOrderElement, 'orderid');

        SaveOrder(XmlOrderElement, LogEntry);

        LogEntry.Information := FORMAT(OrderId);
        LogEntry.Status := LogEntry.Status::Processed;
        LogEntry.MODIFY;
    end;

    local procedure SaveOrder(var XmlOrderElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";var SitooLogEntry : Record "Sitoo Log Entry");
    var
        Setup : Record "Sitoo Setup";
        OrderId : Integer;
        SitooOrder : Record "Sitoo Order";
        GetCompleteOrder : Boolean;
        Common : Codeunit "Sitoo Common";
    begin
        Setup.GET(SitooLogEntry."Market Code");

        OrderId := Common.GetIntXML(XmlOrderElement, 'orderid');

        GetCompleteOrder := SaveOrderHeader(OrderId, XmlOrderElement, SitooLogEntry);

        SitooOrder.GET(OrderId, SitooLogEntry."Market Code");

        SaveOrderItems(SitooOrder, XmlOrderElement);

        SaveOrderPayments(SitooOrder, XmlOrderElement);

        if UPPERCASE(SitooOrder.checkouttypename) = 'FAKTURA' then
          SetLastInvoiceId(Setup, OrderId)
        else
          SetLastOrderId(Setup, OrderId);

        if GetCompleteOrder then
          GetOrder(SitooOrder)
        else
          SetReady(SitooOrder);
    end;

    local procedure SaveOrderHeader(OrderId : Integer;var XmlOrderElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";var LogEntry : Record "Sitoo Log Entry") : Boolean;
    var
        Common : Codeunit "Sitoo Common";
        SitooOrder : Record "Sitoo Order";
        GetCompleteOrder : Boolean;
    begin
        //IF NOT SitooOrder.GET(OrderId) THEN BEGIN
        if not SitooOrder.GET(OrderId, LogEntry."Market Code") then begin //MAJO
          SitooOrder.INIT;
          SitooOrder.orderid := OrderId;
          SitooOrder."Market Code" := LogEntry."Market Code";
          SitooOrder."Nav Status" := SitooOrder."Nav Status"::New;
          SitooOrder.checkouttypename := Common.GetValueXML(XmlOrderElement, 'checkouttypename');
          SitooOrder.INSERT;

          if UPPERCASE(SitooOrder.checkouttypename) = 'FAKTURA' then
            GetCompleteOrder := true;
        end;

        SitooOrder.orderdate := Common.GetDateTimeXML(XmlOrderElement, 'orderdate');
        SitooOrder.orderstateid := Common.GetIntXML(XmlOrderElement, 'orderstateid');
        SitooOrder.paymentstateid := Common.GetIntXML(XmlOrderElement, 'paymentstateid');
        SitooOrder.checkouttypeid := Common.GetIntXML(XmlOrderElement, 'checkouttypeid');
        SitooOrder.checkouttypename := Common.GetValueXML(XmlOrderElement, 'checkouttypename');
        SitooOrder.deliverytypeid := Common.GetIntXML(XmlOrderElement, 'deliverytypeid');
        SitooOrder.moneytotal_net := Common.GetDecimalXML(XmlOrderElement, 'moneytotal_net');
        SitooOrder.moneytotal_vat := Common.GetDecimalXML(XmlOrderElement, 'moneytotal_vat');
        SitooOrder.moneyfinal_net := Common.GetDecimalXML(XmlOrderElement, 'moneyfinal_net');
        SitooOrder.moneyfinal_vat := Common.GetDecimalXML(XmlOrderElement, 'moneyfinal_vat');
        SitooOrder.moneytotal_gross_roundoff := Common.GetDecimalXML(XmlOrderElement, 'moneytotal_gross_roundoff');
        SitooOrder.moneytotal_gross_all := Common.GetDecimalXML(XmlOrderElement, 'moneytotal_gross_all');
        SitooOrder.ordertypeid := Common.GetIntXML(XmlOrderElement, 'ordertypeid');
        SitooOrder.registerid := Common.GetValueXML(XmlOrderElement, 'registerid');
        SitooOrder.warehouseid := Common.GetIntXML(XmlOrderElement, 'warehouseid');
        SitooOrder.email := Common.GetValueXML(XmlOrderElement, 'email');
        SitooOrder.namefirst := Common.GetValueXML(XmlOrderElement, 'namefirst');
        SitooOrder.namelast := Common.GetValueXML(XmlOrderElement, 'namelast');
        SitooOrder.personalid := Common.GetValueXML(XmlOrderElement, 'personalid');
        SitooOrder.company := Common.GetValueXML(XmlOrderElement, 'company');
        SitooOrder.phone := Common.GetValueXML(XmlOrderElement, 'phone');
        SitooOrder.invoice_address := Common.GetValueXML(XmlOrderElement, 'invoice_address');
        SitooOrder.invoice_address2 := Common.GetValueXML(XmlOrderElement, 'invoice_address2');
        SitooOrder.invoice_zip := Common.GetValueXML(XmlOrderElement, 'invoice_zip');
        SitooOrder.invoice_city := Common.GetValueXML(XmlOrderElement, 'invoice_city');
        SitooOrder.invoice_state := Common.GetValueXML(XmlOrderElement, 'invoice_state');
        SitooOrder.invoice_countryid := Common.GetValueXML(XmlOrderElement, 'invoice_countryid');
        SitooOrder.delivery_address := Common.GetValueXML(XmlOrderElement, 'delivery_address');
        SitooOrder.delivery_address2 := Common.GetValueXML(XmlOrderElement, 'delivery_address2');
        SitooOrder.delivery_zip := Common.GetValueXML(XmlOrderElement, 'delivery_zip');
        SitooOrder.delivery_city := Common.GetValueXML(XmlOrderElement, 'delivery_city');
        SitooOrder.delivery_state := Common.GetValueXML(XmlOrderElement, 'delivery_state');
        SitooOrder.delivery_countryid := Common.GetValueXML(XmlOrderElement, 'delivery_countryid');
        SitooOrder.comment := Common.GetValueXML(XmlOrderElement, 'comment');
        SitooOrder.commentinternal := Common.GetValueXML(XmlOrderElement, 'commentinternal');
        SitooOrder.customerref := Common.GetValueXML(XmlOrderElement, 'customerref');
        SitooOrder.checkoutref := Common.GetValueXML(XmlOrderElement, 'checkoutref');

        SitooOrder."Source Entry No." := LogEntry."Entry No.";

        SitooOrder.MODIFY;

        exit(GetCompleteOrder);
    end;

    local procedure SaveOrderItems(var SitooOrder : Record "Sitoo Order";var XmlOrderElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode");
    var
        Common : Codeunit "Sitoo Common";
        SitooItem : Record "Sitoo Order Line";
        XmlItemList : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNodeList";
        XmlItemElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        Counter : Integer;
        ItemId : Integer;
    begin
        XmlItemList := XmlOrderElement.SelectNodes('orderitems');

        if XmlItemList.Count > 0 then begin
          Counter := 0;
          repeat
            XmlItemElement := XmlItemList.Item(Counter);
            ItemId := Common.GetIntXML(XmlItemElement, 'orderitemid');
            if not SitooItem.GET(SitooOrder.orderid, ItemId) then begin
              SitooItem.INIT;
              SitooItem.orderid := SitooOrder.orderid;
              SitooItem.orderitemid := ItemId;
              SitooItem."Market Code" := SitooOrder."Market Code";
              SitooItem.Type := SitooItem.Type::Item;
              SitooItem.INSERT;
            end;

            SitooItem.productid := Common.GetIntXML(XmlItemElement, 'productid');
            SitooItem.sku := Common.GetValueXML(XmlItemElement, 'sku');
            SitooItem.quantity := Common.GetDecimalXML(XmlItemElement, 'quantity');
            SitooItem.moneynetpriceperunit := Common.GetDecimalXML(XmlItemElement, 'moneynetpriceperunit');
            SitooItem.moneypriceorg := Common.GetDecimalXML(XmlItemElement, 'moneypriceorg');
            SitooItem.vatvalue := Common.GetDecimalXML(XmlItemElement, 'vatvalue');
            SitooItem.moneyitemtotal_net := Common.GetDecimalXML(XmlItemElement, 'moneyitemtotal_net');
            SitooItem.moneyitemtotal_vat := Common.GetDecimalXML(XmlItemElement, 'moneyitemtotal_vat');
            SitooItem.vouchercode := Common.GetValueXML(XmlItemElement,'vouchercode');
            SitooItem.voucherid := Common.GetIntXML(XmlItemElement, 'voucherid');
            SitooItem.vouchername := Common.GetValueXML(XmlItemElement, 'vouchername');
            SitooItem.ispercentage := Common.GetBoolXML(XmlItemElement, 'ispercentage');
            SitooItem.vouchervalue := Common.GetDecimalXML(XmlItemElement, 'vouchervalue');
            SitooItem.moneyoriginalprice := Common.GetDecimalXML(XmlItemElement, 'moneyoriginalprice');
            SitooItem.moneydiscountedprice := Common.GetDecimalXML(XmlItemElement, 'moneydiscountedprice');
            SitooItem.moneydiscount := Common.GetDecimalXML(XmlItemElement, 'moneydiscount');
            SitooItem.decimalquantitytotal := Common.GetDecimalXML(XmlItemElement, 'decimalquantitytotal');
            SitooItem.moneynetpriceperquantity := Common.GetDecimalXML(XmlItemElement, 'moneynetpriceperquantity');
            SitooItem.MODIFY;

            Counter += 1;
          until Counter = XmlItemList.Count;
        end;
    end;

    local procedure SaveOrderPayments(var SitooOrder : Record "Sitoo Order";var XmlOrderElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode");
    var
        Common : Codeunit "Sitoo Common";
        SitooItem : Record "Sitoo Order Line";
        Column : Integer;
        PaymentCounter : Integer;
        RefId : Text;
        Name : Text;
        Amount : Decimal;
        XmlPaymentList : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNodeList";
        XmlPaymentElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        Counter : Integer;
    begin
        Column := 0;
        PaymentCounter := 10000;

        SitooItem.SETRANGE(orderid, SitooOrder.orderid);
        SitooItem.SETRANGE(Type, SitooItem.Type::Payment);
        SitooItem.SETRANGE("Market Code", SitooOrder."Market Code");
        if SitooItem.FINDSET then
          SitooItem.DELETEALL;

        XmlPaymentList := XmlOrderElement.SelectNodes('payments');

        if XmlPaymentList.Count > 0 then begin
          Counter := 0;
          repeat
            XmlPaymentElement := XmlPaymentList.Item(Counter);

            if Common.GetValueXML(XmlPaymentElement, 'name') <> '' then begin
              RefId := Common.GetValueXML(XmlPaymentElement, 'refid');
              Name := Common.GetValueXML(XmlPaymentElement, 'name');
              Amount:= Common.GetDecimalXML(XmlPaymentElement, 'moneyamount');

              if RefId <> '' then begin
                SitooItem.RESET;
                SitooItem.SETRANGE(orderid, SitooOrder.orderid);
                SitooItem.SETRANGE(Type, SitooItem.Type::Payment);
                SitooItem.SETRANGE("payment refid", RefId);
                SitooItem.SETRANGE("Market Code", SitooOrder."Market Code");
                if not SitooItem.FINDFIRST then begin
                  SitooItem.INIT;
                  SitooItem.orderid := SitooOrder.orderid;
                  SitooItem.orderitemid := PaymentCounter;
                  SitooItem."Market Code" := SitooOrder."Market Code";
                  SitooItem.Type := SitooItem.Type::Payment;
                  SitooItem.INSERT;
                end;
              end else begin
                  SitooItem.INIT;
                  SitooItem.orderid := SitooOrder.orderid;
                  SitooItem.orderitemid := PaymentCounter;
                  SitooItem."Market Code" := SitooOrder."Market Code";
                  SitooItem.Type := SitooItem.Type::Payment;
                  SitooItem.INSERT;
              end;

              SitooItem."payment name" := Common.GetValueXML(XmlPaymentElement, 'name');
              SitooItem."payment moneyamount" := Common.GetDecimalXML(XmlPaymentElement, 'moneyamount');
              SitooItem."payment reftype" := Common.GetValueXML(XmlPaymentElement, 'reftype');
              SitooItem."payment refid" := Common.GetValueXML(XmlPaymentElement, 'refid');
              SitooItem."payment cardissuer" := Common.GetValueXML(XmlPaymentElement, 'cardissuer');

              SitooItem.MODIFY;
              PaymentCounter += 1;

              Counter += 1;
            end;
          until Counter = XmlPaymentList.Count;
        end;
    end;

    local procedure GetNextOrderId(var SitooSetup : Record "Sitoo Setup") : Integer;
    var
        OrderId : Integer;
    begin
        exit(SitooSetup."Last Sales Order Id" + 1);
    end;

    local procedure GetNextInvoiceId(var SitooSetup : Record "Sitoo Setup") : Integer;
    var
        OrderId : Integer;
    begin
        exit(SitooSetup."Last Sales Invoice Id" + 1);
    end;

    local procedure SetLastOrderId(var SitooSetup : Record "Sitoo Setup";NewOrderId : Integer);
    begin
        //SitooSetup.GET; //MAJO

        if SitooSetup."Last Sales Order Id" < NewOrderId then begin
          SitooSetup."Last Sales Order Id" := NewOrderId;
          SitooSetup.MODIFY;
        end;
    end;

    local procedure SetLastInvoiceId(var SitooSetup : Record "Sitoo Setup";NewOrderId : Integer);
    begin

        if SitooSetup."Last Sales Invoice Id" < NewOrderId then begin
          SitooSetup."Last Sales Invoice Id" := NewOrderId;
          SitooSetup.MODIFY;
        end;
    end;

    local procedure SetReady(var SitooOrder : Record "Sitoo Order");
    begin

        if SitooOrder."Nav Status" <> SitooOrder."Nav Status"::Posted then begin
          SitooOrder.VALIDATE("Nav Status", SitooOrder."Nav Status"::"Ready To Post");
          SitooOrder.MODIFY(true);
        end;
    end;
}

