codeunit 51304 "Sitoo Process Message"
{
    // version Sitoo 3.0

    TableNo = "Sitoo Log Entry";

    trigger OnRun();
    var
        Status : Integer;
    begin
        Rec.Status := Rec.Status::Error;
        Rec.MODIFY;

        case Rec.Direction of
          Rec.Direction::Inbound:
            ProcessInbound(Rec);
          Rec.Direction::Outbound:
            Status := ProcessOutbound(Rec);
        end;

        if Status <> -429 then
          KeepGoing := true
        else
          KeepGoing := false;
    end;

    var
        KeepGoing : Boolean;

    local procedure ProcessInbound(var SitooLogEntry : Record "Sitoo Log Entry");
    var
        SitooCashRegisterMgt : Codeunit "Sitoo Cash Register Mgt";
        SitooOrderMgt : Codeunit "Sitoo Order Mgt";
        SitooProductMgt : Codeunit "Sitoo Product Mgt";
        SitooWarehouseMgt : Codeunit "Sitoo Warehouse Mgt";
        SitooProductGroupMgt : Codeunit "Sitoo Product Group Mgt";
        SitooShipmentMgt : Codeunit "Sitoo Shipment Mgt";
        SitooUserMgt : Codeunit "Sitoo User Mgt";
    begin
        case SitooLogEntry.Type of
          'PRODUCT': SitooProductMgt.ProcessInbound(SitooLogEntry);
          'ORDER': SitooOrderMgt.ProcessInbound(SitooLogEntry);
          'CASHREGISTER': SitooCashRegisterMgt.ProcessInbound(SitooLogEntry);
          'WAREHOUSE': SitooWarehouseMgt.ProcessInbound(SitooLogEntry);
          'CATEGORY': SitooProductGroupMgt.ProcessInbound(SitooLogEntry);
          'SHIPMENT': SitooShipmentMgt.ProcessInbound(SitooLogEntry);
          'USER': SitooUserMgt.ProcessInbound(SitooLogEntry);
        end;
    end;

    local procedure ProcessOutbound(var SitooLogEntry : Record "Sitoo Log Entry") : Integer;
    var
        SitooCashRegisterMgt : Codeunit "Sitoo Cash Register Mgt";
        SitooOrderMgt : Codeunit "Sitoo Order Mgt";
        SitooProductMgt : Codeunit "Sitoo Product Mgt";
        SitooWarehouseMgt : Codeunit "Sitoo Warehouse Mgt";
        SitooProductGroupMgt : Codeunit "Sitoo Product Group Mgt";
        SitooShipmentMgt : Codeunit "Sitoo Shipment Mgt";
        SitooUserMgt : Codeunit "Sitoo User Mgt";
        Status : Integer;
    begin
        case SitooLogEntry.Type of
          'PRODUCT': Status := SitooProductMgt.ProcessOutbound(SitooLogEntry);
          'ORDER': Status := SitooOrderMgt.ProcessOutbound(SitooLogEntry);
          'CASHREGISTER': Status := SitooCashRegisterMgt.ProcessOutbound(SitooLogEntry);
          'WAREHOUSE': Status := SitooWarehouseMgt.ProcessOutbound(SitooLogEntry);
          'CATEGORY': Status := SitooProductGroupMgt.ProcessOutbound(SitooLogEntry);
          'SHIPMENT': Status := SitooShipmentMgt.ProcessOutbound(SitooLogEntry);
          'USER': SitooUserMgt.ProcessOutbound(SitooLogEntry);
        end;

        exit(Status);
    end;

    procedure Continue() : Boolean;
    begin
        exit(KeepGoing);
    end;
}

