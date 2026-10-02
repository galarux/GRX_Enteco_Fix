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

    // Ficha 00001. Carga desde el Excel de la consulta a Oracle (hoja «Reparar») el recurso finalizado y
    // el estado de cola de las OT creadas en BC, en la OT de Planificación (50050) y en la orden estándar (5405).
    procedure RepararRecursoColaOT(Simular: Boolean)
    var
        UltimaFila: Integer;
        Fila: Integer;
    begin
        case CompanyName() of
            'Enteco_Pharma':
                CodigoEmpresaOracle := '10';
            'Enteco_Manviel':
                CodigoEmpresaOracle := '05';
            else
                Error(EmpresaDesconocidaErr, CompanyName());
        end;

        IniciarResultado(Simular);
        LeerExcel('Reparar');

        TempExcelBuffer.Reset();
        if TempExcelBuffer.FindLast() then
            UltimaFila := TempExcelBuffer."Row No.";
        for Fila := 2 to UltimaFila do
            if EsDeEstaEmpresa(ValorCelda(Fila, 1)) then
                RepararRecursoColaFila(Fila);

        ExportarResultado('GRX Fix Recurso Cola OT');
        Message(FilasTotalesMsg, ModoTxt(), NumFilas, NumCambiado, NumYaEstaba, NumNoExiste, NumError);
    end;

    // Ficha 00001. Completa con la unidad base del producto las líneas de material de las estructuras
    // (50021), las líneas de OTT/OT (50051) y los componentes de las órdenes estándar (5407) sin unidad.
    procedure RepararUnidadComponentes(Simular: Boolean)
    begin
        IniciarResultado(Simular);
        RepararUnidadLineasEstructura();
        RepararUnidadLineasOT();
        RepararUnidadComponentesOrden();
        ExportarResultado('GRX Fix Unidad Componentes');
        Message(TotalesMsg, ModoTxt(), NumCambiado, NumError);
    end;

    local procedure RepararRecursoColaFila(Fila: Integer)
    var
        OT: Record "Enteco Production Order";
        ProdOrder: Record "Production Order";
        Numero: Code[20];
        Recurso: Code[40];
        EstadoCola: Text;
        ExisteOT: Boolean;
        ExisteOrden: Boolean;
        HayCambios: Boolean;
    begin
        NumFilas += 1;
        Numero := CopyStr(ValorCelda(Fila, 2), 1, MaxStrLen(Numero));
        Recurso := CopyStr(ValorCelda(Fila, 3), 1, MaxStrLen(Recurso));
        EstadoCola := ValorCelda(Fila, 4);

        ExisteOT := OT.Get(OT.Tipo::OT, Numero);
        ProdOrder.SetRange("No.", Numero);
        ExisteOrden := ProdOrder.FindFirst();

        if not ExisteOT then
            AnadirResultado(TablaOTTxt, Numero, '', '', '', NoExisteTxt);
        if not ExisteOrden then
            AnadirResultado(TablaOrdenTxt, Numero, '', '', '', NoExisteTxt);
        if not (ExisteOT or ExisteOrden) then
            exit;

        if Recurso <> '' then begin
            if ExisteOT then
                if OT."Recurso finalizado" = Recurso then
                    AnadirResultado(TablaOTTxt, Numero, OT.FieldCaption("Recurso finalizado"), OT."Recurso finalizado", Recurso, YaEstabaTxt)
                else begin
                    AnadirResultado(TablaOTTxt, Numero, OT.FieldCaption("Recurso finalizado"), OT."Recurso finalizado", Recurso, CambiadoTxt);
                    OT."Recurso finalizado" := Recurso;
                    HayCambios := true;
                end;
            if ExisteOrden then
                if ProdOrder."Enteco Recurso finalizado" = Recurso then
                    AnadirResultado(TablaOrdenTxt, Numero, ProdOrder.FieldCaption("Enteco Recurso finalizado"), ProdOrder."Enteco Recurso finalizado", Recurso, YaEstabaTxt)
                else begin
                    AnadirResultado(TablaOrdenTxt, Numero, ProdOrder.FieldCaption("Enteco Recurso finalizado"), ProdOrder."Enteco Recurso finalizado", Recurso, CambiadoTxt);
                    ProdOrder."Enteco Recurso finalizado" := Recurso;
                    HayCambios := true;
                end;
        end;

        case EstadoCola of
            '':
                ;
            '1':
                HayCambios := AplicarEstadoCola(OT, ProdOrder, ExisteOT, ExisteOrden, Numero,
                    OT."Estado Cola"::AsignadaCola, ProdOrder."Enteco Estado Cola"::Asignada) or HayCambios;
            '2':
                HayCambios := AplicarEstadoCola(OT, ProdOrder, ExisteOT, ExisteOrden, Numero,
                    OT."Estado Cola"::DesasignadaCola, ProdOrder."Enteco Estado Cola"::Desasignada) or HayCambios;
            else
                AnadirResultado('', Numero, OT.FieldCaption("Estado Cola"), '', EstadoCola, StrSubstNo(EstadoColaNoValidoTxt, EstadoCola));
        end;

        // Sin triggers: el OnModify de la 50050 resincroniza la orden estándar con Commit, y aquí se
        // escriben las dos tablas a la vez.
        if HayCambios and not SimularActivo then begin
            if ExisteOT then
                OT.Modify(false);
            if ExisteOrden then
                ProdOrder.Modify(false);
        end;
    end;

    local procedure AplicarEstadoCola(var OT: Record "Enteco Production Order"; var ProdOrder: Record "Production Order"; ExisteOT: Boolean; ExisteOrden: Boolean; Numero: Code[20]; EstadoOT: Enum "Enteco Tipo Estado Cola"; EstadoOrden: Option) HayCambios: Boolean
    begin
        if ExisteOT then
            if OT."Estado Cola" = EstadoOT then
                AnadirResultado(TablaOTTxt, Numero, OT.FieldCaption("Estado Cola"), Format(OT."Estado Cola"), Format(EstadoOT), YaEstabaTxt)
            else begin
                AnadirResultado(TablaOTTxt, Numero, OT.FieldCaption("Estado Cola"), Format(OT."Estado Cola"), Format(EstadoOT), CambiadoTxt);
                OT."Estado Cola" := EstadoOT;
                HayCambios := true;
            end;
        if ExisteOrden then
            if ProdOrder."Enteco Estado Cola" = EstadoOrden then
                AnadirResultado(TablaOrdenTxt, Numero, ProdOrder.FieldCaption("Enteco Estado Cola"), Format(ProdOrder."Enteco Estado Cola"), FormatEstadoOrden(EstadoOrden), YaEstabaTxt)
            else begin
                AnadirResultado(TablaOrdenTxt, Numero, ProdOrder.FieldCaption("Enteco Estado Cola"), Format(ProdOrder."Enteco Estado Cola"), FormatEstadoOrden(EstadoOrden), CambiadoTxt);
                ProdOrder."Enteco Estado Cola" := EstadoOrden;
                HayCambios := true;
            end;
    end;

    local procedure FormatEstadoOrden(EstadoOrden: Option) Texto: Text
    var
        ProdOrder: Record "Production Order";
    begin
        ProdOrder."Enteco Estado Cola" := EstadoOrden;
        Texto := Format(ProdOrder."Enteco Estado Cola");
    end;

    // Acepta '5' además de '05' por si Excel se come el cero de la izquierda.
    local procedure EsDeEstaEmpresa(Valor: Text): Boolean
    begin
        exit(DelChr(Valor.Trim(), '<', '0') = DelChr(CodigoEmpresaOracle, '<', '0'));
    end;

    local procedure RepararUnidadLineasEstructura()
    var
        Linea: Record "Enteco Linea Estructura";
        LineaModificar: Record "Enteco Linea Estructura";
        Unidad: Code[10];
        Clave: Text;
    begin
        Linea.SetRange("Tipo Linea", Linea."Tipo Linea"::Producto);
        Linea.SetRange("Unidad Medida", '');
        if Linea.FindSet() then
            repeat
                Clave := StrSubstNo(ClaveEstructuraTxt, Linea.Tipo, Linea."Source No.", Linea."No. Estructura", Linea."No.", Linea.Fase, Linea.Secuencia);
                if UnidadBase(Linea."No.", '50021 Enteco Linea Estructura', Clave, Linea.FieldCaption("Unidad Medida"), Unidad) then
                    if not SimularActivo then begin
                        LineaModificar := Linea;
                        LineaModificar."Unidad Medida" := Unidad;
                        LineaModificar.Modify(false);
                    end;
            until Linea.Next() = 0;
    end;

    local procedure RepararUnidadLineasOT()
    var
        Linea: Record "Enteco Production Order Line";
        LineaModificar: Record "Enteco Production Order Line";
        Unidad: Code[10];
        Clave: Text;
    begin
        Linea.SetRange("Tipo Linea", Linea."Tipo Linea"::Producto);
        Linea.SetRange("Cod. Unidad Medida", '');
        if Linea.FindSet() then
            repeat
                Clave := StrSubstNo(ClaveLineaOTTxt, Linea.Tipo, Linea."Prod. Order No.", Linea."No.", Linea.Fase, Linea.Secuencia);
                if UnidadBase(Linea."No.", '50051 Enteco Production Order Line', Clave, Linea.FieldCaption("Cod. Unidad Medida"), Unidad) then
                    if not SimularActivo then begin
                        // Sin triggers: el OnModify de la 50051 resincroniza la orden estándar con Commit.
                        LineaModificar := Linea;
                        LineaModificar."Cod. Unidad Medida" := Unidad;
                        LineaModificar.Modify(false);
                    end;
            until Linea.Next() = 0;
    end;

    local procedure RepararUnidadComponentesOrden()
    var
        Comp: Record "Prod. Order Component";
        CompModificar: Record "Prod. Order Component";
        Unidad: Code[10];
        Clave: Text;
    begin
        Comp.SetFilter(Status, '%1|%2|%3', Comp.Status::Planned, Comp.Status::"Firm Planned", Comp.Status::Released);
        Comp.SetRange("Unit of Measure Code", '');
        Comp.SetFilter("Item No.", '<>%1', '');
        if Comp.FindSet() then
            repeat
                Clave := StrSubstNo(ClaveComponenteTxt, Comp.Status, Comp."Prod. Order No.", Comp."Prod. Order Line No.", Comp."Line No.", Comp."Item No.");
                if UnidadBase(Comp."Item No.", '5407 Prod. Order Component', Clave, Comp.FieldCaption("Unit of Measure Code"), Unidad) then
                    if not SimularActivo then begin
                        // Asignación directa, sin Validate, como CompletarUnidadMedidaComponentes de la
                        // Codeunit 50005: con la unidad en blanco ya se aplicaba factor 1, así que no
                        // cambia ninguna cantidad.
                        CompModificar := Comp;
                        CompModificar."Unit of Measure Code" := Unidad;
                        CompModificar."Qty. per Unit of Measure" := 1;
                        CompModificar.Modify(false);
                    end;
            until Comp.Next() = 0;
    end;

    // Devuelve en Unidad la unidad base del producto y deja la fila en el Excel de resultado. El valor
    // anterior siempre es la unidad en blanco: solo se revisan registros sin unidad.
    local procedure UnidadBase(ItemNo: Code[20]; Tabla: Text; Clave: Text; Campo: Text; var Unidad: Code[10]): Boolean
    var
        Item: Record Item;
    begin
        Unidad := '';
        Item.SetLoadFields("Base Unit of Measure");
        if not Item.Get(ItemNo) then begin
            AnadirResultado(Tabla, Clave, Campo, '', '', ProductoNoExisteTxt);
            exit(false);
        end;
        if Item."Base Unit of Measure" = '' then begin
            AnadirResultado(Tabla, Clave, Campo, '', '', SinUnidadBaseTxt);
            exit(false);
        end;
        Unidad := Item."Base Unit of Measure";
        AnadirResultado(Tabla, Clave, Campo, '', Unidad, CambiadoTxt);
        exit(true);
    end;

    local procedure LeerExcel(Hoja: Text)
    var
        InStr: InStream;
        NombreFichero: Text;
    begin
        if not UploadIntoStream(SubirExcelTxt, '', 'Excel (*.xlsx)|*.xlsx', NombreFichero, InStr) then
            Error('');
        TempExcelBuffer.Reset();
        TempExcelBuffer.DeleteAll();
        TempExcelBuffer.OpenBookStream(InStr, Hoja);
        TempExcelBuffer.ReadSheet();
    end;

    local procedure ValorCelda(Fila: Integer; Columna: Integer): Text
    begin
        if TempExcelBuffer.Get(Fila, Columna) then
            exit(TempExcelBuffer."Cell Value as Text".Trim());
        exit('');
    end;

    local procedure IniciarResultado(Simular: Boolean)
    begin
        SimularActivo := Simular;
        NumFilas := 0;
        NumCambiado := 0;
        NumYaEstaba := 0;
        NumNoExiste := 0;
        NumError := 0;

        TempResultado.Reset();
        TempResultado.DeleteAll();
        TempResultado.NewRow();
        TempResultado.AddColumn('Tabla', false, '', true, false, false, '', TempResultado."Cell Type"::Text);
        TempResultado.AddColumn('Clave', false, '', true, false, false, '', TempResultado."Cell Type"::Text);
        TempResultado.AddColumn('Campo', false, '', true, false, false, '', TempResultado."Cell Type"::Text);
        TempResultado.AddColumn('Valor anterior', false, '', true, false, false, '', TempResultado."Cell Type"::Text);
        TempResultado.AddColumn('Valor nuevo', false, '', true, false, false, '', TempResultado."Cell Type"::Text);
        TempResultado.AddColumn('Resultado', false, '', true, false, false, '', TempResultado."Cell Type"::Text);
    end;

    local procedure AnadirResultado(Tabla: Text; Clave: Text; Campo: Text; ValorAnterior: Text; ValorNuevo: Text; Resultado: Text)
    begin
        TempResultado.NewRow();
        TempResultado.AddColumn(Tabla, false, '', false, false, false, '', TempResultado."Cell Type"::Text);
        TempResultado.AddColumn(Clave, false, '', false, false, false, '', TempResultado."Cell Type"::Text);
        TempResultado.AddColumn(Campo, false, '', false, false, false, '', TempResultado."Cell Type"::Text);
        TempResultado.AddColumn(ValorAnterior, false, '', false, false, false, '', TempResultado."Cell Type"::Text);
        TempResultado.AddColumn(ValorNuevo, false, '', false, false, false, '', TempResultado."Cell Type"::Text);
        TempResultado.AddColumn(Resultado, false, '', false, false, false, '', TempResultado."Cell Type"::Text);

        case Resultado of
            CambiadoTxt:
                NumCambiado += 1;
            YaEstabaTxt:
                NumYaEstaba += 1;
            NoExisteTxt:
                NumNoExiste += 1;
            else
                NumError += 1;
        end;
    end;

    local procedure ExportarResultado(Proceso: Text)
    begin
        TempResultado.CreateNewBook('Resultado');
        TempResultado.WriteSheet('Resultado', CompanyName(), UserId());
        TempResultado.CloseBook();
        TempResultado.SetFriendlyFilename(StrSubstNo(NombreFicheroTxt, Proceso, CompanyName(), ModoTxt()));
        TempResultado.OpenExcel();
    end;

    local procedure ModoTxt(): Text
    begin
        if SimularActivo then
            exit(SimulacionTxt);
        exit(EjecucionTxt);
    end;

    var
        TempExcelBuffer: Record "Excel Buffer" temporary;
        TempResultado: Record "Excel Buffer" temporary;
        SimularActivo: Boolean;
        CodigoEmpresaOracle: Code[2];
        NumFilas: Integer;
        NumCambiado: Integer;
        NumYaEstaba: Integer;
        NumNoExiste: Integer;
        NumError: Integer;
        EmpresaDesconocidaErr: Label 'Empresa %1 desconocida.', Comment = '%1 = nombre de la empresa';
        FilasTotalesMsg: Label '%1. Filas tratadas: %2. Cambiado: %3. Ya estaba: %4. No existe en BC: %5. Error: %6.', Comment = '%1 = Simulación o Ejecución, %2 = filas tratadas, %3 = cambiados, %4 = ya estaban, %5 = no existen en BC, %6 = errores';
        TotalesMsg: Label '%1. Cambiado: %2. Error: %3.', Comment = '%1 = Simulación o Ejecución, %2 = cambiados, %3 = errores';
        NombreFicheroTxt: Label '%1 %2 %3', Comment = '%1 = proceso, %2 = empresa, %3 = Simulación o Ejecución';
        SubirExcelTxt: Label 'Excel de reparación';
        SimulacionTxt: Label 'Simulación';
        EjecucionTxt: Label 'Ejecución';
        CambiadoTxt: Label 'Cambiado';
        YaEstabaTxt: Label 'Ya estaba';
        NoExisteTxt: Label 'No existe en BC';
        EstadoColaNoValidoTxt: Label 'Error: estado de cola %1 no válido', Comment = '%1 = valor de la columna ESTADO_COLA';
        SinUnidadBaseTxt: Label 'Error: producto sin unidad base';
        ProductoNoExisteTxt: Label 'Error: producto no existe';
        TablaOTTxt: Label '50050 Enteco Production Order', Locked = true;
        TablaOrdenTxt: Label '5405 Production Order', Locked = true;
        ClaveEstructuraTxt: Label '%1 %2 / %3 / %4 / F%5 S%6', Locked = true;
        ClaveLineaOTTxt: Label '%1 %2 / %3 / F%4 S%5', Locked = true;
        ClaveComponenteTxt: Label '%1 %2 / %3 / %4 / %5', Locked = true;
}