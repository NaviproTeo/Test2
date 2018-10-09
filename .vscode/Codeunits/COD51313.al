codeunit 51313 "Sitoo User Mgt"
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
          until Setup.NEXT = 0;
    end;

    var
        UserType : Option Customer,Vendor,User;

    procedure ProcessInbound(var SitooLogEntry : Record "Sitoo Log Entry");
    begin
        case SitooLogEntry."Sub Type" of
          'CUSTOMER': ProcessUser(SitooLogEntry);
        end;
    end;

    procedure ProcessOutbound(var SitooLogEntry : Record "Sitoo Log Entry") : Integer;
    var
        Status : Integer;
    begin
        case SitooLogEntry."Sub Type" of
          'CUSTOMER': Status := SendUser(SitooLogEntry);
        end;

        exit(Status);
    end;

    procedure SerializeOutbounds(var Setup : Record "Sitoo Setup");
    var
        NextCheck : DateTime;
    begin
        if Setup."Send Invoice Customers" then begin
          NextCheck := Setup."Last Send Invoice Customers" + Setup."Send Inv. Customers Interval" * 60000;
          if (CURRENTDATETIME > NextCheck) or (GUIALLOWED) then begin
            SerializeCustomers(Setup);
            Setup."Last Send Invoice Customers" := CURRENTDATETIME;
            Setup.MODIFY;
          end;
        end;
    end;

    local procedure SerializeCustomers(var Setup : Record "Sitoo Setup");
    var
        String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
        SitooOutboundQueue : Record "Sitoo Outbound Queue";
        Common : Codeunit "Sitoo Common";
        SitooShipment : Record "Sitoo Shipment" temporary;
        SitooShipmentItem : Record "Sitoo Shipment Item" temporary;
        DeleteQueue : Boolean;
    begin
        if Setup."Send Invoice Customers" then begin
          SitooOutboundQueue.RESET;
          SitooOutboundQueue.SETRANGE("Market Code", Setup."Market Code");
          SitooOutboundQueue.SETRANGE(Type, 'USER');
          SitooOutboundQueue.SETRANGE("Sub Type", 'CUSTOMER');
          if SitooOutboundQueue.FINDSET then begin
            repeat
              SerializeCustomer(SitooOutboundQueue, String);
              Common.AddOutboundLogEntry(String, 'USER', 'CUSTOMER', 'SerializeCustomer', SitooOutboundQueue."Primary Key 1", SitooOutboundQueue.Action, Setup."Market Code");

              AddUser(SitooOutboundQueue);
              SitooOutboundQueue.DELETE;
              COMMIT;
            until SitooOutboundQueue.NEXT = 0;
          end;
        end;
    end;

    local procedure SerializeCustomer(var SitooOutboundQueue : Record "Sitoo Outbound Queue";var String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String");
    var
        JsonMgt : Codeunit "Sitoo Json Mgt";
        Customer : Record Customer;
    begin
        Customer.GET(SitooOutboundQueue."Primary Key 1");

        JsonMgt.StartJSon;

        JsonMgt.AddToJSon('email', Customer."E-Mail");
        JsonMgt.AddToJSon('namefirst', Customer.Name);
        //JsonMgt.AddToJSon('namelast', '');
        JsonMgt.AddToJSon('company', Customer."Name 2");
        //JsonMgt.AddToJSon('department', '');
        JsonMgt.AddToJSon('companyid', Customer."VAT Registration No.");
        JsonMgt.AddToJSon('address', Customer.Address);
        JsonMgt.AddToJSon('address2', Customer."Address 2");
        JsonMgt.AddToJSon('zip', Customer."Post Code");
        JsonMgt.AddToJSon('city', Customer.City);
        //JsonMgt.AddToJSon('state', '');
        if Customer."Country/Region Code" <> '' then
          JsonMgt.AddToJSon('countryid', Customer."Country/Region Code");
        JsonMgt.AddToJSon('phone', Customer."Phone No.");
        //JsonMgt.AddToJSon('mobile', '');
        JsonMgt.AddToJSon('notes', Customer."No.");
        //JsonMgt.AddToJSon('pricelistid', 0);

        JsonMgt.EndJSon;
        String := JsonMgt.GetJSon;
    end;

    local procedure SendUser(var SitooLogEntry : Record "Sitoo Log Entry") : Integer;
    var
        Common : Codeunit "Sitoo Common";
        Setup : Record "Sitoo Setup";
        Status : Integer;
        URL : Text;
        SitooUser : Record "Sitoo User";
    begin
        Setup.GET;
        if SitooLogEntry.Action = 'POST' then
          if GetUserId(SitooLogEntry) <> '' then
            SitooLogEntry.Action := 'PUT';

        if SitooLogEntry.Action = 'POST' then
          URL := Setup."Base URL" + 'sites/' + FORMAT(Setup."Site Id") + '/users.json';
        if SitooLogEntry.Action = 'PUT' then
          URL := Setup."Base URL" + 'sites/' + FORMAT(Setup."Site Id") + '/users/' + GetUserId(SitooLogEntry) + '.json';
        if SitooLogEntry.Action = 'DELETE' then
          URL := Setup."Base URL" + 'sites/' + FORMAT(Setup."Site Id") + '/users/' + GetUserId(SitooLogEntry) + '.json';

        Status := Common.UploadLogEntry(SitooLogEntry, 'SendUser', SitooLogEntry.Action='POST', URL);

        if Status > 0 then begin
          SitooLogEntry.Status := SitooLogEntry.Status::Processed;
          SitooLogEntry.MODIFY;
          if SitooLogEntry.Action = 'DELETE' then begin
            SitooUser.SETRANGE("Sitoo User Id", GetUserId(SitooLogEntry));
            if SitooUser.FINDFIRST then
              SitooUser.DELETE;
          end;
        end;

        exit(Status);
    end;

    local procedure AddUser(var SitooOutboundQueue : Record "Sitoo Outbound Queue");
    var
        SitooUser : Record "Sitoo User";
        Customer : Record Customer;
        Type : Integer;
    begin
        case SitooOutboundQueue."Sub Type" of
          'CUSTOMER': UserType := UserType::Customer;
          'VENDOR': UserType := UserType::Vendor;
          'USER': UserType := UserType::User;
        end;

        SitooUser.SETRANGE("Market Code", SitooOutboundQueue."Market Code");
        SitooUser.SETRANGE("No.", SitooOutboundQueue."Primary Key 1");
        SitooUser.SETRANGE("User Type", UserType);
        if not SitooUser.FINDFIRST then begin
          SitooUser.INIT;
          SitooUser."No." := SitooOutboundQueue."Primary Key 1";
          SitooUser."User Type" := UserType;
          SitooUser."Market Code" := SitooOutboundQueue."Market Code";
          SitooUser.INSERT;
        end;
    end;

    local procedure ProcessUser(var SitooLogEntry : Record "Sitoo Log Entry");
    var
        Common : Codeunit "Sitoo Common";
        XmlResponseDocument : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlDocument";
        XmlRootElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        XmlUserElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        SitooUser : Record "Sitoo User";
    begin
        Common.GetResponseXML(SitooLogEntry, XmlResponseDocument);

        XmlRootElement := XmlResponseDocument.DocumentElement;

        XmlUserElement := XmlRootElement.SelectSingleNode('root');

        case SitooLogEntry."Sub Type" of
          'CUSTOMER': UserType := UserType::Customer;
          'VENDOR': UserType := UserType::Vendor;
          'USER': UserType := UserType::User;
        end;

        SitooUser.SETRANGE("Market Code", SitooLogEntry."Market Code");
        SitooUser.SETRANGE("No.", SitooLogEntry."Document No.");
        SitooUser.SETRANGE("User Type", UserType);
        SitooUser.FINDFIRST;

        if SitooUser."Sitoo User Id" = '' then begin
          SitooUser."Sitoo User Id" := XmlUserElement.InnerXml;
          SitooUser.MODIFY;
        end;

        SitooLogEntry.Information := SitooUser."Sitoo User Id";
        SitooLogEntry.Status := SitooLogEntry.Status::Processed;
        SitooLogEntry.MODIFY;
    end;

    local procedure GetUserId(var SitooLogEntry : Record "Sitoo Log Entry") : Text;
    var
        SitooUser : Record "Sitoo User";
    begin
        case SitooLogEntry."Sub Type" of
          'CUSTOMER': UserType := UserType::Customer;
          'VENDOR': UserType := UserType::Vendor;
          'USER': UserType := UserType::User;
        end;

        SitooUser.SETRANGE("Market Code", SitooLogEntry."Market Code");
        SitooUser.SETRANGE("No.", SitooLogEntry."Document No.");
        SitooUser.SETRANGE("User Type", UserType);
        if SitooUser.FINDFIRST then;

        exit(SitooUser."Sitoo User Id");
    end;
}

