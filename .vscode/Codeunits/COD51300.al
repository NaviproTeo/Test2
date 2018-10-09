codeunit 51300 "Sitoo Mgt"
{
    // version Sitoo 3.0


    trigger OnRun();
    var
        SitooSetup : Record "Sitoo Setup";
    begin
        //SitooSetup.GET;
        //IF SitooSetup.Company <> COMPANYNAME THEN
        //  EXIT;

        if not CODEUNIT.RUN(CODEUNIT::"Sitoo Product Mgt") then
           MESSAGE('Product Mgt error:\ "' + GETLASTERRORTEXT +'"');

        if not CODEUNIT.RUN(CODEUNIT::"Sitoo Order Mgt") then
           MESSAGE('Order Mgt error:\ "' + GETLASTERRORTEXT +'"');

        if not CODEUNIT.RUN(CODEUNIT::"Sitoo Cash Register Mgt") then
           MESSAGE('Cash Register Mgt error:\ "' + GETLASTERRORTEXT +'"');

        if not CODEUNIT.RUN(CODEUNIT::"Sitoo Warehouse Mgt") then
           MESSAGE('Warehouse Mgt error:\ "' + GETLASTERRORTEXT +'"');

        if not CODEUNIT.RUN(CODEUNIT::"Sitoo Voucher Mgt") then
           MESSAGE('Voucher Mgt error:\ "' + GETLASTERRORTEXT +'"');

        if not CODEUNIT.RUN(CODEUNIT::"Sitoo Product Group Mgt") then
           MESSAGE('Product Group Mgt error:\ "' + GETLASTERRORTEXT +'"');

        if not CODEUNIT.RUN(CODEUNIT::"Sitoo Process Mgt") then
           MESSAGE('Process Mgt error:\ "' + GETLASTERRORTEXT +'"');
    end;
}

