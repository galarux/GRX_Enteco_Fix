report 50025 "GRX Fix"
{
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'GRX Fix DOR';
    ProcessingOnly = true;

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

    // Llama al proceso en curso; para lanzar otro se cambia la llamada y se vuelve a publicar.
    trigger OnPreReport()
    begin
        if (UpperCase(UserId()) <> UpperCase('d.oton')) and
           (UpperCase(UserId()) <> UpperCase('a.millan')) then
            Error(SinPermisoErr);

        cuGrxFix.RepararUnidadComponentes(Simular);
    end;

    var
        cuGrxFix: Codeunit "GRX Main";
        Simular: Boolean;
        SinPermisoErr: Label 'Uso exclusivo de Tecnología. No tiene permiso';
}
