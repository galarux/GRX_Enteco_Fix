codeunit 50089 "GRX Main"
{
    procedure Fix_Imprimase()
    var
        RecItem: Record Item;
    begin
        RecItem.Get('P8AZ6203006');
        RecItem."Enteco Imprimase" := RecItem."Enteco Imprimase".Trim();
        RecItem.Modify();
    end;

    procedure Fix_AsignarContactoCliente()
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

    procedure CorregirOts()
    begin

    end;

    procedure CorregirOT(numOt: code[20])
    var
        LinOT: Record "Enteco Production Order Line";
        Cantidad: Decimal;
    begin
        LinOT.SetRange(Tipo, LinOT.Tipo::OT);
        LinOT.SetRange("Prod. Order No.", numOt);
        LinOT.SetRange("Tipo Linea", LinOT."Tipo Linea"::Maquina);
        if LinOT.FindFirst() then begin
            LinOT."Fase Siguiente 1" := 2;
            LinOT.Modify();
            Cantidad := LinOT.Cantidad;

            Clear(LinOT);
            LinOT.Tipo := LinOT.Tipo::OT;
            LinOT."Prod. Order No." := numOT;
            LinOT."No." := 'CORTADORA C-0';
            LinOT."Tipo Linea" := LinOT."Tipo Linea"::Maquina;
            LinOT.Fase := 2;
            LinOT.Secuencia := 0;
            LinOT.Cantidad := Cantidad;
            LinOT."Cod. Unidad Medida" := 'ML';
            LinOT."Fase Siguiente 1" := 2;
            LinOT.Insert();
        end;
    end;

    internal procedure BorraCortePersonalizado()
    var
        CabEstructura: Record "Enteco Cabecera Estructura";
        CabCortesPerso: Record "Enteco Cab Cortes Perso";
        LinCortesPerso: Record "Enteco Lin Cortes Perso";
        PI: Record "Enteco Pedido Interno";
    begin
        // CabCortesPerso.Get(CabCortesPerso.Tipo::OT,
        //                    '2026400079',
        //                    CabCortesPerso."Tipo Linea"::Maquina,
        //                    'CORTADORA C-8',
        //                    1,
        //                    0);
        // CabCortesPerso.Delete();
        // //Cabecera Corte 
        // //key(PK; Tipo, "Prod. Order No.", "Tipo Linea", "No. Maquina", Fase, Secuencia)
        // CabCortesPerso.Get(CabCortesPerso.Tipo::OT,
        //                    '2026400079',
        //                    CabCortesPerso."Tipo Linea"::Maquina,
        //                    'CORTADORA C-0',
        //                    1,
        //                    0);
        // CabCortesPerso.Rename(CabCortesPerso.Tipo::OT,
        //                    '2026400079',
        //                    CabCortesPerso."Tipo Linea"::Maquina,
        //                    'CORTADORA C-8',
        //                    1,
        //                    0);

        // //Linea Corte 1
        // //  key(Key1; Tipo, "Prod. Order No.", "Tipo Linea", "No. Maquina", Fase, Secuencia, "Num. Cortes") { Clustered = true; }                           
        // LinCortesPerso.Get(LinCortesPerso.Tipo::OT,
        //                    '2026400079',
        //                    LinCortesPerso."Tipo Linea"::Maquina,
        //                    'CORTADORA C-0',
        //                    1,
        //                    0,
        //                    1);
        // LinCortesPerso.Rename(LinCortesPerso.Tipo::OT,
        //                    '2026400079',
        //                    LinCortesPerso."Tipo Linea"::Maquina,
        //                    'CORTADORA C-8',
        //                    1,
        //                    0,
        //                    1);
        // //Linea Corte 2
        // LinCortesPerso.Get(LinCortesPerso.Tipo::OT,
        //                    '2026400079',
        //                    LinCortesPerso."Tipo Linea"::Maquina,
        //                    'CORTADORA C-0',
        //                    1,
        //                    0,
        //                    2);
        // LinCortesPerso.Rename(LinCortesPerso.Tipo::OT,
        //                    '2026400079',
        //                    LinCortesPerso."Tipo Linea"::Maquina,
        //                    'CORTADORA C-8',
        //                    1,
        //                    0,
        //                    2);
        CabEstructura.Get(CabEstructura.Tipo::PedidoInterno, '9390000001', '505 X 1(935)');
        CabEstructura."Ancho total" := 940;
        CabEstructura.Modify();
    end;


}