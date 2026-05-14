codeunit 50089 "GRX Main"
{
    Subtype = Install;

    trigger OnInstallAppPerDatabase()
    begin

    end;

    trigger OnInstallAppPerCompany()
    begin
        Fix_AsignarContactoCliente();
    end;

    local procedure Fix_AsignarContactoCliente()
    var
        ContactBusRelation: Record "Contact Business Relation";
    begin
        if ContactBusRelation.Get('CONT0000003092', 'CLIENTE') then
            ContactBusRelation.Delete(true);

        Clear(ContactBusRelation);
        ContactBusRelation."Contact No." := 'CONT0000004759';
        ContactBusRelation."Link to Table" := ContactBusRelation."Link to Table"::Customer;
        ContactBusRelation."Business Relation Code" := 'CLIENTE';
        ContactBusRelation."No." := '6165';
        ContactBusRelation.Insert();

    end;
}