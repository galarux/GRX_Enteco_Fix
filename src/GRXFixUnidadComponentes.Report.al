// Ficha 00001. Completa con la unidad base del producto las líneas de material de las estructuras (50021),
// las líneas de OTT/OT (50051) y los componentes de las órdenes estándar (5407) que se quedaron sin unidad.
report 59902 "GRX Fix Unidad Componentes"
{
    Caption = 'GRX FIX - Unidad de medida de componentes';
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

        AnadirCabeceraResultado();
        RepararLineasEstructura();
        RepararLineasOT();
        RepararComponentes();
        ExportarResultado();

        Message(TotalesMsg, ModoTxt(), NumCambiado, NumError);
    end;

    var
        TempResultado: Record "Excel Buffer" temporary;
        Simular: Boolean;
        NumCambiado: Integer;
        NumError: Integer;
        SinPermisoErr: Label 'Uso exclusivo de Tecnología. No tiene permiso';
        TotalesMsg: Label '%1. Cambiado: %2. Error: %3.', Comment = '%1 = Simulación o Ejecución, %2 = cambiados, %3 = errores';
        NombreFicheroTxt: Label 'GRX Fix Unidad Componentes %1 %2', Comment = '%1 = empresa, %2 = Simulación o Ejecución';
        ClaveEstructuraTxt: Label '%1 %2 / %3 / %4 / F%5 S%6', Locked = true;
        ClaveLineaOTTxt: Label '%1 %2 / %3 / F%4 S%5', Locked = true;
        ClaveComponenteTxt: Label '%1 %2 / %3 / %4 / %5', Locked = true;
        CambiadoTxt: Label 'Cambiado';
        SinUnidadBaseTxt: Label 'Error: producto sin unidad base';
        ProductoNoExisteTxt: Label 'Error: producto no existe';

    local procedure RepararLineasEstructura()
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
                    if not Simular then begin
                        LineaModificar := Linea;
                        LineaModificar."Unidad Medida" := Unidad;
                        LineaModificar.Modify(false);
                    end;
            until Linea.Next() = 0;
    end;

    local procedure RepararLineasOT()
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
                    if not Simular then begin
                        // Sin triggers: el OnModify de la 50051 resincroniza la orden estándar con Commit.
                        LineaModificar := Linea;
                        LineaModificar."Cod. Unidad Medida" := Unidad;
                        LineaModificar.Modify(false);
                    end;
            until Linea.Next() = 0;
    end;

    local procedure RepararComponentes()
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
                    if not Simular then begin
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

    // Devuelve en Unidad la unidad base del producto y deja la fila en el Excel de resultado.
    local procedure UnidadBase(ItemNo: Code[20]; Tabla: Text; Clave: Text; Campo: Text; var Unidad: Code[10]): Boolean
    var
        Item: Record Item;
    begin
        Unidad := '';
        Item.SetLoadFields("Base Unit of Measure");
        if not Item.Get(ItemNo) then begin
            AnadirResultado(Tabla, Clave, Campo, '', ProductoNoExisteTxt);
            exit(false);
        end;
        if Item."Base Unit of Measure" = '' then begin
            AnadirResultado(Tabla, Clave, Campo, '', SinUnidadBaseTxt);
            exit(false);
        end;
        Unidad := Item."Base Unit of Measure";
        AnadirResultado(Tabla, Clave, Campo, Unidad, CambiadoTxt);
        exit(true);
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

    // El valor anterior siempre es la unidad en blanco: solo se revisan registros sin unidad.
    local procedure AnadirResultado(Tabla: Text; Clave: Text; Campo: Text; ValorNuevo: Text; Resultado: Text)
    begin
        TempResultado.NewRow();
        TempResultado.AddColumn(Tabla, false, '', false, false, false, '', TempResultado."Cell Type"::Text);
        TempResultado.AddColumn(Clave, false, '', false, false, false, '', TempResultado."Cell Type"::Text);
        TempResultado.AddColumn(Campo, false, '', false, false, false, '', TempResultado."Cell Type"::Text);
        TempResultado.AddColumn('', false, '', false, false, false, '', TempResultado."Cell Type"::Text);
        TempResultado.AddColumn(ValorNuevo, false, '', false, false, false, '', TempResultado."Cell Type"::Text);
        TempResultado.AddColumn(Resultado, false, '', false, false, false, '', TempResultado."Cell Type"::Text);

        if Resultado = CambiadoTxt then
            NumCambiado += 1
        else
            NumError += 1;
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
