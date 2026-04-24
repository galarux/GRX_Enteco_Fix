codeunit 50089 "GRX Main"
{
    Subtype = Install;

    trigger OnInstallAppPerDatabase()
    begin

    end;

    trigger OnInstallAppPerCompany()
    var
        Cust: Record Customer;
    begin
        if CompanyName() = 'Enteco_Pharma' then begin
            Cust.Get('DOR');
            Cust.Delete();
        end
    end;
}