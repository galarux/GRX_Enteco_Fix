codeunit 50018 "GRX Main"
{
    Subtype = Install;

    trigger OnRun()
    var
        Cust: Record Customer;
    begin
        Cust."No." := 'DOR';
        Cust.Insert();
    end;
}