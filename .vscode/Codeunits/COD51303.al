codeunit 51303 "Sitoo Process Mgt"
{
    // version Sitoo 3.0


    trigger OnRun();
    var
        Common : Codeunit "Sitoo Common";
        Setup : Record "Sitoo Setup";
    begin

        Setup.SETRANGE(Active, true);
        if Setup.FINDSET then
          repeat
            ProcessMessages(Setup);
          until Setup.NEXT = 0;

        Setup.RESET;
        Setup.SETRANGE(Active, true);
        if Setup.FINDSET then
          repeat
            ProcessQueue(Setup);
          until Setup.NEXT = 0;
    end;

    local procedure ProcessMessages(var Setup : Record "Sitoo Setup");
    var
        SitooLogEntry : Record "Sitoo Log Entry";
        SitooProcessMessage : Codeunit "Sitoo Process Message";
    begin
        SitooLogEntry.SETRANGE(Direction, SitooLogEntry.Direction::Inbound);
        SitooLogEntry.SETRANGE(Status, SitooLogEntry.Status::Unprocessed);
        SitooLogEntry.SETRANGE("Market Code", Setup."Market Code");
        if SitooLogEntry.FINDSET then repeat
          if not SitooProcessMessage.RUN(SitooLogEntry) then begin
            SitooLogEntry.GET(SitooLogEntry."Entry No.");
            SitooLogEntry.Status := SitooLogEntry.Status::Error;
            SitooLogEntry.Information := COPYSTR(GETLASTERRORTEXT, 1, MAXSTRLEN(SitooLogEntry.Information));
            SitooLogEntry.MODIFY;
            COMMIT;
          end;
        until SitooLogEntry.NEXT = 0;

        SitooLogEntry.RESET;
        SitooLogEntry.SETRANGE(Direction, SitooLogEntry.Direction::Outbound);
        SitooLogEntry.SETRANGE(Status, SitooLogEntry.Status::Unprocessed);
        SitooLogEntry.SETRANGE("Market Code", Setup."Market Code");
        if SitooLogEntry.FINDSET then repeat
          if not SitooProcessMessage.RUN(SitooLogEntry) then begin
            SitooLogEntry.GET(SitooLogEntry."Entry No.");
            SitooLogEntry.Status := SitooLogEntry.Status::Error;
            SitooLogEntry.Information := COPYSTR(GETLASTERRORTEXT, 1, MAXSTRLEN(SitooLogEntry.Information));
            SitooLogEntry.MODIFY;
            COMMIT;
          end;
          if not SitooProcessMessage.Continue then
            exit;
        until SitooLogEntry.NEXT = 0;
    end;

    procedure ProcessMessage(var SitooLogEntry : Record "Sitoo Log Entry");
    begin
        if not CODEUNIT.RUN(CODEUNIT::"Sitoo Process Message", SitooLogEntry) then begin
          SitooLogEntry.GET(SitooLogEntry."Entry No.");
          SitooLogEntry.Status := SitooLogEntry.Status::Error;
          SitooLogEntry.Information := COPYSTR(GETLASTERRORTEXT, 1, MAXSTRLEN(SitooLogEntry.Information));
          SitooLogEntry.MODIFY;
          COMMIT;
        end;
    end;

    procedure ProcessQueue(var Setup : Record "Sitoo Setup");
    var
        SitooProductMgt : Codeunit "Sitoo Product Mgt";
        SitooWarehouseMgt : Codeunit "Sitoo Warehouse Mgt";
        SitooProductGroupMgt : Codeunit "Sitoo Product Group Mgt";
        SitooShipmentMgt : Codeunit "Sitoo Shipment Mgt";
        SitooUserMgt : Codeunit "Sitoo User Mgt";
    begin
        SitooProductMgt.SerializeOutbounds(Setup);
        SitooWarehouseMgt.SerializeOutbounds(Setup);
        SitooProductGroupMgt.SerializeOutbounds(Setup);
        SitooShipmentMgt.SerializeOutbounds(Setup);
        SitooUserMgt.SerializeOutbounds(Setup);
    end;
}

