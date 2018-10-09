codeunit 51310 "Sitoo Product Group Mgt"
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
            COMMIT;
          until Setup.NEXT = 0;
    end;

    procedure ProcessInbound(var SitooLogEntry : Record "Sitoo Log Entry");
    begin
        case SitooLogEntry."Sub Type" of
          'VATGROUPLIST': SaveVATGroups(SitooLogEntry);
        end;
    end;

    procedure ProcessOutbound(var SitooLogEntry : Record "Sitoo Log Entry") : Integer;
    var
        Status : Integer;
    begin
        case SitooLogEntry."Sub Type" of
          'PRODUCTGROUP': Status := SendCategory(SitooLogEntry);
        end;

        exit(Status);
    end;

    procedure SerializeOutbounds(var Setup : Record "Sitoo Setup");
    var
        NextCheck : DateTime;
    begin
        if Setup."Send Categories" then begin
          NextCheck := Setup."Last Send Categories" + Setup."Send Categories Interval" * 60000;
          if (CURRENTDATETIME > NextCheck) or (GUIALLOWED) then begin
            SerializeCategories(Setup);
            Setup."Last Send Categories" := CURRENTDATETIME;
            Setup.MODIFY;
          end;
        end;
    end;

    procedure GetProductGroups(var Setup : Record "Sitoo Setup");
    var
        Common : Codeunit "Sitoo Common";
        URL : Text;
    begin

        URL := Setup."Base URL" + 'sites/' + FORMAT(Setup."Site Id") + '/productgroups.json';

        Common.Download(URL, 'CATEGORY', 'VATGROUPLIST', 'GetProductGroups', '', Setup."Market Code");
    end;

    procedure SaveVATGroups(var SitooLogEntry : Record "Sitoo Log Entry");
    var
        Common : Codeunit "Sitoo Common";
        Counter : Integer;
        XmlDocument : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlDocument";
        XmlProductGroupList : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNodeList";
        XmlProductGroupElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";
        ProgressWindow : Dialog;
    begin

        Common.GetResponseXML(SitooLogEntry, XmlDocument);

        XmlProductGroupList := XmlDocument.GetElementsByTagName('items');

        if XmlProductGroupList.Count > 0 then begin
          Counter := 0;

          if GUIALLOWED then
            ProgressWindow.OPEN('Processing Product Group #1#######');

          repeat
            XmlProductGroupElement := XmlProductGroupList.Item(Counter);

            if GUIALLOWED then
              ProgressWindow.UPDATE(1, FORMAT(Counter));

            SaveVATGroup(XmlProductGroupElement, SitooLogEntry."Market Code");

            Counter += 1;
          until Counter = XmlProductGroupList.Count;

          if GUIALLOWED then
            ProgressWindow.CLOSE;
        end;

        SitooLogEntry.Information := FORMAT(Counter) + ' product groups';
        SitooLogEntry.Status := SitooLogEntry.Status::Processed;
        SitooLogEntry.MODIFY;
    end;

    local procedure SaveVATGroup(var XmlProductGroupElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";MarketCode : Code[20]);
    var
        Common : Codeunit "Sitoo Common";
        SitooVATProductGroup : Record "Sitoo VAT Product Group";
        VatId : Integer;
    begin
        VatId := Common.GetIntXML(XmlProductGroupElement, 'vatid');
        SitooVATProductGroup.SETRANGE("VAT Id", VatId);
        SitooVATProductGroup.SETRANGE("Market Code", MarketCode);
        if not SitooVATProductGroup.FINDFIRST then begin
          SitooVATProductGroup.INIT;
          SitooVATProductGroup."VAT Id" := VatId;
          SitooVATProductGroup."Market Code" := MarketCode;
          SitooVATProductGroup.INSERT;
        end;

        SitooVATProductGroup.Value := Common.GetIntXML(XmlProductGroupElement, 'value');
        SitooVATProductGroup."Product Group Type" := Common.GetIntXML(XmlProductGroupElement, 'productgrouptype');
        SitooVATProductGroup."Product Group Name" := Common.GetValueXML(XmlProductGroupElement, 'productgroupname');
        SitooVATProductGroup.MODIFY;
    end;

    procedure SerializeCategories(var Setup : Record "Sitoo Setup");
    var
        ItemCategory : Record "Item Category";
        SitooLogEntry : Record "Sitoo Log Entry";
        ProductGroup : Record "Product Group";
        EntryNo : Integer;
        SitooOutboundQueue : Record "Sitoo Outbound Queue";
        "Action" : Text;
    begin
        SitooOutboundQueue.SETRANGE("Market Code", Setup."Market Code");
        SitooOutboundQueue.SETRANGE(Type, 'CATEGORY');
        SitooOutboundQueue.SETRANGE("Sub Type", 'ITEMCATEGORY');
        if SitooOutboundQueue.FINDSET then begin
          repeat
            if ItemCategory.GET(SitooOutboundQueue."Primary Key 1") then begin
              if GetCategoryId(ItemCategory.Code, Setup."Market Code") > 0 then
                Action := 'PUT'
              else
                Action := 'POST';

              EntryNo := SerializeItemCategory(ItemCategory, Action, Setup."Market Code");
              if EntryNo > 0 then begin
                SitooLogEntry.GET(EntryNo);
                EntryNo := SendCategory(SitooLogEntry);
                SitooLogEntry.GET(EntryNo);
                if Action = 'POST' then
                  SaveCategoryId(SitooLogEntry);
              end;
            end;
            SitooOutboundQueue.DELETE;
          until SitooOutboundQueue.NEXT = 0;
        end;

        SitooOutboundQueue.SETRANGE("Market Code", Setup."Market Code");
        SitooOutboundQueue.SETRANGE(Type, 'CATEGORY');
        SitooOutboundQueue.SETRANGE("Sub Type", 'PRODUCTGROUP');
        if SitooOutboundQueue.FINDSET then begin
          repeat
            if ProductGroup.GET(SitooOutboundQueue."Primary Key 1", SitooOutboundQueue."Primary Key 2") then begin
              if GetCategoryId(ProductGroup."Item Category Code" + '-' + ProductGroup.Code, Setup."Market Code") > 0 then
                Action := 'PUT'
              else
                Action := 'POST';

              EntryNo := SerializeProductGroup(ProductGroup, Action, Setup."Market Code");
              if EntryNo > 0 then begin
                SitooLogEntry.GET(EntryNo);
                EntryNo := SendCategory(SitooLogEntry);
                SitooLogEntry.GET(EntryNo);
                if Action = 'POST' then
                  SaveCategoryId(SitooLogEntry);
              end;
            end;
            SitooOutboundQueue.DELETE;
          until SitooOutboundQueue.NEXT = 0;
        end;
    end;

    procedure SerializeAllCategories(var Setup : Record "Sitoo Setup");
    var
        ItemCategory : Record "Item Category";
        SitooLogEntry : Record "Sitoo Log Entry";
        ProductGroup : Record "Product Group";
        SitooProductCategory : Record "Sitoo Product Category";
        Levels : Integer;
        Level : Integer;
        EntryNo : Integer;
        "Action" : Text;
    begin

        Levels := 2;
        Level := 0;

        while Level < Levels do begin
          ItemCategory.SETRANGE(Indentation, Level);
          if ItemCategory.FINDSET then begin
            repeat
              if GetCategoryId(ItemCategory.Code, Setup."Market Code") > 0 then
                Action := 'PUT'
              else
                Action := 'POST';

              EntryNo := SerializeItemCategory(ItemCategory, Action, Setup."Market Code");
              if EntryNo > 0 then begin
                SitooLogEntry.GET(EntryNo);
                EntryNo := SendCategory(SitooLogEntry);
                SitooLogEntry.GET(EntryNo);
                if Action = 'POST' then
                  SaveCategoryId(SitooLogEntry);
              end;
            until ItemCategory.NEXT = 0;
          end;
          Level += 1;
        end;

        ProductGroup.SETFILTER(ProductGroup."Item Category Code", '<>%1', '');
        if ProductGroup.FINDSET then begin
          repeat
            if GetCategoryId(ProductGroup."Item Category Code" + '-' + ProductGroup.Code, Setup."Market Code") > 0 then
                Action := 'PUT'
              else
                Action := 'POST';

            EntryNo := SerializeProductGroup(ProductGroup, Action, Setup."Market Code");
            if EntryNo > 0 then begin
              SitooLogEntry.GET(EntryNo);
              EntryNo := SendCategory(SitooLogEntry);
              SitooLogEntry.GET(EntryNo);
              if Action = 'POST' then
                SaveCategoryId(SitooLogEntry);
            end;
          until ProductGroup.NEXT = 0;
        end;
    end;

    local procedure SerializeItemCategory(var ItemCategory : Record "Item Category";"Action" : Text;MarketCode : Code[20]) : Integer;
    var
        JsonMgt : Codeunit "Sitoo Json Mgt";
        Common : Codeunit "Sitoo Common";
        String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
        SubGroup : Boolean;
        ParentId : Integer;
        SitooProductCategory : Record "Sitoo Product Category";
        DocumentNo : Text;
        Title : Text;
        EntryNo : Integer;
    begin

        if ItemCategory."Parent Category" <> '' then begin
          SubGroup := true;
          SitooProductCategory.SETRANGE("Item Category", ItemCategory."Parent Category");
          SitooProductCategory.FINDFIRST;
          ParentId := SitooProductCategory."Category Id"
        end;

        DocumentNo := ItemCategory.Code;

        JsonMgt.StartJSon;
        JsonMgt.AddToJSon('title', ItemCategory.Description);
        if SubGroup then
          JsonMgt.AddIntProperty('categoryparentid', ParentId);

        JsonMgt.EndJSon;

        String := JsonMgt.GetJSon;

        EntryNo := Common.AddOutboundLogEntry(String, 'CATEGORY', 'ITEMCATEGORY', 'SerializeCategory', DocumentNo, Action, MarketCode);

        exit(EntryNo);
    end;

    local procedure SerializeProductGroup(var ProductGroup : Record "Product Group";"Action" : Text;var MarketCode : Code[20]) : Integer;
    var
        JsonMgt : Codeunit "Sitoo Json Mgt";
        Common : Codeunit "Sitoo Common";
        String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
        SubGroup : Boolean;
        ParentId : Integer;
        SitooProductCategory : Record "Sitoo Product Category";
        ItemCategory : Record "Item Category";
        DocumentNo : Text;
        Title : Text;
        EntryNo : Integer;
        Description : Text;
    begin

        ItemCategory.GET(ProductGroup."Item Category Code");

        SitooProductCategory.SETRANGE("Market Code", MarketCode);
        SitooProductCategory.SETRANGE("Item Category", ItemCategory.Code);
        SitooProductCategory.SETFILTER("Product Group", '%1', '');
        if SitooProductCategory.FINDFIRST then
          ParentId := SitooProductCategory."Category Id";

        DocumentNo := ItemCategory.Code + '-' + ProductGroup.Code;

        Description := ProductGroup.Description;
        if Description = '' then
          Description := ProductGroup.Code;

        JsonMgt.StartJSon;
        JsonMgt.AddToJSon('title', Description);
        if ParentId <> 0 then
          JsonMgt.AddIntProperty('categoryparentid', ParentId);
        JsonMgt.EndJSon;

        String := JsonMgt.GetJSon;

        EntryNo := Common.AddOutboundLogEntry(String, 'CATEGORY', 'PRODUCTGROUP', 'SerializeCategory', DocumentNo, Action, MarketCode);

        exit(EntryNo);
    end;

    procedure SendCategory(var SitooLogEntry : Record "Sitoo Log Entry") : Integer;
    var
        Setup : Record "Sitoo Setup";
        Common : Codeunit "Sitoo Common";
        Status : Integer;
    begin
        Setup.GET(SitooLogEntry."Market Code");

        if GetCategoryId(SitooLogEntry."Document No.", Setup."Market Code") > 0 then
          SitooLogEntry.Action := 'PUT';

        if SitooLogEntry.Action = 'POST' then
          Status := Common.UploadLogEntry(SitooLogEntry, 'SendCategory', true, Setup."Base URL" + 'sites/' + FORMAT(Setup."Site Id") + '/categories.json')
        else
          Status := Common.UploadLogEntry(SitooLogEntry, 'SendCategory', false, Setup."Base URL" + 'sites/' + FORMAT(Setup."Site Id") + '/categories/' + FORMAT(GetCategoryId(SitooLogEntry."Document No.", Setup."Market Code")) + '.json');

        if Status > 0 then begin
          SitooLogEntry.Status := SitooLogEntry.Status::Processed;
          SitooLogEntry.MODIFY;
        end;

        exit(Status);
    end;

    procedure SaveCategoryId(var SitooLogEntry : Record "Sitoo Log Entry");
    var
        Common : Codeunit "Sitoo Common";
        ResponsePostingExchField : Record "Data Exch. Field" temporary;
        SitooProductCategory : Record "Sitoo Product Category";
        CategoryId : Integer;
        ItemCategory : Code[20];
        ProductGroup : Code[10];
    begin
        Common.GetResponseRecords(SitooLogEntry, ResponsePostingExchField, '');

        ResponsePostingExchField.FINDFIRST;
        EVALUATE(CategoryId, ResponsePostingExchField.Value);

        if STRPOS(SitooLogEntry."Document No.", '-') <> 0 then begin
          ItemCategory := COPYSTR(SitooLogEntry."Document No.", 1, STRPOS(SitooLogEntry."Document No.", '-')-1);
          ProductGroup := COPYSTR(SitooLogEntry."Document No.", STRPOS(SitooLogEntry."Document No.", '-') + 1, STRLEN(SitooLogEntry."Document No."));
        end else
          ItemCategory := SitooLogEntry."Document No.";

        if not SitooProductCategory.GET(CategoryId, SitooLogEntry."Market Code") then begin
          SitooProductCategory.INIT;
          SitooProductCategory."Category Id" := CategoryId;
          SitooProductCategory."Market Code" := SitooLogEntry."Market Code";
          SitooProductCategory.VALIDATE("Item Category", ItemCategory);
          SitooProductCategory.VALIDATE("Product Group", ProductGroup);
          SitooProductCategory.INSERT;
        end;

        SitooLogEntry.Status := SitooLogEntry.Status::Processed;
        SitooLogEntry.MODIFY;
    end;

    local procedure GetCategoryId(DocumentNo : Text;MarketCode : Code[20]) : Integer;
    var
        ItemCategory : Code[20];
        ProductGroup : Code[20];
        SitooProductCategory : Record "Sitoo Product Category";
    begin
        if STRPOS(DocumentNo, '-') > 0 then begin
          ItemCategory := COPYSTR(DocumentNo, 1, STRPOS(DocumentNo, '-')-1);
          ProductGroup := COPYSTR(DocumentNo, STRPOS(DocumentNo, '-') + 1, STRLEN(DocumentNo));
        end else
          ItemCategory := DocumentNo;

        if ProductGroup <> '' then
          SitooProductCategory.SETRANGE("Product Group", ProductGroup);
        SitooProductCategory.SETRANGE("Item Category", ItemCategory);
        SitooProductCategory.SETRANGE("Market Code", MarketCode);
        if SitooProductCategory.FINDFIRST then
          exit(SitooProductCategory."Category Id");
        exit(-1);
    end;

    procedure DeleteCategories(var Setup : Record "Sitoo Setup");
    var
        SitooProductCategory : Record "Sitoo Product Category";
        Common : Codeunit "Sitoo Common";
        Request : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
    begin
        SitooProductCategory.SETRANGE("Market Code", Setup."Market Code");
        if SitooProductCategory.FINDSET then begin
          repeat
            Request := Setup."Base URL" + 'sites/' + FORMAT(Setup."Site Id") + '/categories/' + FORMAT(SitooProductCategory."Category Id") + '.json';
            Common.Upload(Request, 'CATEGORY', 'NAVIGATION', 'DeleteCategories', SitooProductCategory."Item Category", Request, 'DELETE', Setup."Market Code");
            SitooProductCategory.DELETE;
          until SitooProductCategory.NEXT = 0;
        end;
    end;

    procedure DownloadCategories(var Setup : Record "Sitoo Setup");
    var
        Common : Codeunit "Sitoo Common";
        URL : Text;
    begin

        URL := Setup."Base URL" + 'sites/' + FORMAT(Setup."Site Id") + '/categories.json?num=1000';

        Common.Download(URL, 'CATEGORY', 'LIST', 'DownloadCategories', '', Setup."Market Code");
    end;

    procedure ProcessDownloadList(var SitooLogEntry : Record "Sitoo Log Entry");
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

          SaveDownloadCategory(XmlNode, SitooLogEntry);

          Counter += 1;
        end;

        SitooLogEntry.Information := FORMAT(Counter) + ' categories downloaded';
        SitooLogEntry.Status := SitooLogEntry.Status::Processed;
        SitooLogEntry.MODIFY;
    end;

    procedure SaveDownloadCategory(var XmlNode : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlNode";var LogEntry : Record "Sitoo Log Entry");
    var
        Common : Codeunit "Sitoo Common";
        CategoryId : Integer;
        SitooProductCategory : Record "Sitoo Product Category";
    begin
        EVALUATE(CategoryId, Common.GetValueXML(XmlNode, 'categoryid'));

        if not SitooProductCategory.GET(CategoryId, LogEntry."Market Code") then begin
          SitooProductCategory.INIT;
          SitooProductCategory."Category Id" := CategoryId;
          SitooProductCategory."Market Code" := LogEntry."Market Code";
          SitooProductCategory.INSERT;
        end;
    end;
}

