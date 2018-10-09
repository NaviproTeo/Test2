codeunit 51306 "Sitoo Cash Register Mgt"
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
            if Setup."Get Cash Registers" then begin
              NextCheck := Setup."Last Get Cash Registers" + Setup."Get Cash Register Interval" * 60000;
              if (CURRENTDATETIME > NextCheck) or (GUIALLOWED) then begin
                GetCashRegisters(Setup);
                Setup."Last Get Cash Registers" := CURRENTDATETIME;
                Setup.MODIFY;
                COMMIT;
              end;
            end;

            if Setup."Get Z-Reports" then begin
              NextCheck := Setup."Last Get Z-Reports" + Setup."Get Z-Reports Interval" * 60000;
              if (CURRENTDATETIME > NextCheck) or (GUIALLOWED) then begin
                GetZReports(Setup);
                Setup."Last Get Z-Reports" := CURRENTDATETIME;
                Setup.MODIFY;
                COMMIT;
              end;
            end;
          until Setup.NEXT = 0;
    end;

    procedure ProcessInbound(var SitooLogEntry : Record "Sitoo Log Entry");
    begin
        case SitooLogEntry."Sub Type" of
          'ZREPORTS': SaveZReports(SitooLogEntry);
          'ZREPORT': SaveZReportSingle(SitooLogEntry);
          'LIST': SaveCashRegisters(SitooLogEntry);
        end;
    end;

    procedure ProcessOutbound(var SitooLogEntry : Record "Sitoo Log Entry") : Integer;
    begin
    end;

    procedure GetCashRegisters(var Setup : Record "Sitoo Setup");
    var
        Common : Codeunit "Sitoo Common";
        URL : Text;
    begin

        URL := Setup."Base URL" + 'sites/' + FORMAT(Setup."Site Id") + '/cashregisters.json?num=1000';
        Common.Download(URL, 'CASHREGISTER', 'LIST', 'GetCashRegisters', '', Setup."Market Code");
    end;

    local procedure SaveCashRegisters(var LogEntry : Record "Sitoo Log Entry") : Integer;
    var
        Common : Codeunit "Sitoo Common";
        Counter : Integer;
        Updated : Integer;
        XmlDocument : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlDocument";
        XmlRegisterList : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNodeList";
        XmlRegisterElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        ProgressWindow : Dialog;
    begin
        Common.GetResponseXML(LogEntry, XmlDocument);

        XmlRegisterList := XmlDocument.GetElementsByTagName('items');

        if XmlRegisterList.Count > 0 then begin
          Counter := 0;

          if GUIALLOWED then
            ProgressWindow.OPEN('Processing cash register #1#######');

          repeat
            XmlRegisterElement := XmlRegisterList.Item(Counter);

            if SaveCashRegister(XmlRegisterElement, LogEntry."Market Code") then
              Updated += 1;

            if GUIALLOWED then
              ProgressWindow.UPDATE(1, FORMAT(Counter));

            Counter += 1;
          until Counter = XmlRegisterList.Count;

          if GUIALLOWED then
            ProgressWindow.CLOSE;

        end;

        LogEntry.Information := FORMAT(Updated) + ' updated cash registers';
        LogEntry.Status := LogEntry.Status::Processed;
        LogEntry.MODIFY;

        if Updated = 0 then
          LogEntry.DELETE;
    end;

    local procedure SaveCashRegister(var XmlRegisterElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";MarketCode : Code[20]) : Boolean;
    var
        Common : Codeunit "Sitoo Common";
        SitooCashRegister : Record "Sitoo Cash Register";
        RegisterId : Text;
        Modified : Boolean;
        WarehouseId : Integer;
    begin
        RegisterId := Common.GetValueXML(XmlRegisterElement, 'registerid');
        if RegisterId = '' then
          exit(false);

        if not SitooCashRegister.GET(RegisterId, MarketCode) then begin
          SitooCashRegister.INIT;
          SitooCashRegister.registerid := RegisterId;
          SitooCashRegister."Market Code" := MarketCode;
          SitooCashRegister.registerkey := Common.GetValueXML(XmlRegisterElement, 'registerkey');
          SitooCashRegister."Last Z Report" := CREATEDATETIME(19700101D, 000000T);
          SitooCashRegister.INSERT;
          Modified := true;
        end;

        WarehouseId := Common.GetIntXML(XmlRegisterElement, 'warehouseid');
        if SitooCashRegister.warehouseid <> WarehouseId then begin
          SitooCashRegister.warehouseid := WarehouseId;
          SitooCashRegister.MODIFY(true);
          Modified := true;
        end;

        if SitooCashRegister.registerkey <> Common.GetValueXML(XmlRegisterElement, 'registerkey') then begin
          SitooCashRegister.registerkey := Common.GetValueXML(XmlRegisterElement, 'registerkey');
          SitooCashRegister.MODIFY(true);
          Modified := true;
        end;

        exit(Modified);
    end;

    procedure GetZReports(var Setup : Record "Sitoo Setup");
    var
        SitooCashRegister : Record "Sitoo Cash Register";
        Common : Codeunit "Sitoo Common";
        NextCheck : DateTime;
        TimeStamp : Text;
        URL : Text;
    begin

        NextCheck := Setup."Last Get Z-Reports" + Setup."Get Z-Reports Interval" * 60000;

        if CURRENTDATETIME < NextCheck then
          exit;

        if SitooCashRegister.FINDSET then begin
          repeat
            TimeStamp := Common.DateTimeToTimestamp(SitooCashRegister."Last Z Report");
            URL := Setup."Base URL"+ 'sites/' + FORMAT(Setup."Site Id") + '/cashregisters/' + SitooCashRegister.registerid + '/zreports.json?datecreatedfrom=' + TimeStamp + '&num=50';
            Common.Download(URL, 'CASHREGISTER', 'ZREPORTS', 'GetZReports', SitooCashRegister.registerid, Setup."Market Code");
          until SitooCashRegister.NEXT = 0;
        end;

        Setup."Last Get Z-Reports" := CURRENTDATETIME;
        Setup.MODIFY;
    end;

    local procedure SaveZReports(var LogEntry : Record "Sitoo Log Entry");
    var
        Common : Codeunit "Sitoo Common";
        ZReportId : Integer;
        RegisterId : Code[40];
        Counter : Integer;
        XmlDocument : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlDocument";
        XmlZReportList : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNodeList";
        XmlZReportElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        ProgressWindow : Dialog;
        SitooZReport : Record "Sitoo Z Report";
    begin
        Common.GetResponseXML(LogEntry, XmlDocument);

        XmlZReportList := XmlDocument.GetElementsByTagName('items');

        if XmlZReportList.Count > 0 then begin
          Counter := 0;

          if GUIALLOWED then
            ProgressWindow.OPEN('Processing Z-report #1#######');

          repeat
            XmlZReportElement := XmlZReportList.Item(Counter);

            SaveZReportFromList(ZReportId, RegisterId, XmlZReportElement, LogEntry);

            SitooZReport.GET(ZReportId, RegisterId, LogEntry."Market Code");

            if GUIALLOWED then
              ProgressWindow.UPDATE(1, FORMAT(ZReportId));

            SaveZReportLinesFromList(SitooZReport, XmlZReportElement);

            if ZReportId <> 0 then
              SetReady(SitooZReport);

            Counter += 1;
          until Counter = XmlZReportList.Count;

          if GUIALLOWED then
            ProgressWindow.CLOSE;

        end;

        LogEntry.Information := FORMAT(Counter) + ' z reports';
        LogEntry.Status := LogEntry.Status::Processed;
        LogEntry.MODIFY;

        if Counter = 0 then
          LogEntry.DELETE;
    end;

    local procedure SaveZReportFromList(var ZReportId : Integer;var RegisterId : Code[40];var XmlZReportElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";var LogEntry : Record "Sitoo Log Entry") : Integer;
    var
        Common : Codeunit "Sitoo Common";
        SitooZReport : Record "Sitoo Z Report";
        SitooCashRegister : Record "Sitoo Cash Register";
        SitooWarehouse : Record "Sitoo Warehouse";
    begin
        ZReportId := Common.GetIntXML(XmlZReportElement, 'zreportid');
        RegisterId := Common.GetValueXML(XmlZReportElement, 'registerid');
        //##180831#MAJO#Save store
        if not SitooCashRegister.GET(RegisterId, LogEntry."Market Code") then
          ERROR('Cash register is missing');
        if not SitooWarehouse.GET(SitooCashRegister.warehouseid, LogEntry."Market Code") then
          ERROR('Warehouse is missing');
        //#END#MAJO
        if not SitooZReport.GET(ZReportId, RegisterId, LogEntry."Market Code") then begin
          SitooZReport.INIT;
          SitooZReport.zreportid := ZReportId;
          SitooZReport.registerid := RegisterId;
          SitooZReport."Market Code" := LogEntry."Market Code";
          SitooZReport."Location Code" := SitooWarehouse."Location Code"; //##180831#MAJO#Save store
          SitooZReport.INSERT;
        end;

        if SitooZReport."Nav Status" = SitooZReport."Nav Status"::Posted then
          exit;

        SitooZReport.registerkey := Common.GetValueXML(XmlZReportElement, 'registerkey');
        SitooZReport.comment := Common.GetValueXML(XmlZReportElement, 'comment');
        SitooZReport.datecreated := Common.GetDateTimeXML(XmlZReportElement, 'datecreated');
        SitooZReport.moneysalestotal := Common.GetDecimalXML(XmlZReportElement, 'moneysalestotal');
        SitooZReport.moneysalestotalnet := Common.GetDecimalXML(XmlZReportElement, 'moneysalestotalnet');
        SitooZReport.numsales := Common.GetDecimalXML(XmlZReportElement, 'numsales');
        SitooZReport.numsalesitems := Common.GetDecimalXML(XmlZReportElement, 'numsalesitems');
        SitooZReport.moneyrefundtotal := Common.GetDecimalXML(XmlZReportElement, 'moneyrefundtotal');
        SitooZReport.moneyrefundtotalnet := Common.GetDecimalXML(XmlZReportElement, 'moneyrefundtotalnet');
        SitooZReport.numrefund := Common.GetDecimalXML(XmlZReportElement, 'numrefund');
        SitooZReport.numrefunditems := Common.GetDecimalXML(XmlZReportElement, 'numrefunditems');
        SitooZReport.moneyroundoff := Common.GetDecimalXML(XmlZReportElement, 'moneyroundoff');
        SitooZReport.moneysummarysales := Common.GetDecimalXML(XmlZReportElement, 'moneysummarysales');
        SitooZReport.moneysummaryrefund := Common.GetDecimalXML(XmlZReportElement, 'moneysummaryrefund');
        SitooZReport.moneysummaryroundoff := Common.GetDecimalXML(XmlZReportElement, 'moneysummaryroundoff');
        SitooZReport.moneysummarytotal := Common.GetDecimalXML(XmlZReportElement, 'moneysummarytotal');
        SitooZReport.moneycash_in := Common.GetDecimalXML(XmlZReportElement, 'moneycash_in');
        SitooZReport.moneycash_salesrefunds := Common.GetDecimalXML(XmlZReportElement, 'moneycash_salesrefunds');
        SitooZReport.moneycash_petty := Common.GetDecimalXML(XmlZReportElement, 'moneycash_petty');
        SitooZReport.moneycash_bank := Common.GetDecimalXML(XmlZReportElement, 'moneycash_bank');
        SitooZReport.moneycash_expected := Common.GetDecimalXML(XmlZReportElement, 'moneycash_expected');
        SitooZReport.moneycash_counted := Common.GetDecimalXML(XmlZReportElement, 'moneycash_counted');
        SitooZReport.moneycash_diff := Common.GetDecimalXML(XmlZReportElement, 'moneycash_diff');
        SitooZReport.moneycash_bankfinal := Common.GetDecimalXML(XmlZReportElement, 'moneycash_bankfinal');
        SitooZReport.moneycash_out := Common.GetDecimalXML(XmlZReportElement, 'moneycash_out');
        SitooZReport.moneydiscount := Common.GetDecimalXML(XmlZReportElement, 'moneydiscount');
        SitooZReport.numsalestypeproduct := Common.GetDecimalXML(XmlZReportElement, 'numsalestypeproduct');
        SitooZReport.numsalestypeservice := Common.GetDecimalXML(XmlZReportElement, 'numsalestypeservice');
        SitooZReport.numsalestypegiftcard := Common.GetDecimalXML(XmlZReportElement, 'numsalestypegiftcard');
        SitooZReport.numreceipts := Common.GetDecimalXML(XmlZReportElement, 'numreceipts');
        SitooZReport.numopendrawer := Common.GetDecimalXML(XmlZReportElement, 'numopendrawer');
        SitooZReport.numpractice := Common.GetDecimalXML(XmlZReportElement, 'numpractice');
        SitooZReport.moneypractice := Common.GetDecimalXML(XmlZReportElement, 'moneypractice');
        SitooZReport.moneygrandtotalsales := Common.GetDecimalXML(XmlZReportElement, 'moneygrandtotalsales');
        SitooZReport.moneygrandtotalrefund := Common.GetDecimalXML(XmlZReportElement, 'moneygrandtotalrefund');
        SitooZReport.moneygrandtotalnet := Common.GetDecimalXML(XmlZReportElement, 'moneygrandtotalnet');

        SitooZReport."Source Entry No." := LogEntry."Entry No.";

        SitooZReport.MODIFY;
    end;

    local procedure SaveZReportLinesFromList(var SitooZReport : Record "Sitoo Z Report";var XmlLinesElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode");
    var
        Common : Codeunit "Sitoo Common";
        SitooZReportLine : Record "Sitoo Z Report Line";
    begin
        CreateZReportSubGroup(XmlLinesElement, SitooZReport, 10000, 'vatgroupssales');
        CreateZReportSubGroup(XmlLinesElement, SitooZReport, 20000, 'productgroupssales');
        CreateZReportSubGroup(XmlLinesElement, SitooZReport, 30000, 'vatgroupsrefund');
        CreateZReportSubGroup(XmlLinesElement, SitooZReport, 40000, 'productgroupsrefund');
        CreateZReportSubGroup(XmlLinesElement, SitooZReport, 50000, 'paymentssales');
        CreateZReportSubGroup(XmlLinesElement, SitooZReport, 60000, 'paymentsrefund');
    end;

    local procedure SaveZReportSingle(var LogEntry : Record "Sitoo Log Entry");
    var
        Common : Codeunit "Sitoo Common";
        ZReportId : Integer;
        RegisterId : Code[40];
        Counter : Integer;
        XmlDocument : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlDocument";
        XmlZReportList : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNodeList";
        XmlRootElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        XmlZReportElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        ProgressWindow : Dialog;
        SitooZReport : Record "Sitoo Z Report";
    begin
        Common.GetResponseXML(LogEntry, XmlDocument);

        if GUIALLOWED then
          ProgressWindow.OPEN('Processing Z-report #1#######');

        XmlRootElement := XmlDocument.DocumentElement;

        XmlZReportElement := XmlRootElement.SelectSingleNode('root');

        //ZReportId := Common.GetIntXML(XmlZReportElement, 'zreportid');
        //RegisterId := Common.GetValueXML(XmlZReportElement, 'registerid');

        SaveZReportFromList(ZReportId, RegisterId, XmlZReportElement, LogEntry);

        SitooZReport.GET(ZReportId, RegisterId, LogEntry."Market Code");

        if GUIALLOWED then
          ProgressWindow.UPDATE(1, FORMAT(ZReportId));

        SaveZReportLinesFromList(SitooZReport, XmlZReportElement);

        if ZReportId <> 0 then
          SetReady(SitooZReport);

        if GUIALLOWED then
          ProgressWindow.CLOSE;

        LogEntry.Information := FORMAT(ZReportId);
        LogEntry.Status := LogEntry.Status::Processed;
        LogEntry.MODIFY;
    end;

    local procedure CreateZReportSubGroup(var XmlLinesElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";var SitooZReport : Record "Sitoo Z Report";LineNo : Integer;GroupName : Text);
    var
        XmlLinesList : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNodeList";
        XmlLineElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        Counter : Integer;
    begin
        XmlLinesList := XmlLinesElement.SelectNodes(GroupName);

        if XmlLinesList.Count > 0 then begin
          Counter := 0;
          repeat
            XmlLineElement := XmlLinesList.Item(Counter);
            CreateZReportLine(XmlLineElement, SitooZReport, LineNo + Counter, GroupName);
            Counter += 1;
          until Counter = XmlLinesList.Count;
        end;
    end;

    local procedure CreateZReportLine(var XmlGroupElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";var SitooZReport : Record "Sitoo Z Report";LineNo : Integer;GroupName : Text);
    var
        Common : Codeunit "Sitoo Common";
        SitooZReportLine : Record "Sitoo Z Report Line";
    begin

        SitooZReportLine.INIT;
        SitooZReportLine.Code := GroupName;
        SitooZReportLine."Z Report Id" := SitooZReport.zreportid;
        SitooZReportLine."Line No." := LineNo;
        SitooZReportLine."Register Id" := SitooZReport.registerid;
        SitooZReportLine."Market Code" := SitooZReport."Market Code";
        if SitooZReportLine.INSERT then;

        SitooZReportLine.name := Common.GetValueXML(XmlGroupElement, 'name');
        SitooZReportLine.vatvalue := Common.GetDecimalXML(XmlGroupElement, 'vatvalue');
        SitooZReportLine.numtotal := Common.GetDecimalXML(XmlGroupElement, 'numtotal');
        SitooZReportLine.moneytotal := Common.GetDecimalXML(XmlGroupElement, 'moneytotal');
        SitooZReportLine.moneytotalnet := Common.GetDecimalXML(XmlGroupElement, 'moneytotalnet');
        SitooZReportLine.moneytotalvat := Common.GetDecimalXML(XmlGroupElement, 'moneytotalvat');
        SitooZReportLine.MODIFY;
    end;

    local procedure SetReady(var SitooZReport : Record "Sitoo Z Report");
    var
        SitooCashRegister : Record "Sitoo Cash Register";
        LastDateTime : DateTime;
        Date : Date;
        Time : Time;
    begin

        if SitooZReport."Nav Status" <> SitooZReport."Nav Status"::Posted then begin
          SitooZReport.VALIDATE("Nav Status", SitooZReport."Nav Status"::"Ready To Post");
          SitooZReport.MODIFY(true);
        end;

        SitooCashRegister.GET(SitooZReport.registerid, SitooZReport."Market Code");
        if SitooCashRegister."Last Z Report" <= SitooZReport.datecreated then begin
          Date := DT2DATE(SitooZReport.datecreated);
          Time := DT2TIME(SitooZReport.datecreated);
          Time += 1000;
          Time -= 1000*60*60*2; //#MAJO#that's right, we are having time zone problems and this is the ugly solution
          LastDateTime := CREATEDATETIME(Date, Time);
          SitooCashRegister."Last Z Report" := LastDateTime;
          SitooCashRegister.MODIFY;
        end;
    end;

    procedure GetZReport(ReportId : Integer;RegisterId : Code[40];MarketCode : Code[20]);
    var
        Setup : Record "Sitoo Setup";
        Common : Codeunit "Sitoo Common";
        URL : Text;
    begin
        Setup.GET(MarketCode);

        URL := Setup."Base URL" + 'sites/' + FORMAT(Setup."Site Id") + '/cashregisters/' + RegisterId + '/zreports/' + FORMAT(ReportId) + '.json';

        Common.Download(URL, 'CASHREGISTER', 'ZREPORT', 'GetZReport', FORMAT(ReportId), MarketCode);
    end;
}

