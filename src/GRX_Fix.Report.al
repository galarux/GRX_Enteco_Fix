report 50025 "GRX Fix"
{
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'GRX Fix DOR';
    ProcessingOnly = true;

    trigger OnPreReport()
    var
    begin
        cuGrxFix.BorraCortePersonalizado();
    end;

    trigger OnPostReport()
    begin
        Message('Proceso finalizado correctamente');
    end;

    var
        cuGrxFix: Codeunit "GRX Main";
}
