codeunit 51301 "Sitoo Common"
{
    // version Sitoo 3.0


    trigger OnRun();
    begin
    end;

    procedure Download(URL : Text;Type : Code[20];SubType : Code[20];Method : Text;DocumentNo : Code[50];MarketCode : Code[20]) : Integer;
    var
        Response : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
        JsonMgt : Codeunit "Sitoo Json Mgt";
        EntryNo : Integer;
        Setup : Record "Sitoo Setup";
    begin
        Setup.GET(MarketCode);

        JsonMgt.DownloadString(URL, '', '', Response, Setup.Authorization);

        EntryNo := AddInboundLogEntry(URL, Response, Type, SubType, Method, DocumentNo, URL, MarketCode);

        exit(EntryNo);
    end;

    procedure Upload(URL : Text;Type : Code[20];SubType : Code[20];Method : Text;DocumentNo : Code[20];Request : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";"Action" : Code[10];MarketCode : Code[20]) : Integer;
    var
        JsonMgt : Codeunit "Sitoo Json Mgt";
        LogEntry : Record "Sitoo Log Entry";
        EntryNo : Integer;
        Response : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
        ErrorMsg : Text;
        Setup : Record "Sitoo Setup";
    begin
        Setup.GET(MarketCode);

        JsonMgt.UploadJSon(URL, '', '', Request, Response, Action, Setup.Authorization);

        EntryNo := AddInboundLogEntry(Request, Response, Type, SubType, Method, DocumentNo, URL, MarketCode);

        LogEntry.GET(EntryNo);
        ErrorMsg := GetErrorTextXML(LogEntry);

        if ErrorMsg <> '' then begin
          LogEntry.Information := ErrorMsg;
          LogEntry.Status := LogEntry.Status::Error;
        end;

        LogEntry.Method := Method;
        LogEntry.MODIFY;

        exit(EntryNo);
    end;

    procedure UploadLogEntry(var LogEntry : Record "Sitoo Log Entry";Method : Text;SaveInbound : Boolean;URL : Text) : Integer;
    var
        JsonMgt : Codeunit "Sitoo Json Mgt";
        EntryNo : Integer;
        Request : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
        Response : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
        Error : Text;
        BigText : BigText;
        StreamOut : OutStream;
        Status : Integer;
        Setup : Record "Sitoo Setup";
    begin
        Setup.GET(LogEntry."Market Code");

        GetRequestString(LogEntry, Request);

        JsonMgt.UploadJSon(URL, '', '', Request, Response, LogEntry.Action, Setup.Authorization);

        EntryNo := LogEntry."Entry No.";

        BigText.ADDTEXT(Response.ToString);

        LogEntry.CALCFIELDS("Response Document");
        CLEAR(LogEntry."Response Document");

        LogEntry."Response Document".CREATEOUTSTREAM(StreamOut);
        BigText.WRITE(StreamOut);

        LogEntry.MODIFY;

        Error := GetErrorTextXML(LogEntry);
        if Error <> '' then begin
          LogEntry.Information := Error;
          LogEntry.Status := LogEntry.Status::Error;

          Status := GetStatusXML(LogEntry);

          if Status = -429 then begin
            LogEntry.Information := 'requeued';
            LogEntry.Status := LogEntry.Status::Unprocessed;
          end;

          LogEntry.MODIFY;
          exit(Status);
        end
        else begin
          if SaveInbound then
            EntryNo := AddInboundLogEntry(Request, Response, LogEntry.Type, LogEntry."Sub Type", Method, LogEntry."Document No.", URL, LogEntry."Market Code");
          exit(EntryNo);
        end;
    end;

    procedure GetRequestRecords(var LogEntry : Record "Sitoo Log Entry";var TempPostingExchField : Record "Data Exch. Field" temporary;GroupName : Text);
    var
        JsonMgt : Codeunit "Sitoo Json Mgt";
        Request : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
        InStream : InStream;
        MemoryStream : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.IO.MemoryStream";
        Encoding : DotNet "'mscorlib, Version=4.0.0.0, culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Text.UTF8Encoding";
    begin
        LogEntry.CALCFIELDS("Request Document");
        LogEntry."Request Document".CREATEINSTREAM(InStream);

        MemoryStream := MemoryStream.MemoryStream;
        COPYSTREAM(MemoryStream, InStream);

        Encoding := Encoding.UTF8Encoding;
        Request := Encoding.GetString(MemoryStream.ToArray);

        JsonMgt.ReadJSon(Request, TempPostingExchField, GroupName);
    end;

    procedure GetResponseRecords(var LogEntry : Record "Sitoo Log Entry";var TempPostingExchField : Record "Data Exch. Field" temporary;GroupName : Text);
    var
        JsonMgt : Codeunit "Sitoo Json Mgt";
        Response : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
        InStream : InStream;
        MemoryStream : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.IO.MemoryStream";
        Encoding : DotNet "'mscorlib, Version=4.0.0.0, culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Text.UTF8Encoding";
    begin
        LogEntry.CALCFIELDS("Response Document");
        LogEntry."Response Document".CREATEINSTREAM(InStream);

        MemoryStream := MemoryStream.MemoryStream;
        COPYSTREAM(MemoryStream, InStream);

        Encoding := Encoding.UTF8Encoding;
        Response := Encoding.GetString(MemoryStream.ToArray);

        JsonMgt.ReadJSon(Response, TempPostingExchField, GroupName);
    end;

    procedure GetRequestString(var LogEntry : Record "Sitoo Log Entry";var String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String");
    var
        JsonMgt : Codeunit "Sitoo Json Mgt";
        InStream : InStream;
        MemoryStream : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.IO.MemoryStream";
        Encoding : DotNet "'mscorlib, Version=4.0.0.0, culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Text.UTF8Encoding";
    begin
        LogEntry.CALCFIELDS("Request Document");
        LogEntry."Request Document".CREATEINSTREAM(InStream);

        MemoryStream := MemoryStream.MemoryStream;
        COPYSTREAM(MemoryStream, InStream);

        Encoding := Encoding.UTF8Encoding;
        String := Encoding.GetString(MemoryStream.ToArray);
    end;

    procedure GetResponseString(var LogEntry : Record "Sitoo Log Entry";var String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String");
    var
        JsonMgt : Codeunit "Sitoo Json Mgt";
        InStream : InStream;
        MemoryStream : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.IO.MemoryStream";
        Encoding : DotNet "'mscorlib, Version=4.0.0.0, culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Text.UTF8Encoding";
    begin
        LogEntry.CALCFIELDS("Response Document");
        LogEntry."Response Document".CREATEINSTREAM(InStream);

        MemoryStream := MemoryStream.MemoryStream;
        COPYSTREAM(MemoryStream, InStream);

        Encoding := Encoding.UTF8Encoding;
        String := Encoding.GetString(MemoryStream.ToArray);
    end;

    procedure GetResponseXML(var LogEntry : Record "Sitoo Log Entry";var XmlDocument : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlDocument");
    var
        JsonMgt : Codeunit "Sitoo Json Mgt";
        InStream : InStream;
        MemoryStream : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.IO.MemoryStream";
        Encoding : DotNet "'mscorlib, Version=4.0.0.0, culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Text.UTF8Encoding";
        String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
    begin
        LogEntry.CALCFIELDS("Response Document");
        LogEntry."Response Document".CREATEINSTREAM(InStream);

        MemoryStream := MemoryStream.MemoryStream;
        COPYSTREAM(MemoryStream, InStream);

        Encoding := Encoding.UTF8Encoding;
        String := Encoding.GetString(MemoryStream.ToArray);

        JsonMgt.StringToXML(String, XmlDocument);
    end;

    procedure GetRequestXML(var LogEntry : Record "Sitoo Log Entry";var XmlDocument : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlDocument");
    var
        JsonMgt : Codeunit "Sitoo Json Mgt";
        InStream : InStream;
        MemoryStream : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.IO.MemoryStream";
        Encoding : DotNet "'mscorlib, Version=4.0.0.0, culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Text.UTF8Encoding";
        String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
    begin
        LogEntry.CALCFIELDS("Request Document");
        LogEntry."Request Document".CREATEINSTREAM(InStream);

        MemoryStream := MemoryStream.MemoryStream;
        COPYSTREAM(MemoryStream, InStream);

        Encoding := Encoding.UTF8Encoding;
        String := Encoding.GetString(MemoryStream.ToArray);

        JsonMgt.StringToXML(String, XmlDocument);
    end;

    procedure GetValueXML(var XmlElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";ParameterName : Text) : Text;
    var
        Node : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
    begin
        Node := XmlElement.SelectSingleNode(ParameterName);
        if not ISNULL(Node) then
          exit(Node.InnerXml);

        exit('');
    end;

    procedure GetDecimalXML(var XmlElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";ParameterName : Text) : Decimal;
    var
        Value : Text;
        Dec : Decimal;
        Lang : Integer;
    begin
        Value := GetValueXML(XmlElement, ParameterName);

        if WINDOWSLANGUAGE = 1053 then
           Value := CONVERTSTR(Value, '.', ',');

        if Value <> '' then
          EVALUATE(Dec, Value);
        exit(Dec);
    end;

    procedure GetIntXML(var XmlElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";ParameterName : Text) : Integer;
    var
        Value : Text;
        Int : Integer;
    begin
        Value := GetValueXML(XmlElement, ParameterName);
        Value := CONVERTSTR(Value, '.', ',');
        if Value <> '' then
          EVALUATE(Int, Value);
        exit(Int);
    end;

    procedure GetDateTimeXML(var XmlElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";ParameterName : Text) : DateTime;
    var
        TimeStamp : Integer;
        DateTime : DateTime;
        Value : Text;
        DateTimeText : Text;
        Date : Date;
        Time : Time;
        DNDateTime : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.DateTime";
    begin
        Value := GetValueXML(XmlElement, ParameterName);
        if Value = '' then
          exit(CREATEDATETIME(0D, 000000T));

        EVALUATE(TimeStamp, Value);

        DNDateTime := DNDateTime.DateTime(1970, 1, 1);

        if WINDOWSLANGUAGE = 1053 then
          DNDateTime := DNDateTime.AddSeconds(TimeStamp + (GetTimeOffset * 60 * 60))
        else
          DNDateTime := DNDateTime.AddSeconds(TimeStamp);

        DateTimeText := DNDateTime.ToString('o');
        EVALUATE(Time, COPYSTR(DateTimeText, 12, 8));

        DateTimeText := DNDateTime.ToString;
        EVALUATE(Date, COPYSTR(DateTimeText, 1, 10));

        DateTime := CREATEDATETIME(Date, Time);

        exit(DateTime);
    end;

    procedure GetBoolXML(var XmlElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";ParameterName : Text) : Boolean;
    var
        Value : Text;
    begin
        Value := GetValueXML(XmlElement, ParameterName);
        exit (UPPERCASE(Value) = 'TRUE');
    end;

    procedure GetStatusXML(var SitooLogEntry : Record "Sitoo Log Entry") : Integer;
    var
        XmlDocument : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlDocument";
        XmlElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
    begin
        GetResponseXML(SitooLogEntry, XmlDocument);

        XmlElement := XmlDocument.DocumentElement.Item('root');

        exit(-GetIntXML(XmlElement, 'statuscode'));
    end;

    procedure GetErrorTextXML(var SitooLogEntry : Record "Sitoo Log Entry") : Text;
    var
        XmlDocument : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlDocument";
        XmlElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
    begin
        GetResponseXML(SitooLogEntry, XmlDocument);

        XmlElement := XmlDocument.DocumentElement.Item('root');

        exit(GetValueXML(XmlElement, 'errortext'));
    end;

    procedure GetTotalCount(var SitooLogEntry : Record "Sitoo Log Entry") : Integer;
    var
        XmlDocument : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlDocument";
        XmlElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
    begin
        GetResponseXML(SitooLogEntry, XmlDocument);

        XmlElement := XmlDocument.DocumentElement.Item('root');

        exit(GetIntXML(XmlElement, 'totalcount'));
    end;

    procedure DateToTimestamp(DateIN : Date) : Text;
    var
        DateTimeEpoch : DotNet "'mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.DateTime";
        DateTime : DotNet "'mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.DateTime";
        Diff : BigInteger;
        Timespan : DotNet "'mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.TimeSpan";
        Seconds : BigInteger;
        Year : Integer;
        Month : Integer;
        Day : Integer;
    begin
        if DateIN = 0D then
          exit('');

        DateTimeEpoch := DateTimeEpoch.DateTime(1970, 1, 1);

        Year := DATE2DMY(DateIN, 3);
        Month := DATE2DMY(DateIN, 2);
        Day := DATE2DMY(DateIN, 1);

        DateTime := DateTime.DateTime(Year, Month, Day);

        Diff := DateTime.Ticks - DateTimeEpoch.Ticks;

        Seconds := Timespan.FromTicks(Diff);

        exit(COPYSTR(FORMAT(Seconds), 1, 10));
    end;

    procedure DateTimeToTimestamp(DateTimeIN : DateTime) : Text;
    var
        DateTimeEpoch : DotNet "'mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.DateTime";
        DateTime : DotNet "'mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.DateTime";
        Diff : BigInteger;
        Timespan : DotNet "'mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.TimeSpan";
        Seconds : BigInteger;
        Year : Integer;
        Month : Integer;
        Day : Integer;
        Date : Date;
        Hour : Integer;
        Minute : Integer;
        Second : Integer;
        HourText : Text;
    begin
        DateTimeEpoch := DateTimeEpoch.DateTime(1970, 1, 1);

        Date := DT2DATE(DateTimeIN);

        Year := DATE2DMY(Date, 3);
        Month := DATE2DMY(Date, 2);
        Day := DATE2DMY(Date, 1);

        HourText := FORMAT(DateTimeIN,0,9);

        EVALUATE(Hour, COPYSTR(FORMAT(DateTimeIN, 0, 9), 12, 2));
        EVALUATE(Minute, COPYSTR(FORMAT(DateTimeIN, 0, 9), 15, 2));
        EVALUATE(Second, COPYSTR(FORMAT(DateTimeIN, 0, 9), 18, 2));

        if Hour + GetTimeOffset < 24 then
          Hour := Hour + GetTimeOffset
        else begin
          // Calculera Day
        end;

        DateTime := DateTime.DateTime(Year, Month, Day, Hour, Minute, Second);

        Diff := DateTime.Ticks - DateTimeEpoch.Ticks;

        Seconds := Timespan.FromTicks(Diff);

        exit(COPYSTR(FORMAT(Seconds), 1, 10));
    end;

    procedure AddInboundLogEntry(Request : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";Response : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";Type : Code[20];SubType : Code[20];Method : Text[30];DocumentNo : Code[50];URL : Text;MarketCode : Code[20]) : Integer;
    var
        LogEntry : Record "Sitoo Log Entry";
        EntryNo : Integer;
        StreamOut : OutStream;
        BigText : BigText;
    begin
        if LogEntry.FIND('+') then
          EntryNo := LogEntry."Entry No." + 1
        else
          EntryNo := 1;

        LogEntry.INIT;
        LogEntry.VALIDATE("Entry No.", EntryNo);
        LogEntry.VALIDATE(Type, Type);
        LogEntry.VALIDATE("Sub Type", SubType);
        LogEntry.VALIDATE(Method, Method);
        LogEntry.VALIDATE(Direction, LogEntry.Direction::Inbound);
        LogEntry.VALIDATE(DateTime, CURRENTDATETIME);
        LogEntry.VALIDATE(Status, LogEntry.Status::Unprocessed);
        LogEntry.VALIDATE("Document No.", DocumentNo);
        LogEntry.VALIDATE("Market Code", MarketCode);
        LogEntry.INSERT(true);

        BigText.ADDTEXT(Response.ToString);

        LogEntry."Response Document".CREATEOUTSTREAM(StreamOut);
        BigText.WRITE(StreamOut);

        CLEAR(BigText);
        CLEAR(StreamOut);

        BigText.ADDTEXT(Request.ToString);

        LogEntry."Request Document".CREATEOUTSTREAM(StreamOut);
        BigText.WRITE(StreamOut);

        LogEntry.MODIFY(true);
        COMMIT;
        exit(LogEntry."Entry No.");
    end;

    procedure AddOutboundLogEntry(Request : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";Type : Code[20];SubType : Code[20];Method : Text[30];DocumentNo : Code[50];"Action" : Text;MarketCode : Code[20]) : Integer;
    var
        LogEntry : Record "Sitoo Log Entry";
        EntryNo : Integer;
        StreamOut : OutStream;
        BigText : BigText;
    begin
        if LogEntry.FIND('+') then
          EntryNo := LogEntry."Entry No." + 1
        else
          EntryNo := 1;

        LogEntry.INIT;
        LogEntry.VALIDATE("Entry No.", EntryNo);
        LogEntry.VALIDATE(Type, Type);
        LogEntry.VALIDATE("Sub Type", SubType);
        LogEntry.VALIDATE(Method, Method);
        LogEntry.VALIDATE(Direction, LogEntry.Direction::Outbound);
        LogEntry.VALIDATE(DateTime, CURRENTDATETIME);
        LogEntry.VALIDATE(Status, LogEntry.Status::Unprocessed);
        LogEntry.VALIDATE("Document No.", DocumentNo);
        LogEntry.VALIDATE(Action, Action);
        LogEntry.VALIDATE("Market Code", MarketCode);
        LogEntry.INSERT(true);

        BigText.ADDTEXT(Request.ToString);

        LogEntry."Request Document".CREATEOUTSTREAM(StreamOut);
        BigText.WRITE(StreamOut);

        LogEntry.MODIFY(true);
        COMMIT;
        exit(LogEntry."Entry No.");
    end;

    procedure AddQueueMessage(Type : Code[20];SubType : Code[20];"Action" : Code[10];PrimaryKey1 : Code[30];PrimaryKey2 : Code[30];MarketCode : Code[20]);
    var
        SitooOutboundQueue : Record "Sitoo Outbound Queue";
    begin
        SitooOutboundQueue.SETCURRENTKEY(Type, "Primary Key 1","Primary Key 2");
        SitooOutboundQueue.SETRANGE("Market Code", MarketCode);
        SitooOutboundQueue.SETRANGE(Type, Type);
        SitooOutboundQueue.SETRANGE("Sub Type", SubType);
        SitooOutboundQueue.SETRANGE("Primary Key 1", PrimaryKey1);
        SitooOutboundQueue.SETRANGE("Primary Key 2", PrimaryKey2);
        if not SitooOutboundQueue.FINDFIRST then begin
          SitooOutboundQueue.INIT;
          SitooOutboundQueue.GUID := CREATEGUID;
          SitooOutboundQueue.DateTime  := CURRENTDATETIME;
          SitooOutboundQueue."Market Code" := MarketCode;
          SitooOutboundQueue.Type := Type;
          SitooOutboundQueue."Sub Type" := SubType;
          SitooOutboundQueue."Primary Key 1" := PrimaryKey1;
          SitooOutboundQueue."Primary Key 2" := PrimaryKey2;
          SitooOutboundQueue.Action := Action;
          SitooOutboundQueue."Market Code" := MarketCode;
          SitooOutboundQueue.INSERT;
        end;
    end;

    procedure AddQueueMessageWDate(Type : Code[20];SubType : Code[20];"Action" : Code[10];PrimaryKey1 : Code[20];PrimaryKey2 : Code[20];Date1 : Date;Date2 : Date;MarketCode : Code[20]);
    var
        SitooOutboundQueue : Record "Sitoo Outbound Queue";
    begin
        SitooOutboundQueue.SETCURRENTKEY(Type, "Primary Key 1","Primary Key 2");
        SitooOutboundQueue.SETRANGE("Market Code", MarketCode);
        SitooOutboundQueue.SETRANGE(Type, Type);
        SitooOutboundQueue.SETRANGE("Sub Type", SubType);
        SitooOutboundQueue.SETRANGE("Primary Key 1", PrimaryKey1);
        SitooOutboundQueue.SETRANGE("Primary Key 2", PrimaryKey2);
        SitooOutboundQueue.SETRANGE("Date 1", Date1);
        SitooOutboundQueue.SETRANGE("Date 2", Date2);
        if not SitooOutboundQueue.FINDFIRST then begin
          SitooOutboundQueue.INIT;
          SitooOutboundQueue.GUID := CREATEGUID;
          SitooOutboundQueue.DateTime  := CURRENTDATETIME;
          SitooOutboundQueue."Market Code" := MarketCode;
          SitooOutboundQueue.Type := Type;
          SitooOutboundQueue."Sub Type" := SubType;
          SitooOutboundQueue."Primary Key 1" := PrimaryKey1;
          SitooOutboundQueue."Primary Key 2" := PrimaryKey2;
          SitooOutboundQueue."Date 1" := Date1;
          SitooOutboundQueue."Date 2" := Date2;
          SitooOutboundQueue.Action := Action;
          SitooOutboundQueue."Market Code" := MarketCode;
          SitooOutboundQueue.INSERT;
        end;
    end;

    procedure AddQueueError(var SitooOutboundQueue : Record "Sitoo Outbound Queue");
    begin
        SitooOutboundQueue."Error Message" := COPYSTR(GETLASTERRORTEXT, 1, 250);
        SitooOutboundQueue."Retry Count" += 1;
        SitooOutboundQueue.MODIFY;
    end;

    procedure ClearQueue(Status : Option "None",All,Unprocessed,Errors;MarketCode : Code[20]);
    var
        SitooOutboundQueue : Record "Sitoo Outbound Queue";
    begin
        if Status in [Status::All, Status::Unprocessed, Status::Errors] then begin
          if MarketCode <> '' then
            SitooOutboundQueue.SETRANGE("Market Code", MarketCode);
          if Status = Status::Unprocessed then
            SitooOutboundQueue.SETRANGE("Retry Count", 0);
          if Status = Status::Errors then
            SitooOutboundQueue.SETFILTER("Retry Count", '>0');

          SitooOutboundQueue.DELETEALL;
        end;
    end;

    local procedure GetTimeOffset() : Integer;
    var
        Registry : DotNet "'mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.Microsoft.Win32.Registry";
        V : Variant;
        Offset : Integer;
    begin
        V := Registry.GetValue('HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\TimeZoneInformation', 'ActiveTimeBias', 0);
        EVALUATE(Offset, FORMAT(V));
        if Offset <> 0 then
          exit(-Offset / 60);
    end;

    procedure CheckVariant(VariantCode : Text) : Boolean;
    var
        DNRegEx : DotNet "'System, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Text.RegularExpressions.Regex";
        DNMatch : DotNet "'System, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Text.RegularExpressions.Match";
        RegEx : Text;
    begin
        if VariantCode = '' then
          exit(true);

        RegEx := '^[a-öA-Ö0-9./-]+$';

        DNMatch := DNRegEx.Match(VariantCode,RegEx);

        if not DNMatch.Success then
          ERROR('Variant Code %1 contains invalid characters. Allowed are A-Ö, 0-9 and ./-', VariantCode);
    end;

    procedure CleanString(Input : Text) : Text;
    var
        DNRegEx : DotNet "'System, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Text.RegularExpressions.Regex";
        RegEx : Text;
    begin
        RegEx := '^[a-öA-Ö0-9./-]+$';

        exit(DNRegEx.Replace(Input, RegEx));
    end;

    procedure EnqueueMessages(SitooSetup : Record "Sitoo Setup");
    begin

        if SitooSetup."Use Variants" then begin
          SitooSetup.TESTFIELD("Enqueue Variants Report Id");
          REPORT.RUN(SitooSetup."Enqueue Variants Report Id");
        end else begin
          SitooSetup.TESTFIELD("Enqueue Messages Report Id");
          REPORT.RUN(SitooSetup."Enqueue Messages Report Id");
        end;
    end;

    procedure GetMarketCode(LocationCode : Code[10]) : Code[20];
    var
        SitooWarehouse : Record "Sitoo Warehouse";
        SitooEvents : Codeunit "Sitoo Events";
        MarketCode : Code[20];
        Handled : Boolean;
    begin
        SitooEvents.SitooCU51301_OnBeforeGetMarketCode(LocationCode, MarketCode, Handled);
        if Handled then
          exit(MarketCode);

        SitooWarehouse.SETRANGE("Location Code", LocationCode);
        if SitooWarehouse.FINDFIRST then
          exit(SitooWarehouse."Market Code");
    end;

    procedure GetComment(TableName : Option "G/L Account",Customer,Vendor,Item,Resource,Job,,"Resource Group","Bank Account",Campaign,"Fixed Asset",Insurance,"Nonstock Item","IC Partner";No : Code[20]) : Text;
    var
        CommentLine : Record "Comment Line";
        Comments : Text;
        SitooEvents : Codeunit "Sitoo Events";
        Handled : Boolean;
    begin
        SitooEvents.SitooCU51301_OnBeforeGetComment(TableName, No, Comments, Handled);
        if Handled then
          exit(Comments);

        Comments := '';
        CommentLine.SETRANGE("Table Name", TableName);
        CommentLine.SETRANGE("No.", No);
        if CommentLine.FINDSET then
          repeat
            Comments := Comments + CommentLine.Comment + ' ';
          until CommentLine.NEXT = 0;
    end;

    procedure GetCustomField(CustomFieldNo : Integer) : Text;
    var
        CommentLine : Record "Comment Line";
        CustomValue : Text;
        SitooEvents : Codeunit "Sitoo Events";
        Handled : Boolean;
    begin
        SitooEvents.SitooCU51301_OnBeforeGetCustomField(CustomFieldNo, CustomValue, Handled);
        if Handled then
          exit(CustomValue);
    end;
}

