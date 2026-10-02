// Ficha 00001. Carga desde el Excel de la consulta a Oracle (hoja «Reparar») el recurso finalizado y el
// estado de cola de las OT creadas en BC, en la OT de Planificación (50050) y en la orden estándar (5405).
report 59901 "GRX Fix Recurso Cola OT"
{
    Caption = 'GRX FIX - Recurso finalizado y estado de cola de OT';
    ProcessingOnly = true;
    UsageCategory = Tasks;
    ApplicationArea = All;

    requestpage
    {
        layout
        {
            area(Content)
            {
                group(Opciones)
                {
                    Caption = 'Opciones';

                    field(SimularField; Simular)
                    {
                        Caption = 'Simular';
                        ApplicationArea = All;
                        ToolTip = 'Hace todo menos grabar: el Excel de resultado muestra lo que se cambiaría.';
                    }
                }
            }
        }
    }

    trigger OnInitReport()
    begin
        Simular := true;
    end;

    trigger OnPreReport()
    begin
        if (UpperCase(UserId()) <> UpperCase('d.oton')) and
           (UpperCase(UserId()) <> UpperCase('a.millan')) then
            Error(SinPermisoErr);

        case CompanyName() of
            'Enteco_Pharma':
                CodigoEmpresaOracle := '10';
            'Enteco_Manviel':
                CodigoEmpresaOracle := '05';
            else
                Error(EmpresaDesconocidaErr, CompanyName());
        end;

        LeerExcel();
        ProcesarFilas();
        ExportarResultado();

        Message(TotalesMsg, ModoTxt(), NumFilas, NumCambiado, NumYaEstaba, NumNoExiste, NumError);
    end;

    var
        TempExcelBuffer: Record "Excel Buffer" temporary;
        TempResultado: Record "Excel Buffer" temporary;
        Simular: Boolean;
        CodigoEmpresaOracle: Code[2];
        NumFilas: Integer;
        NumCambiado: Integer;
        NumYaEstaba: Integer;
        NumNoExiste: Integer;
        NumError: Integer;
        SinPermisoErr: Label 'Uso exclusivo de Tecnología. No tiene permiso';
        EmpresaDesconocidaErr: Label 'Empresa %1 desconocida.', Comment = '%1 = nombre de la empresa';
        TotalesMsg: Label '%1. Filas tratadas: %2. Cambiado: %3. Ya estaba: %4. No existe en BC: %5. Error: %6.', Comment = '%1 = Simulación o Ejecución, %2 = filas tratadas, %3 = cambiados, %4 = ya estaban, %5 = no existen en BC, %6 = errores';
        NombreFicheroTxt: Label 'GRX Fix Recurso Cola OT %1 %2', Comment = '%1 = empresa, %2 = Simulación o Ejecución';
        CambiadoTxt: Label 'Cambiado';
        YaEstabaTxt: Label 'Ya estaba';
        NoExisteTxt: Label 'No existe en BC';
        EstadoColaNoValidoTxt: Label 'Error: estado de cola %1 no válido', Comment = '%1 = valor de la columna ESTADO_COLA';

    local procedure LeerExcel()
    var
        InStr: InStream;
        NombreFichero: Text;
    begin
        if not UploadIntoStream('Excel de reparación', '', 'Excel (*.xlsx)|*.xlsx', NombreFichero, InStr) then
            Error('');
        TempExcelBuffer.Reset();
        TempExcelBuffer.DeleteAll();
        TempExcelBuffer.OpenBookStream(InStr, 'Reparar');
        TempExcelBuffer.ReadSheet();
    end;

    local procedure ProcesarFilas()
    var
        UltimaFila: Integer;
        Fila: Integer;
    begin
        TempExcelBuffer.Reset();
        if TempExcelBuffer.FindLast() then
            UltimaFila := TempExcelBuffer."Row No.";

        AnadirCabeceraResultado();
        for Fila := 2 to UltimaFila do
            if EsDeEstaEmpresa(ValorCelda(Fila, 1)) then
                ProcesarFila(Fila);
    end;

    local procedure ProcesarFila(Fila: Integer)
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
            AnadirResultado('50050 Enteco Production Order', Numero, '', '', '', NoExisteTxt);
        if not ExisteOrden then
            AnadirResultado('5405 Production Order', Numero, '', '', '', NoExisteTxt);
        if not (ExisteOT or ExisteOrden) then
            exit;

        if Recurso <> '' then begin
            if ExisteOT then
                if OT."Recurso finalizado" = Recurso then
                    AnadirResultado('50050 Enteco Production Order', Numero, OT.FieldCaption("Recurso finalizado"), OT."Recurso finalizado", Recurso, YaEstabaTxt)
                else begin
                    AnadirResultado('50050 Enteco Production Order', Numero, OT.FieldCaption("Recurso finalizado"), OT."Recurso finalizado", Recurso, CambiadoTxt);
                    OT."Recurso finalizado" := Recurso;
                    HayCambios := true;
                end;
            if ExisteOrden then
                if ProdOrder."Enteco Recurso finalizado" = Recurso then
                    AnadirResultado('5405 Production Order', Numero, ProdOrder.FieldCaption("Enteco Recurso finalizado"), ProdOrder."Enteco Recurso finalizado", Recurso, YaEstabaTxt)
                else begin
                    AnadirResultado('5405 Production Order', Numero, ProdOrder.FieldCaption("Enteco Recurso finalizado"), ProdOrder."Enteco Recurso finalizado", Recurso, CambiadoTxt);
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
        if HayCambios and not Simular then begin
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
                AnadirResultado('50050 Enteco Production Order', Numero, OT.FieldCaption("Estado Cola"), Format(OT."Estado Cola"), Format(EstadoOT), YaEstabaTxt)
            else begin
                AnadirResultado('50050 Enteco Production Order', Numero, OT.FieldCaption("Estado Cola"), Format(OT."Estado Cola"), Format(EstadoOT), CambiadoTxt);
                OT."Estado Cola" := EstadoOT;
                HayCambios := true;
            end;
        if ExisteOrden then
            if ProdOrder."Enteco Estado Cola" = EstadoOrden then
                AnadirResultado('5405 Production Order', Numero, ProdOrder.FieldCaption("Enteco Estado Cola"), Format(ProdOrder."Enteco Estado Cola"), FormatEstadoOrden(EstadoOrden), YaEstabaTxt)
            else begin
                AnadirResultado('5405 Production Order', Numero, ProdOrder.FieldCaption("Enteco Estado Cola"), Format(ProdOrder."Enteco Estado Cola"), FormatEstadoOrden(EstadoOrden), CambiadoTxt);
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

    local procedure ValorCelda(Fila: Integer; Columna: Integer): Text
    begin
        if TempExcelBuffer.Get(Fila, Columna) then
            exit(TempExcelBuffer."Cell Value as Text".Trim());
        exit('');
    end;

    local procedure AnadirCabeceraResultado()
    begin
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

        case true of
            Resultado = CambiadoTxt:
                NumCambiado += 1;
            Resultado = YaEstabaTxt:
                NumYaEstaba += 1;
            Resultado = NoExisteTxt:
                NumNoExiste += 1;
            else
                NumError += 1;
        end;
    end;

    local procedure ExportarResultado()
    begin
        TempResultado.CreateNewBook('Resultado');
        TempResultado.WriteSheet('Resultado', CompanyName(), UserId());
        TempResultado.CloseBook();
        TempResultado.SetFriendlyFilename(StrSubstNo(NombreFicheroTxt, CompanyName(), ModoTxt()));
        TempResultado.OpenExcel();
    end;

    local procedure ModoTxt(): Text
    begin
        if Simular then
            exit('Simulación');
        exit('Ejecución');
    end;
}
