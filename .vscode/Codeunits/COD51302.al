codeunit 51302 "Sitoo Json Mgt"
{
    // version Sitoo 3.0


    trigger OnRun();
    begin
    end;

    var
        StringBuilder : DotNet "'mscorlib'.System.Text.StringBuilder";
        StringWriter : DotNet "'mscorlib'.System.IO.StringWriter";
        StringReader : DotNet "'mscorlib'.System.IO.StringReader";
        JsonTextWriter : DotNet "'Newtonsoft.Json, Version=7.0.0.0, Culture=neutral, PublicKeyToken=30ad4fe6b2a6aeed'.Newtonsoft.Json.JsonTextWriter";
        JsonTextReader : DotNet "'Newtonsoft.Json, Version=7.0.0.0, Culture=neutral, PublicKeyToken=30ad4fe6b2a6aeed'.Newtonsoft.Json.JsonTextReader";

    local procedure Initialize();
    var
        Formatting : DotNet "'Newtonsoft.Json, Version=7.0.0.0, Culture=neutral, PublicKeyToken=30ad4fe6b2a6aeed'.Newtonsoft.Json.Formatting";
        StringEscapeHandling : DotNet "'Newtonsoft.Json, Version=7.0.0.0, Culture=neutral, PublicKeyToken=30ad4fe6b2a6aeed'.Newtonsoft.Json.StringEscapeHandling";
    begin
        StringBuilder := StringBuilder.StringBuilder;
        StringWriter := StringWriter.StringWriter(StringBuilder);
        JsonTextWriter := JsonTextWriter.JsonTextWriter(StringWriter);
        JsonTextWriter.Formatting := Formatting.Indented;
        JsonTextWriter.StringEscapeHandling := StringEscapeHandling.EscapeNonAscii;
    end;

    procedure StartJSon();
    begin
        if ISNULL(StringBuilder) then
          Initialize;
        JsonTextWriter.WriteStartObject;
    end;

    procedure StartJSonArray();
    begin
        if ISNULL(StringBuilder) then
          Initialize;
        JsonTextWriter.WriteStartArray;
    end;

    procedure AddJSonBranch(BranchName : Text);
    begin
        JsonTextWriter.WritePropertyName(BranchName);
        JsonTextWriter.WriteStartObject;
    end;

    procedure AddToJSon(VariableName : Text;Variable : Variant);
    begin
        JsonTextWriter.WritePropertyName(VariableName);
        JsonTextWriter.WriteValue(FORMAT(Variable,0,9));
    end;

    procedure AddProperty(VariableName : Text);
    begin
        JsonTextWriter.WritePropertyName(VariableName);
    end;

    procedure AddFormatValue(Variable : Variant);
    begin
        JsonTextWriter.WriteValue(FORMAT(Variable,0,9));
    end;

    procedure AddValueProperty(VariableName : Text;Variable : Variant);
    begin
        JsonTextWriter.WritePropertyName(VariableName);
        JsonTextWriter.WriteValue(Variable);
    end;

    procedure AddIntProperty(VariableName : Text;Variable : Integer);
    begin
        JsonTextWriter.WritePropertyName(VariableName);
        JsonTextWriter.WriteValue(Variable);
    end;

    procedure AddDecProperty(VariableName : Text;Variable : Decimal);
    begin
        JsonTextWriter.WritePropertyName(VariableName);
        JsonTextWriter.WriteValue(Variable);
    end;

    procedure AddBigIntProperty(VariableName : Text;Variable : BigInteger);
    begin
        JsonTextWriter.WritePropertyName(VariableName);
        JsonTextWriter.WriteValue(Variable);
    end;

    procedure AddBoolProperty(VariableName : Text;Variable : Boolean);
    begin
        JsonTextWriter.WritePropertyName(VariableName);
        JsonTextWriter.WriteValue(Variable);
    end;

    procedure AddValue(Variable : Variant);
    begin
        JsonTextWriter.WriteValue(Variable);
    end;

    procedure BeginJsonObject();
    begin
        JsonTextWriter.WriteStartObject;
    end;

    procedure EndJsonObject();
    begin
        JsonTextWriter.WriteEndObject;
    end;

    procedure EndJSonBranch();
    begin
        JsonTextWriter.WriteEndObject;
    end;

    procedure EndJSonArray();
    begin
        JsonTextWriter.WriteEndArray;
    end;

    procedure EndJSon();
    begin
        JsonTextWriter.WriteEndObject;
    end;

    procedure WriteEnd();
    begin
        JsonTextWriter.WriteEnd;
    end;

    procedure GetJSon() JSon : Text;
    begin
        JSon := StringBuilder.ToString;
        Initialize;
    end;

    procedure ReadJSon(var String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";var TempPostingExchField : Record "Data Exch. Field" temporary;GroupName : Text);
    var
        JsonToken : DotNet "'Newtonsoft.Json, Version=7.0.0.0, Culture=neutral, PublicKeyToken=30ad4fe6b2a6aeed'.Newtonsoft.Json.JsonToken";
        PrefixArray : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Array";
        PrefixString : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";
        PropertyName : Text;
        ColumnNo : Integer;
        InArray : array [250] of Boolean;
        GroupCount : Integer;
    begin
        PrefixArray := PrefixArray.CreateInstance(GETDOTNETTYPE(String),250);
        StringReader := StringReader.StringReader(String);
        JsonTextReader := JsonTextReader.JsonTextReader(StringReader);
        while JsonTextReader.Read do
          case true of
            JsonTextReader.TokenType.CompareTo(JsonToken.StartObject) = 0 :
              ;
            JsonTextReader.TokenType.CompareTo(JsonToken.StartArray) = 0 :
              begin
                InArray[JsonTextReader.Depth + 1] := true;
                ColumnNo := 0;
              end;
            JsonTextReader.TokenType.CompareTo(JsonToken.StartConstructor) = 0 :
              ;
            JsonTextReader.TokenType.CompareTo(JsonToken.PropertyName) = 0 :
              begin
                if FORMAT(JsonTextReader.Value,0,9) = GroupName then
                  GroupCount += 1;
                PrefixArray.SetValue(JsonTextReader.Value,JsonTextReader.Depth - 1);
                if JsonTextReader.Depth > 1 then begin
                  PrefixString := '[' + FORMAT(GroupCount) + ']' + PrefixString.Join('.',PrefixArray,0,JsonTextReader.Depth - 1);
                  if PrefixString.Length > 0 then
                    PropertyName := PrefixString.ToString + '.' + FORMAT(JsonTextReader.Value,0,9)
                  else
                    PropertyName := FORMAT(JsonTextReader.Value,0,9);
                end else
                  PropertyName := FORMAT(JsonTextReader.Value,0,9);
              end;
            JsonTextReader.TokenType.CompareTo(JsonToken.String) = 0 ,
            JsonTextReader.TokenType.CompareTo(JsonToken.Integer) = 0 ,
            JsonTextReader.TokenType.CompareTo(JsonToken.Float) = 0 ,
            JsonTextReader.TokenType.CompareTo(JsonToken.Boolean) = 0 ,
            JsonTextReader.TokenType.CompareTo(JsonToken.Date) = 0 ,
            JsonTextReader.TokenType.CompareTo(JsonToken.Bytes) = 0 :
              begin
                TempPostingExchField."Data Exch. No." := JsonTextReader.Depth;
                TempPostingExchField."Line No." := JsonTextReader.LineNumber;
                TempPostingExchField."Column No." := ColumnNo;
                TempPostingExchField."Node ID" := PropertyName;
                TempPostingExchField.Value := FORMAT(JsonTextReader.Value,0,9);
                TempPostingExchField."Data Exch. Line Def Code" := JsonTextReader.TokenType.ToString;
                TempPostingExchField.INSERT;
              end;
            JsonTextReader.TokenType.CompareTo(JsonToken.EndConstructor) = 0 :
              ;
            JsonTextReader.TokenType.CompareTo(JsonToken.EndArray) = 0 :
              InArray[JsonTextReader.Depth + 1] := false;
            JsonTextReader.TokenType.CompareTo(JsonToken.EndObject) = 0 :
              if JsonTextReader.Depth > 0 then
                if InArray[JsonTextReader.Depth] then ColumnNo += 1;
          end;
    end;

    procedure ReadFirstJSonValue(var String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";ParameterName : Text) ParameterValue : Text;
    var
        JsonToken : DotNet "'Newtonsoft.Json, Version=7.0.0.0, Culture=neutral, PublicKeyToken=30ad4fe6b2a6aeed'.Newtonsoft.Json.JsonToken";
        PropertyName : Text;
    begin
        StringReader := StringReader.StringReader(String);
        JsonTextReader := JsonTextReader.JsonTextReader(StringReader);
        while JsonTextReader.Read do
          case true of
            JsonTextReader.TokenType.CompareTo(JsonToken.PropertyName) = 0 :
              PropertyName := FORMAT(JsonTextReader.Value,0,9);
            (PropertyName = ParameterName) and not ISNULL(JsonTextReader.Value)  :
              begin
                ParameterValue := FORMAT(JsonTextReader.Value,0,9);
                exit;
              end;
          end;
    end;

    procedure UploadJSon(WebServiceURL : Text;UserName : Text;Password : Text;var String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";var Response : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";"Action" : Code[10];Authorization : Text);
    var
        HttpWebRequest : DotNet "'System, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Net.HttpWebRequest";
        HttpWebResponse : DotNet "'System, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Net.WebResponse";
    begin
        CreateWebRequest(HttpWebRequest,WebServiceURL,Action,Authorization);
        CreateCredentials(HttpWebRequest,UserName,Password);
        SetRequestStream(HttpWebRequest,String);
        DoWebRequest(HttpWebRequest,HttpWebResponse,'');
        GetResponseStream(HttpWebResponse,Response);
    end;

    procedure DownloadString(Url : Text;UserName : Text;Password : Text;var String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";Authorization : Text);
    var
        WebClient : DotNet "'System, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Net.WebClient";
        Credential : DotNet "'System, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Net.NetworkCredential";
    begin
        Credential := Credential.NetworkCredential;
        Credential.UserName := UserName;
        Credential.Password := Password;

        WebClient := WebClient.WebClient;
        WebClient.Credentials := Credential;

        if Authorization <> '' then
          WebClient.Headers.Add('Authorization', Authorization);

        String := WebClient.DownloadString(Url);
    end;

    procedure CreateWebRequest(var HttpWebRequest : DotNet "'System, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Net.HttpWebRequest";WebServiceURL : Text;Method : Text;Authorization : Text);
    var
        Setup : Record "Sitoo Setup";
    begin
        HttpWebRequest := HttpWebRequest.Create(WebServiceURL);
        HttpWebRequest.Timeout := 30000;
        HttpWebRequest.Method := Method;

        if Authorization <> '' then
          HttpWebRequest.Headers.Add('Authorization', Authorization);

        HttpWebRequest.Accept := 'application/json';
    end;

    procedure CreateCredentials(var HttpWebRequest : DotNet "'System, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Net.HttpWebRequest";UserName : Text;Password : Text);
    var
        Credential : DotNet "'System, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Net.NetworkCredential";
    begin
        Credential := Credential.NetworkCredential;
        Credential.UserName := UserName;
        Credential.Password := Password;
        HttpWebRequest.Credentials := Credential;
    end;

    procedure SetRequestStream(var HttpWebRequest : DotNet "'System, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Net.HttpWebRequest";var String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String");
    var
        StreamWriter : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.IO.StreamWriter";
        Encoding : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Text.Encoding";
    begin
        StreamWriter := StreamWriter.StreamWriter(HttpWebRequest.GetRequestStream,Encoding.GetEncoding('iso8859-1'));
        StreamWriter.Write(String);
        StreamWriter.Close;
    end;

    procedure DoWebRequest(var HttpWebRequest : DotNet "'System, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Net.HttpWebRequest";var HttpWebResponse : DotNet "'System, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Net.WebResponse";IgnoreCode : Code[10]);
    var
        NAVWebRequest : DotNet "'NAVWebRequest, Version=1.0.0.3, Culture=neutral, PublicKeyToken=null'.NAVWebRequest.NAVWebRequest";
        HttpWebException : DotNet "'System, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Net.WebException";
        HttpWebRequestError : TextConst ENU='Error: %1\%2',ISL='Stöðuvilla: %1\%2';
    begin
        NAVWebRequest := NAVWebRequest.NAVWebRequest;
        if not NAVWebRequest.DoRequest(HttpWebRequest,HttpWebException,HttpWebResponse) then
          HttpWebResponse := HttpWebException.Response;
    end;

    procedure GetResponseStream(var HttpWebResponse : DotNet "'System, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Net.WebResponse";var String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String");
    var
        StreamReader : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.IO.StreamReader";
        MemoryStream : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.IO.MemoryStream";
    begin
        StreamReader := StreamReader.StreamReader(HttpWebResponse.GetResponseStream);
        String := StreamReader.ReadToEnd;
    end;

    procedure GetValueFromJsonString(var String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";ParameterName : Text;GroupName : Text) : Text;
    var
        TempPostingExchField : Record "Data Exch. Field" temporary;
    begin
        ReadJSon(String,TempPostingExchField, GroupName);
        exit(GetJsonValue(TempPostingExchField,ParameterName));
    end;

    procedure GetJsonValue(var TempPostingExchField : Record "Data Exch. Field" temporary;ParameterName : Text) : Text;
    begin
        with TempPostingExchField do begin
          SETRANGE("Node ID",ParameterName);
          if FINDFIRST then exit(Value);
        end;
    end;

    procedure NodeExists(var TempPostingExchField : Record "Data Exch. Field" temporary;ParameterName : Text) : Boolean;
    begin
        with TempPostingExchField do begin
          SETRANGE("Node ID",ParameterName);
          if FINDFIRST then exit(true);
        end;
    end;

    procedure StringToXML(var String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";var XmlDocument : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlDocument");
    var
        JsonConvert : DotNet "'Newtonsoft.Json, Version=7.0.0.0, Culture=neutral, PublicKeyToken=30ad4fe6b2a6aeed'.Newtonsoft.Json.JsonConvert";
        XmlDocElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlElement";
        XmlElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlElement";
        XmlResponseElement : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlElement";
        XmlDocFragment : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlDocumentFragment";
    begin
        if not DeserializeXmlNode(String, XmlDocument) then begin
          XmlDocument := XmlDocument.XmlDocument;
          XmlDocument.LoadXml('<nav/>');
          XmlDocElement := XmlDocument.DocumentElement;
          AddXMLElement(XmlDocElement, 'root', '', '', XmlResponseElement);
          AddXMLElement(XmlResponseElement, 'errortext', String.ToString, '', XmlElement);
        end;
    end;

    [TryFunction]
    local procedure DeserializeXmlNode(var String : DotNet "'mscorlib, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.String";var XmlDocument : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlDocument");
    var
        JsonConvert : DotNet "'Newtonsoft.Json, Version=7.0.0.0, Culture=neutral, PublicKeyToken=30ad4fe6b2a6aeed'.Newtonsoft.Json.JsonConvert";
    begin
        XmlDocument := JsonConvert.DeserializeXmlNode('{"root":' + String.ToString + '}', 'root');
    end;

    procedure AddXMLElement(var ParentXmlElementIN : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlElement";NameIN : Text[100];ValueIN : Text;NameSpaceIN : Text[250];var ChildXmlElementIN : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlElement");
    var
        ParentXmlDoc : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlDocument";
        XmlText : DotNet "'System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089'.System.Xml.XmlText";
    begin

        ParentXmlDoc := ParentXmlElementIN.OwnerDocument;

        ChildXmlElementIN := ParentXmlDoc.CreateElement(NameIN, NameSpaceIN);
        if ValueIN <> '' then begin
          XmlText := ParentXmlDoc.CreateTextNode(ValueIN);
          ChildXmlElementIN.AppendChild(XmlText);
        end;

        ParentXmlElementIN.AppendChild(ChildXmlElementIN);
    end;
}

