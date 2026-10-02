report 50133 "GRX Fix Import Planif"
{
    Caption = 'GRX FIX - Importar Planificacion';
    ProcessingOnly = true;
    UsageCategory = Lists;
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

                    field(SoloCortesPersonalizados; SoloCortesPersonalizados)
                    {
                        Caption = 'Solo cortes personalizados';
                        ApplicationArea = All;
                        ToolTip = 'Rehace únicamente las cabeceras y líneas de cortes personalizados (ficheros 08, 09, 10 y 11). No toca ninguna otra tabla de la migración, y el borrado previo se limita a las filas que dejó la importación defectuosa.';
                    }
                    field(FechaHoraImportacion; FechaHoraImportacion)
                    {
                        Caption = 'Respetar lo creado desde';
                        ApplicationArea = All;
                        ToolTip = 'Si se informa, el borrado previo solo alcanza a los registros creados antes de esta fecha y hora. En blanco no aplica límite.';
                    }
                }
            }
        }
    }

    trigger OnPreReport()
    begin
        // El código de empresa de Oracle ('10' / '05') viaja en la primera columna de cada Excel y
        // sirve para descartar las filas de la otra empresa.
        case CompanyName() of
            'Enteco_Pharma':
                begin
                    Sufijo := '_pharma';
                    CodigoEmpresaOracle := '10';
                end;
            'Enteco_Manviel':
                begin
                    Sufijo := '_manviel';
                    CodigoEmpresaOracle := '05';
                end;
            else
                Error('Empresa %1 desconocida.', CompanyName);
        end;

        if (UPPERCASE(UserId()) <> UPPERCASE('d.oton')) and
           (UPPERCASE(UserId()) <> UPPERCASE('a.millan')) then
            Error('Uso exclusivo de Tecnología. No tiene permiso');

        // Reparación acotada: rehace solo las tablas 50052 y 50053 a partir de sus cuatro ficheros.
        // Ninguna otra tabla de la migración se toca.
        if SoloCortesPersonalizados then begin
            Importar_CabecerasCortesPersonalizados_PedidosInternos();
            Importar_LineasCortesPersonalizados_PedidosInternos();
            Message('Reimportación de cortes personalizados finalizada correctamente.');
            exit;
        end;

        //FechaHoraImportacion := CreateDateTime(20260522D, 000000T);

        // Debe ir ANTES de importar las estructuras: éstas copian la unidad de producción de la máquina
        // a las líneas de máquina (ver ImportExcelDataPedidosInternosEstructuras).
        RellenarUnidadProduccionMaquinas();

        Importar_PedidosInternos();
        Importar_Estructuras_PedidosInternos();
        ImportarPlanesCortePedidosInternos();
        Importar_CabecerasOTT_PedidosInternos();
        Importar_CabecerasOT_PedidosInternos();
        Importar_LineasOTT_PedidosInternos();
        Importar_LineasOT_PedidosInternos();
        Importar_CabecerasCortesPersonalizados_PedidosInternos();
        Importar_LineasCortesPersonalizados_PedidosInternos();
        Importar_AsignacionesLotesOTT_PedidosInternos();
        Importar_AsignacionesLotesOT_PedidosInternos();
        Importar_ObservacionesPartesTrabajo();

        CrearNosSeries();
        RellenarEmojis();
        RellenarConfigDesbarbes();

        // Importar_FichasTecnicas_Semielaborados();

        RegistrarServiciosWeb();
        //Fix();

        Message('Importación finalizada correctamente.');
    end;

    local procedure ImportarProcesarExcel(Tipo: Text)
    var
        TempExcelBuffer: Record "Excel Buffer" temporary;
        FileName: Text[100];
        SheetName: Text[100];
    begin
        GetFileSheetName(Tipo, FileName, SheetName);

        TempExcelBuffer.Reset();
        TempExcelBuffer.DeleteAll();
        TempExcelBuffer.OpenBook(FileName, SheetName);
        TempExcelBuffer.ReadSheet();

        ProcessExcelBufferPorTipo(Tipo, TempExcelBuffer);
    end;

    local procedure ProcessExcelBufferPorTipo(Tipo: Text; var TempExcelBuffer: Record "Excel Buffer" temporary)
    begin
        case Tipo of
            'Pedidos':
                ImportExcelDataPedidosInternos(TempExcelBuffer);
            'Estructuras':
                ImportExcelDataPedidosInternosEstructuras(TempExcelBuffer);
            'PlanesCorte':
                ImportExcelDataPedidosInternosPlanesCorte(TempExcelBuffer);
            'OTT':
                ImportExcelDataCabeceraOTT(TempExcelBuffer);
            'OT':
                ImportExcelDataCabeceraOT(TempExcelBuffer);
            'OTTCortesPerso':
                ImportExcelDataCabeceraCortesPerso(TempExcelBuffer, Enum::"Enteco Production Order Type"::"OTT");
            'OTCortesPerso':
                ImportExcelDataCabeceraCortesPerso(TempExcelBuffer, Enum::"Enteco Production Order Type"::"OT");
            'LotesTeoricosOTT':
                ImportExcelDataCabeceraLotes(TempExcelBuffer, Enum::"Enteco Production Order Type"::"OTT");
            'LotesTeoricosOT':
                ImportExcelDataCabeceraLotes(TempExcelBuffer, Enum::"Enteco Production Order Type"::"OT");
            'LIN_OTT':
                ImportExcelDataLineasOTT(TempExcelBuffer);
            'LIN_OT':
                ImportExcelDataLineasOT(TempExcelBuffer);
            'LIN_OTTCortesPerso':
                ImportExcelDataLineasCortesPerso(TempExcelBuffer, Enum::"Enteco Production Order Type"::"OTT");
            'LIN_OTCortesPerso':
                ImportExcelDataLineasCortesPerso(TempExcelBuffer, Enum::"Enteco Production Order Type"::"OT");
            'ObservacionesPartesTrabajo':
                ImportExcelObservacionesPartesTrabajo(TempExcelBuffer);
            'FichasTecnicasSemielaborados':
                ImportExcelFichasTecnicasSemielaborados(TempExcelBuffer);
        end;
    end;

    local procedure GetFileSheetName(Tipo: Text; var FileName: Text[100]; var SheetName: Text[100])
    begin
        case Tipo of
            'Pedidos':
                begin
                    FileName := 'C:\ficheros\01_cabeceras_pedidos_internos' + Sufijo + '.xlsx';
                    SheetName := 'Sheet1';
                end;
            'Estructuras':
                begin
                    FileName := 'C:\ficheros\02_estructuras_pedidos_internos' + Sufijo + '.xlsx';
                    SheetName := 'Sheet1';
                end;
            'PlanesCorte':
                begin
                    FileName := 'C:\ficheros\03_planes_corte_pedidos_internos' + Sufijo + '.xlsx';
                    SheetName := 'Sheet1';
                end;
            'OTT':
                begin
                    FileName := 'C:\ficheros\04_otts_pedidos_internos_cabeceras' + Sufijo + '.xlsx';
                    SheetName := 'Sheet1';
                end;
            'LIN_OTT':
                begin
                    FileName := 'C:\ficheros\05_otts_pedidos_internos_lineas' + Sufijo + '.xlsx';
                    SheetName := 'Sheet1';
                end;
            'OT':
                begin
                    FileName := 'C:\ficheros\06_ots_pedidos_internos_cabeceras' + Sufijo + '.xlsx';
                    SheetName := 'Sheet1';
                end;
            'LIN_OT':
                begin
                    FileName := 'C:\ficheros\07_ots_pedidos_internos_lineas' + Sufijo + '.xlsx';
                    SheetName := 'Sheet1';
                end;
            'OTTCortesPerso':
                begin
                    FileName := 'C:\ficheros\08_cortes_personalizados_ott_cabeceras' + Sufijo + '.xlsx';
                    SheetName := 'Sheet1';
                end;
            'LIN_OTTCortesPerso':
                begin
                    FileName := 'C:\ficheros\09_cortes_personalizados_ott_lineas' + Sufijo + '.xlsx';
                    SheetName := 'Sheet1';
                end;
            'OTCortesPerso':
                begin
                    FileName := 'C:\ficheros\10_cortes_personalizados_ot_cabeceras' + Sufijo + '.xlsx';
                    SheetName := 'Sheet1';
                end;
            'LIN_OTCortesPerso':
                begin
                    FileName := 'C:\ficheros\11_cortes_personalizados_ot_lineas' + Sufijo + '.xlsx';
                    SheetName := 'Sheet1';
                end;
            'LotesTeoricosOTT':
                begin
                    FileName := 'C:\ficheros\12_lotes_ordenes_trabajo_teoricas' + Sufijo + '.xlsx';
                    SheetName := 'Sheet1';
                end;
            'LotesTeoricosOT':
                begin
                    FileName := 'C:\ficheros\13_lotes_ordenes_trabajo_reales' + Sufijo + '.xlsx';
                    SheetName := 'Sheet1';
                end;
            'ObservacionesPartesTrabajo':
                begin
                    FileName := 'C:\ficheros\14_observaciones_partes_trabajo' + Sufijo + '.xlsx';
                    SheetName := 'Sheet1';
                end;
            else
                Error('Proceso cancelado tipo %1', Tipo);
        end;
    end;

    local procedure ImportExcelObservacionesPartesTrabajo(var TempExcelBuffer: Record "Excel Buffer" temporary)
    var
        RecObsPartes: Record "Enteco Obs. Parte Trabajo";
        RowNo: Integer;
        MaxRowNo: Integer;
    begin
        if FechaHoraImportacion <> 0DT then
            RecObsPartes.SetFilter(SystemCreatedAt, '<%1', FechaHoraImportacion);

        RecObsPartes.DeleteAll();

        TempExcelBuffer.Reset();
        if TempExcelBuffer.FindLast() then
            MaxRowNo := TempExcelBuffer."Row No.";

        for RowNo := 2 to MaxRowNo do begin
            RecObsPartes.Init();
            RecObsPartes."Prod. Order No." := GetValueAtCell(TempExcelBuffer, RowNo, 2);
            RecObsPartes."Tipo Observacion" := GetTipoObse(GetValueAtCell(TempExcelBuffer, RowNo, 4));
            RecObsPartes.Observacion := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 5), 1, 1024);
            RecObsPartes."Usu_Alta" := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 6), 1, MaxStrLen(RecObsPartes."Usu_Alta"));
            Evaluate(RecObsPartes."Fec_Alta", GetValueAtCell(TempExcelBuffer, RowNo, 7));
            RecObsPartes."Usu_Modi" := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 8), 1, MaxStrLen(RecObsPartes."Usu_Modi"));
            Evaluate(RecObsPartes."Fec_Modi", GetValueAtCell(TempExcelBuffer, RowNo, 9));
            RecObsPartes.Insert();
        end;
    end;

    local procedure ImportExcelFichasTecnicasSemielaborados(var TempExcelBuffer: Record "Excel Buffer" temporary)
    var
        RecItem: Record Item;
        RowNo: Integer;
        MaxRowNo: Integer;
        ProductoImportado: Code[20];
        AnchoImportado: Decimal;
        DiametroInteriorImportado: Decimal;
        DiametroExteriorImportado: Decimal;
        DiametroMlImportado: Decimal;
        LfsImportado: Code[20];
        GrupoProduccionImportado: Code[1];
    begin
        TempExcelBuffer.Reset();
        if TempExcelBuffer.FindLast() then
            MaxRowNo := TempExcelBuffer."Row No.";

        for RowNo := 2 to MaxRowNo do begin
            ProductoImportado := 'S' + GetValueAtCell(TempExcelBuffer, RowNo, 2);
            if not RecItem.Get(ProductoImportado) then
                Error('El producto %1 no existe en el sistema. Proceso cancelado.', ProductoImportado);

            LfsImportado := GetValueAtCell(TempExcelBuffer, RowNo, 5);
            if LfsImportado <> RecItem."Enteco LFS code" then
                Error('No coincide la LFS del producto %1. Proceso cancelado.', ProductoImportado);

            Evaluate(AnchoImportado, GetValueAtCell(TempExcelBuffer, RowNo, 6));
            if AnchoImportado <> RecItem."Enteco Ancho mm." then
                Error('No coincide el ancho del producto %1. Proceso cancelado.', ProductoImportado);

            Evaluate(DiametroInteriorImportado, GetValueAtCell(TempExcelBuffer, RowNo, 16));
            case DiametroInteriorImportado of
                0:
                    if RecItem."Enteco Diametro interior" <> RecItem."Enteco Diametro interior"::"0" then
                        Error('No coincide el diámetro interior del producto %1. Proceso cancelado.', ProductoImportado);
                70:
                    if RecItem."Enteco Diametro interior" <> RecItem."Enteco Diametro interior"::"70" then
                        Error('No coincide el diámetro interior del producto %1. Proceso cancelado.', ProductoImportado);
                76:
                    if RecItem."Enteco Diametro interior" <> RecItem."Enteco Diametro interior"::"76" then
                        Error('No coincide el diámetro interior del producto %1. Proceso cancelado.', ProductoImportado);
                150:
                    if RecItem."Enteco Diametro interior" <> RecItem."Enteco Diametro interior"::"150" then
                        Error('No coincide el diámetro interior del producto %1. Proceso cancelado.', ProductoImportado);
                152:
                    if RecItem."Enteco Diametro interior" <> RecItem."Enteco Diametro interior"::"152" then
                        Error('No coincide el diámetro interior del producto %1. Proceso cancelado.', ProductoImportado);
            end;

            Evaluate(DiametroExteriorImportado, GetValueAtCell(TempExcelBuffer, RowNo, 17));
            if DiametroExteriorImportado <> RecItem."Enteco Diametro exterior" then
                Error('No coincide el diámetro exterior del producto %1. Proceso cancelado.', ProductoImportado);

            Evaluate(DiametroMlImportado, GetValueAtCell(TempExcelBuffer, RowNo, 18));
            if DiametroMlImportado <> RecItem."Enteco Diametro exterior ml." then
                Error('No coincide el diámetro ML del producto %1. Proceso cancelado.', ProductoImportado);

            GrupoProduccionImportado := GetValueAtCell(TempExcelBuffer, RowNo, 41);

            RecItem.Modify();
        end;
    end;

    local procedure GetTipoObse(Valor: Text) TipoObse: Enum "Enteco Tipo Observacion OT"
    begin
        case Valor of
            'OT_ALMACEN':
                TipoObse := TipoObse::OT_ALMACEN;
            'OT_CORTE':
                TipoObse := TipoObse::OT_CORTE;
            'OT_IMPRESION':
                TipoObse := TipoObse::OT_IMPRESION;
            'OT_LAMINACION':
                TipoObse := TipoObse::OT_LAMINACION;
            'OT_LAQUEADO':
                TipoObse := TipoObse::OT_LAQUEADO;
            'OT_MONTAJE':
                TipoObse := TipoObse::OT_MONTAJE;
            'OT_TINTAS':
                TipoObse := TipoObse::OT_TINTAS;
        end;
        exit(TipoObse);
    end;

    local procedure ImportExcelDataCabeceraOTT(var TempExcelBuffer: Record "Excel Buffer" temporary)
    var
        RecProdOrder: Record "Enteco Production Order";
        RowNo: Integer;
        MaxRowNo: Integer;
        ValorTexto: Text;
        Estado: Text[10];
    begin
        if FechaHoraImportacion <> 0DT then
            RecProdOrder.SetFilter(SystemCreatedAt, '<%1', FechaHoraImportacion);

        RecProdOrder.SetRange(Tipo, RecProdOrder.Tipo::"OTT");
        RecProdOrder.DeleteAll();

        TempExcelBuffer.Reset();
        if TempExcelBuffer.FindLast() then
            MaxRowNo := TempExcelBuffer."Row No.";

        for RowNo := 2 to MaxRowNo do begin
            RecProdOrder.Init();
            RecProdOrder.Tipo := RecProdOrder.Tipo::"OTT";
            RecProdOrder."No." := GetValueAtCell(TempExcelBuffer, RowNo, 2);
            RecProdOrder.Descripcion := 'Pedido Interno OTT ' + RecProdOrder."No.";
            RecProdOrder."Source Type" := RecProdOrder."Source Type"::PedidoInterno;
            RecProdOrder."Source No." := GetValueAtCell(TempExcelBuffer, RowNo, 4);
            Evaluate(RecProdOrder."Nº Linea Pedido", GetValueAtCell(TempExcelBuffer, RowNo, 5));
            RecProdOrder."Item No." := 'P35PRODORTI';
            // OJO: se fuerza a blanco sin mirar el Excel, y el blanco es un valor que ningun
            // flujo del sistema produce (lo natural seria SinAsignarCola). Se corrigio con el
            // Report 50130.
            RecProdOrder."Estado Cola" := RecProdOrder."Estado Cola"::" ";
            Estado := GetValueAtCell(TempExcelBuffer, RowNo, 11);
            case Estado of
                'P':
                    RecProdOrder.Estado := RecProdOrder.Estado::Abierta;
                'A':
                    RecProdOrder.Estado := RecProdOrder.Estado::Cerrada;
                else
                    RecProdOrder.Estado := RecProdOrder.Estado::" ";
            end;
            RecProdOrder.Observaciones := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 24), 1, 1024);
            Evaluate(RecProdOrder.Cantidad, GetValueAtCell(TempExcelBuffer, RowNo, 9));
            RecProdOrder."Cod. Unidad Medida" := 'M2';
            RecProdOrder."No. OTT Comun" := GetValueAtCell(TempExcelBuffer, RowNo, 15);
            ValorTexto := GetValueAtCell(TempExcelBuffer, RowNo, 13);
            if (ValorTexto <> '') and (ValorTexto <> '0') then
                Evaluate(RecProdOrder."Fecha Servicio", ValorTexto)
            else
                RecProdOrder."Fecha Servicio" := 0D; // Valor por defecto si no es válido
            RecProdOrder."Estructura por defecto" := GetValueAtCell(TempExcelBuffer, RowNo, 25);

            RecProdOrder."Usu_Alta" := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 20), 1, MaxStrLen(RecProdOrder."Usu_Alta"));
            Evaluate(RecProdOrder."Fec_Alta", GetValueAtCell(TempExcelBuffer, RowNo, 21));
            RecProdOrder."Usu_Modi" := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 22), 1, MaxStrLen(RecProdOrder."Usu_Modi"));
            Evaluate(RecProdOrder."Fec_Modi", GetValueAtCell(TempExcelBuffer, RowNo, 23));

            RecProdOrder.Insert();
        end;
    end;

    local procedure ImportExcelDataLineasOTT(var TempExcelBuffer: Record "Excel Buffer" temporary)
    var
        RecProdOrderLine: Record "Enteco Production Order Line";
        RowNo: Integer;
        MaxRowNo: Integer;
        LineNo: Integer;
        ValorTexto: Text;
        TipAres: Code[1];
    begin
        if FechaHoraImportacion <> 0DT then
            RecProdOrderLine.SetFilter(SystemCreatedAt, '<%1', FechaHoraImportacion);

        RecProdOrderLine.SetRange(Tipo, RecProdOrderLine.Tipo::"OTT");
        RecProdOrderLine.DeleteAll();

        TempExcelBuffer.Reset();
        if TempExcelBuffer.FindLast() then
            MaxRowNo := TempExcelBuffer."Row No.";

        LineNo := 0;
        for RowNo := 2 to MaxRowNo do begin
            LineNo += 1;
            RecProdOrderLine.Init();
            RecProdOrderLine."Prod. Order No." := GetValueAtCell(TempExcelBuffer, RowNo, 2);

            TipAres := GetValueAtCell(TempExcelBuffer, RowNo, 4);
            // Concatenar letra si el tipo de línea es 'S', 'M' o 'P'
            case TipAres of
                'S', 'M', 'P':
                    begin
                        RecProdOrderLine."Tipo Linea" := RecProdOrderLine."Tipo Linea"::Producto;
                        RecProdOrderLine."No." := TipAres + GetValueAtCell(TempExcelBuffer, RowNo, 5);

                    end
                else begin
                    RecProdOrderLine."Tipo Linea" := RecProdOrderLine."Tipo Linea"::Maquina;
                    RecProdOrderLine."No." := GetValueAtCell(TempExcelBuffer, RowNo, 5);
                end;
            end;

            RecProdOrderLine.Tipo := RecProdOrderLine.Tipo::"OTT";
            // RecProdOrderLine."Fase" := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 6), 1, 3);
            // RecProdOrderLine."Secuencia" := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 7), 1, 3);
            if GetValueAtCell(TempExcelBuffer, RowNo, 6) <> '' then
                Evaluate(RecProdOrderLine."Fase", GetValueAtCell(TempExcelBuffer, RowNo, 6));
            if GetValueAtCell(TempExcelBuffer, RowNo, 7) <> '' then
                Evaluate(RecProdOrderLine."Secuencia", GetValueAtCell(TempExcelBuffer, RowNo, 7));

            if RecProdOrderLine."Tipo Linea" = RecProdOrderLine."Tipo Linea"::Maquina then begin
                ValorTexto := GetValueAtCell(TempExcelBuffer, RowNo, 15);
                if IsNumeric(ValorTexto) then
                    Evaluate(RecProdOrderLine.Cantidad, ValorTexto)
                else
                    RecProdOrderLine.Cantidad := 0;
                RecProdOrderLine."Cod. Unidad Medida" := GetValueAtCell(TempExcelBuffer, RowNo, 25);
            end else begin
                ValorTexto := GetValueAtCell(TempExcelBuffer, RowNo, 12);
                if IsNumeric(ValorTexto) then
                    Evaluate(RecProdOrderLine.Cantidad, ValorTexto)
                else
                    RecProdOrderLine.Cantidad := 0;
                RecProdOrderLine."Cod. Unidad Medida" := GetValueAtCell(TempExcelBuffer, RowNo, 22);
            end;
            // ValorTexto := GetValueAtCell(TempExcelBuffer, RowNo, 11);
            // if IsNumeric(ValorTexto) then
            //     Evaluate(RecProdOrderLine."Cantidad Mermas", ValorTexto)
            // else
            //     RecProdOrderLine."Cantidad Mermas" := 0;
            // RecProdOrderLine."Cod. Unidad Medida Mermas" := GetValueAtCell(TempExcelBuffer, RowNo, 23);

            //RecProdOrderLine."Fase Siguiente 1" := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 29), 1, 3);
            if GetValueAtCell(TempExcelBuffer, RowNo, 29) <> '' then
                Evaluate(RecProdOrderLine."Fase Siguiente 1", GetValueAtCell(TempExcelBuffer, RowNo, 29));

            RecProdOrderLine."Usu_Alta" := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 17), 1, MaxStrLen(RecProdOrderLine."Usu_Alta"));
            Evaluate(RecProdOrderLine."Fec_Alta", GetValueAtCell(TempExcelBuffer, RowNo, 18));
            RecProdOrderLine."Usu_Modi" := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 19), 1, MaxStrLen(RecProdOrderLine."Usu_Modi"));
            Evaluate(RecProdOrderLine."Fec_Modi", GetValueAtCell(TempExcelBuffer, RowNo, 20));

            RecProdOrderLine.Insert();
        end;
    end;

    local procedure ImportExcelDataCabeceraOT(var TempExcelBuffer: Record "Excel Buffer" temporary)
    var
        RecProdOrder: Record "Enteco Production Order";
        RowNo: Integer;
        MaxRowNo: Integer;
    begin
        if FechaHoraImportacion <> 0DT then
            RecProdOrder.SetFilter(SystemCreatedAt, '<%1', FechaHoraImportacion);

        RecProdOrder.SetRange(Tipo, RecProdOrder.Tipo::"OT");
        RecProdOrder.DeleteAll();

        TempExcelBuffer.Reset();
        if TempExcelBuffer.FindLast() then
            MaxRowNo := TempExcelBuffer."Row No.";

        for RowNo := 2 to MaxRowNo do begin
            RecProdOrder.Init();
            RecProdOrder.Tipo := RecProdOrder.Tipo::"OT";
            RecProdOrder."No." := GetValueAtCell(TempExcelBuffer, RowNo, 2);
            RecProdOrder.Descripcion := 'Pedido Interno OT' + RecProdOrder."No.";
            RecProdOrder."Source Type" := RecProdOrder."Source Type"::PedidoInterno;
            RecProdOrder."Source No." := GetValueAtCell(TempExcelBuffer, RowNo, 4);
            Evaluate(RecProdOrder."Nº Linea Pedido", GetValueAtCell(TempExcelBuffer, RowNo, 5));
            RecProdOrder."Item No." := 'P35PRODORTI';
            // OJO: se fuerza a blanco sin mirar el Excel, y el blanco es un valor que ningun
            // flujo del sistema produce (lo natural seria SinAsignarCola). Se corrigio con el
            // Report 50130.
            RecProdOrder."Estado Cola" := RecProdOrder."Estado Cola"::" ";
            Evaluate(RecProdOrder."Fecha EditaPedi", GetValueAtCell(TempExcelBuffer, RowNo, 8));

            RecProdOrder."No. OTT Comun" := GetValueAtCell(TempExcelBuffer, RowNo, 6);
            Evaluate(RecProdOrder.Cantidad, GetValueAtCell(TempExcelBuffer, RowNo, 11));
            RecProdOrder."Cod. Unidad Medida" := 'M2';
            case GetValueAtCell(TempExcelBuffer, RowNo, 13) of
                'A':
                    RecProdOrder.Estado := RecProdOrder.Estado::Abierta;
                'C':
                    RecProdOrder.Estado := RecProdOrder.Estado::Cerrada;
            end;

            Evaluate(RecProdOrder."Fecha Servicio", GetValueAtCell(TempExcelBuffer, RowNo, 15));
            RecProdOrder.Observaciones := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 25), 1, 1024);
            Evaluate(RecProdOrder."Cantidad Cerrada", GetValueAtCell(TempExcelBuffer, RowNo, 26));
            RecProdOrder."Recurso finalizado" := GetValueAtCell(TempExcelBuffer, RowNo, 29);
            Evaluate(RecProdOrder."Fecha Cierre", GetValueAtCell(TempExcelBuffer, RowNo, 32));

            RecProdOrder."Usu_Alta" := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 21), 1, MaxStrLen(RecProdOrder."Usu_Alta"));
            Evaluate(RecProdOrder."Fec_Alta", GetValueAtCell(TempExcelBuffer, RowNo, 22));
            RecProdOrder."Usu_Modi" := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 23), 1, MaxStrLen(RecProdOrder."Usu_Modi"));
            Evaluate(RecProdOrder."Fec_Modi", GetValueAtCell(TempExcelBuffer, RowNo, 24));

            RecProdOrder.Insert();
        end;
    end;

    // OJO: no se lee la columna 37 (ORDECOLAPLAN) del fichero 07, que trae el orden de cola de
    // ORACLE y cuyo destino es "Orden Cola Planificado" (campo 34). Se recupero con el Report 50130.
    local procedure ImportExcelDataLineasOT(var TempExcelBuffer: Record "Excel Buffer" temporary)
    var
        RecProdOrderLine: Record "Enteco Production Order Line";
        RowNo: Integer;
        MaxRowNo: Integer;
        LineNo: Integer;
        ValorTexto: Text;
        TipAres: Code[1];
    begin
        if FechaHoraImportacion <> 0DT then
            RecProdOrderLine.SetFilter(SystemCreatedAt, '<%1', FechaHoraImportacion);

        RecProdOrderLine.SetRange(Tipo, RecProdOrderLine.Tipo::"OT");
        RecProdOrderLine.DeleteAll();

        TempExcelBuffer.Reset();
        if TempExcelBuffer.FindLast() then
            MaxRowNo := TempExcelBuffer."Row No.";

        LineNo := 0;
        for RowNo := 2 to MaxRowNo do begin
            LineNo += 1;
            RecProdOrderLine.Init();
            RecProdOrderLine."Prod. Order No." := GetValueAtCell(TempExcelBuffer, RowNo, 2);

            TipAres := GetValueAtCell(TempExcelBuffer, RowNo, 4);
            // Concatenar letra si el tipo de línea es 'S', 'M' o 'P'
            case TipAres of
                'S', 'M', 'P':
                    begin
                        RecProdOrderLine."Tipo Linea" := RecProdOrderLine."Tipo Linea"::Producto;
                        RecProdOrderLine."No." := TipAres + GetValueAtCell(TempExcelBuffer, RowNo, 5);

                    end
                else begin
                    RecProdOrderLine."Tipo Linea" := RecProdOrderLine."Tipo Linea"::Maquina;
                    RecProdOrderLine."No." := GetValueAtCell(TempExcelBuffer, RowNo, 5);
                end;
            end;

            RecProdOrderLine.Tipo := RecProdOrderLine.Tipo::"OT";
            // RecProdOrderLine."Fase" := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 6), 1, 3);
            // RecProdOrderLine."Secuencia" := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 7), 1, 3);
            if GetValueAtCell(TempExcelBuffer, RowNo, 6) <> '' then
                Evaluate(RecProdOrderLine."Fase", GetValueAtCell(TempExcelBuffer, RowNo, 6));
            if GetValueAtCell(TempExcelBuffer, RowNo, 7) <> '' then
                Evaluate(RecProdOrderLine."Secuencia", GetValueAtCell(TempExcelBuffer, RowNo, 7));

            if RecProdOrderLine."Tipo Linea" = RecProdOrderLine."Tipo Linea"::Maquina then begin
                ValorTexto := GetValueAtCell(TempExcelBuffer, RowNo, 15);
                if IsNumeric(ValorTexto) then
                    Evaluate(RecProdOrderLine.Cantidad, ValorTexto)
                else
                    RecProdOrderLine.Cantidad := 0;
                RecProdOrderLine."Cod. Unidad Medida" := GetValueAtCell(TempExcelBuffer, RowNo, 26);
            end else begin
                ValorTexto := GetValueAtCell(TempExcelBuffer, RowNo, 12);
                if IsNumeric(ValorTexto) then
                    Evaluate(RecProdOrderLine.Cantidad, ValorTexto)
                else
                    RecProdOrderLine.Cantidad := 0;
                RecProdOrderLine."Cod. Unidad Medida" := GetValueAtCell(TempExcelBuffer, RowNo, 23);
            end;


            // ValorTexto := GetValueAtCell(TempExcelBuffer, RowNo, 11);
            // if IsNumeric(ValorTexto) then
            //     Evaluate(RecProdOrderLine."Cantidad Mermas", ValorTexto)
            // else
            //     RecProdOrderLine."Cantidad Mermas" := 0;
            // RecProdOrderLine."Cod. Unidad Medida Mermas" := GetValueAtCell(TempExcelBuffer, RowNo, 24);

            //RecProdOrderLine."Fase Siguiente 1" := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 29), 1, 3);
            if GetValueAtCell(TempExcelBuffer, RowNo, 29) <> '' then
                Evaluate(RecProdOrderLine."Fase Siguiente 1", GetValueAtCell(TempExcelBuffer, RowNo, 29));

            // ValorTexto := GetValueAtCell(TempExcelBuffer, RowNo, 10);
            // if ValorTexto <> '' then
            //     Evaluate(RecProdOrderLine."Cantidad por Unidad", ValorTexto)
            // else
            //     RecProdOrderLine."Cantidad por Unidad" := 0;

            RecProdOrderLine."Usu_Alta" := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 18), 1, MaxStrLen(RecProdOrderLine."Usu_Alta"));
            Evaluate(RecProdOrderLine."Fec_Alta", GetValueAtCell(TempExcelBuffer, RowNo, 19));
            RecProdOrderLine."Usu_Modi" := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 20), 1, MaxStrLen(RecProdOrderLine."Usu_Modi"));
            Evaluate(RecProdOrderLine."Fec_Modi", GetValueAtCell(TempExcelBuffer, RowNo, 21));

            RecProdOrderLine.Insert();
        end;
    end;

    local procedure ImportExcelDataCabeceraCortesPerso(var TempExcelBuffer: Record "Excel Buffer" temporary; Tipo: Enum "Enteco Production Order Type")
    var
        RecCabCortesPerso: Record "Enteco Cab Cortes Perso";
        RowNo: Integer;
        MaxRowNo: Integer;
        ValorTexto: Text;
    begin
        if not (Tipo in [Tipo::"OTT", Tipo::"OT"]) then
            Error('Proceso cancelado 1');

        if FechaHoraImportacion <> 0DT then
            RecCabCortesPerso.SetFilter(SystemCreatedAt, '<%1', FechaHoraImportacion);

        RecCabCortesPerso.SetRange(Tipo, Tipo);
        // En la reparación no se puede vaciar la tabla: hay que respetar los cortes introducidos en BC
        // después de la migración. Una cabecera sin máquina solo la puede haber dejado la importación
        // defectuosa, porque InitCabeceraCortesPersonalizados siempre informa Tipo Linea y No. Maquina
        // y VerCortesPersonalizados aborta si la línea no es de máquina cortadora.
        if SoloCortesPersonalizados then
            RecCabCortesPerso.SetRange("No. Maquina", '');
        RecCabCortesPerso.DeleteAll();

        TempExcelBuffer.Reset();
        if TempExcelBuffer.FindLast() then
            MaxRowNo := TempExcelBuffer."Row No.";

        for RowNo := 2 to MaxRowNo do
            // El fichero de cabeceras de OT trae filas de la otra empresa, porque su consulta de
            // extracción cruza solo por número de OT y los números se repiten entre empresas.
            if GetValueAtCell(TempExcelBuffer, RowNo, 1) = CodigoEmpresaOracle then begin
                RecCabCortesPerso.Init();
                RecCabCortesPerso.Tipo := Tipo;
                RecCabCortesPerso."Prod. Order No." := GetValueAtCell(TempExcelBuffer, RowNo, 2);
                // La cabecera cuelga de la línea de máquina de la OT. Sin estos dos campos su clave no
                // casa con la de sus propias líneas ni con la que busca VerCortesPersonalizados, y la
                // cabecera importada queda huérfana.
                RecCabCortesPerso."Tipo Linea" := RecCabCortesPerso."Tipo Linea"::Maquina;
                RecCabCortesPerso."No. Maquina" := GetValueAtCell(TempExcelBuffer, RowNo, 5);
                if GetValueAtCell(TempExcelBuffer, RowNo, 6) <> '' then
                    Evaluate(RecCabCortesPerso.Fase, GetValueAtCell(TempExcelBuffer, RowNo, 6));
                if GetValueAtCell(TempExcelBuffer, RowNo, 7) <> '' then
                    Evaluate(RecCabCortesPerso.Secuencia, GetValueAtCell(TempExcelBuffer, RowNo, 7));
                Evaluate(RecCabCortesPerso.Ancho, GetValueAtCell(TempExcelBuffer, RowNo, 8));
                Evaluate(RecCabCortesPerso.Cantidad, GetValueAtCell(TempExcelBuffer, RowNo, 10));
                ValorTexto := GetValueAtCell(TempExcelBuffer, RowNo, 9);
                if IsNumeric(ValorTexto) then
                    Evaluate(RecCabCortesPerso."No. Cortes", ValorTexto)
                else
                    RecCabCortesPerso."No. Cortes" := 0;
                RecCabCortesPerso."Unidad Medida" := GetValueAtCell(TempExcelBuffer, RowNo, 11);
                Evaluate(RecCabCortesPerso."Enteco Diametro exterior ml.", GetValueAtCell(TempExcelBuffer, RowNo, 14));
                Evaluate(RecCabCortesPerso."Enteco Diametro exterior", GetValueAtCell(TempExcelBuffer, RowNo, 13));
                Evaluate(RecCabCortesPerso."Enteco Diametro interior", GetValueAtCell(TempExcelBuffer, RowNo, 12));

                // Solo inserta si no existe
                if not RecCabCortesPerso.Get(
                        RecCabCortesPerso.Tipo,
                        RecCabCortesPerso."Prod. Order No.",
                        RecCabCortesPerso."Tipo Linea",
                        RecCabCortesPerso."No. Maquina",
                        RecCabCortesPerso.Fase,
                        RecCabCortesPerso.Secuencia) then begin
                    // Se asignan ANTES del Insert(true) para que el subscriber de auto-relleno de
                    // Codeunit 50019 (Enteco_SellarAlta, gateado por "ya viene informado") no los pise.
                    RecCabCortesPerso."Usu_Alta" := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 15), 1, MaxStrLen(RecCabCortesPerso."Usu_Alta"));
                    Evaluate(RecCabCortesPerso."Fec_Alta", GetValueAtCell(TempExcelBuffer, RowNo, 16));
                    RecCabCortesPerso."Usu_Modi" := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 17), 1, MaxStrLen(RecCabCortesPerso."Usu_Modi"));
                    Evaluate(RecCabCortesPerso."Fec_Modi", GetValueAtCell(TempExcelBuffer, RowNo, 18));
                    RecCabCortesPerso.Insert(true);
                end;
            end;
    end;

    local procedure ImportExcelDataLineasCortesPerso(var TempExcelBuffer: Record "Excel Buffer" temporary; Tipo: Enum "Enteco Production Order Type")
    var
        RecLinCortesPerso: Record "Enteco Lin Cortes Perso";
        RowNo: Integer;
        MaxRowNo: Integer;
        ValorTexto: Text;
        NumCorteNoNumericoErr: Label 'El nº de corte "%1" de la fila %2 del fichero de líneas de cortes personalizados no es numérico.';
        UsoCorteDesconocidoErr: Label 'Uso de corte desconocido "%1" en la fila %2 del fichero de líneas de cortes personalizados.';
    begin
        if not (Tipo in [Tipo::"OTT", Tipo::"OT"]) then
            Error('Proceso cancelado 1');

        if FechaHoraImportacion <> 0DT then
            RecLinCortesPerso.SetFilter(SystemCreatedAt, '<%1', FechaHoraImportacion);

        RecLinCortesPerso.SetRange(Tipo, Tipo);
        // Mismo criterio que en la cabecera. Las líneas solo nacen de GenerarCortes, que reparte un
        // ancho mayor que cero (ValidarParaGenerar lo garantiza) y la página no permite insertarlas a
        // mano, así que un ancho a cero identifica exactamente las filas mal importadas.
        if SoloCortesPersonalizados then
            RecLinCortesPerso.SetRange(Ancho, 0);
        RecLinCortesPerso.DeleteAll();

        TempExcelBuffer.Reset();
        if TempExcelBuffer.FindLast() then
            MaxRowNo := TempExcelBuffer."Row No.";

        for RowNo := 2 to MaxRowNo do
            if GetValueAtCell(TempExcelBuffer, RowNo, 1) = CodigoEmpresaOracle then begin
                RecLinCortesPerso.Init();
                RecLinCortesPerso.Tipo := Tipo;
                RecLinCortesPerso."Prod. Order No." := GetValueAtCell(TempExcelBuffer, RowNo, 2);
                RecLinCortesPerso."Tipo Linea" := RecLinCortesPerso."Tipo Linea"::Maquina;
                RecLinCortesPerso."No. Maquina" := GetValueAtCell(TempExcelBuffer, RowNo, 5);

                if GetValueAtCell(TempExcelBuffer, RowNo, 6) <> '' then
                    Evaluate(RecLinCortesPerso.Fase, CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 6), 1, 3));
                if GetValueAtCell(TempExcelBuffer, RowNo, 7) <> '' then
                    Evaluate(RecLinCortesPerso.Secuencia, CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 7), 1, 3));

                // El nº de corte forma parte de la clave primaria: si no viene numérico no se puede
                // inventar un sustituto sin arriesgar colisiones.
                ValorTexto := GetValueAtCell(TempExcelBuffer, RowNo, 8);
                if not IsNumeric(ValorTexto) then
                    Error(NumCorteNoNumericoErr, ValorTexto, RowNo);
                Evaluate(RecLinCortesPerso."Num. Cortes", ValorTexto);

                if GetValueAtCell(TempExcelBuffer, RowNo, 9) <> '' then
                    Evaluate(RecLinCortesPerso.Ancho, GetValueAtCell(TempExcelBuffer, RowNo, 9));

                RecLinCortesPerso."Otra Prod. Order No." := GetValueAtCell(TempExcelBuffer, RowNo, 16);
                RecLinCortesPerso."Otra No. Maquina" := GetValueAtCell(TempExcelBuffer, RowNo, 18);
                if GetValueAtCell(TempExcelBuffer, RowNo, 19) <> '' then
                    Evaluate(RecLinCortesPerso."Otra Fase", GetValueAtCell(TempExcelBuffer, RowNo, 19));
                if GetValueAtCell(TempExcelBuffer, RowNo, 20) <> '' then
                    Evaluate(RecLinCortesPerso."Otra Secuencia", GetValueAtCell(TempExcelBuffer, RowNo, 20));

                // La columna DESBARBE de Oracle no es un indicador: guarda la letra del uso del corte.
                // El mapeo está documentado en el enum "Enteco Tipo Uso Corte Perso".
                ValorTexto := GetValueAtCell(TempExcelBuffer, RowNo, 10);
                case ValorTexto of
                    'N':
                        RecLinCortesPerso."Tipo Uso Corte" := RecLinCortesPerso."Tipo Uso Corte"::Utilizar;
                    'C':
                        RecLinCortesPerso."Tipo Uso Corte" := RecLinCortesPerso."Tipo Uso Corte"::Expedir;
                    'S':
                        RecLinCortesPerso."Tipo Uso Corte" := RecLinCortesPerso."Tipo Uso Corte"::Desbarbe;
                    'A':
                        RecLinCortesPerso."Tipo Uso Corte" := RecLinCortesPerso."Tipo Uso Corte"::Almacenar;
                    'O':
                        RecLinCortesPerso."Tipo Uso Corte" := RecLinCortesPerso."Tipo Uso Corte"::UtilizarOtraOT;
                    'E':
                        RecLinCortesPerso."Tipo Uso Corte" := RecLinCortesPerso."Tipo Uso Corte"::ExpedirOtraOT;
                    else
                        Error(UsoCorteDesconocidoErr, ValorTexto, RowNo);
                end;
                RecLinCortesPerso."Es Desbarbe" := (ValorTexto = 'S');

                // Solo inserta si no existe
                if not RecLinCortesPerso.Get(
                        RecLinCortesPerso.Tipo,
                        RecLinCortesPerso."Prod. Order No.",
                        RecLinCortesPerso."Tipo Linea",
                        RecLinCortesPerso."No. Maquina",
                        RecLinCortesPerso.Fase,
                        RecLinCortesPerso.Secuencia,
                        RecLinCortesPerso."Num. Cortes") then begin
                    // Se asignan ANTES del Insert(true) para que el subscriber de auto-relleno de
                    // Codeunit 50019 (Enteco_SellarAlta, gateado por "ya viene informado") no los pise.
                    RecLinCortesPerso."Usu_Alta" := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 11), 1, MaxStrLen(RecLinCortesPerso."Usu_Alta"));
                    Evaluate(RecLinCortesPerso."Fec_Alta", GetValueAtCell(TempExcelBuffer, RowNo, 12));
                    RecLinCortesPerso."Usu_Modi" := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 13), 1, MaxStrLen(RecLinCortesPerso."Usu_Modi"));
                    Evaluate(RecLinCortesPerso."Fec_Modi", GetValueAtCell(TempExcelBuffer, RowNo, 14));
                    RecLinCortesPerso.Insert(true);
                end;
            end;
    end;

    local procedure GetValueAtCell(var TempExcelBuffer: Record "Excel Buffer" temporary; RowNo: Integer; ColNo: Integer): Text
    begin
        TempExcelBuffer.Reset();
        if TempExcelBuffer.Get(RowNo, ColNo) then
            exit(TempExcelBuffer."Cell Value as Text")
        else
            exit('');
    end;

    // Función auxiliar para validar si un texto es numérico
    local procedure IsNumeric(Value: Text): Boolean
    var
        DummyDecimal: Decimal;
    begin
        exit(Evaluate(DummyDecimal, Value));
    end;

    local procedure ImportExcelDataPedidosInternos(var TempExcelBuffer: Record "Excel Buffer" temporary)
    var
        PedidoInterno: Record "Enteco Pedido Interno";
        ImportedDiametroInterior: Text[10];
        RowNo: Integer;
        MaxRowNo: Integer;
    begin
        if FechaHoraImportacion <> 0DT then
            PedidoInterno.SetFilter(SystemCreatedAt, '<%1', FechaHoraImportacion);

        PedidoInterno.DeleteAll();
        Commit();

        RowNo := 0;
        MaxRowNo := 0;

        TempExcelBuffer.Reset();
        if TempExcelBuffer.FindLast() then
            MaxRowNo := TempExcelBuffer."Row No.";

        // OJO: los ficheros 01/02/03/12/13 tienen UNA SOLA fila de cabecera, asi que este 3
        // se salta la primera fila de datos. No se corrige a 2 porque el report no se va a
        // relanzar; las filas perdidas se recuperaron con el Report 50130.
        for RowNo := 3 to MaxRowNo do begin
            Clear(PedidoInterno);
            PedidoInterno."No." := GetValueAtCell(TempExcelBuffer, RowNo, 2);
            PedidoInterno.Insert();

            PedidoInterno."No. Cliente" := GetValueAtCell(TempExcelBuffer, RowNo, 3);

            case GetValueAtCell(TempExcelBuffer, RowNo, 4) of
                'RCL_CLIENTE':
                    PedidoInterno."Tipo Pedido Interno" := Enum::"Enteco Tipo Pedido Interno"::RCL_Cliente;
                'RCL_PROVEEDOR', 'REPROCESO':
                    PedidoInterno."Tipo Pedido Interno" := Enum::"Enteco Tipo Pedido Interno"::Reproceso;
                'BOBINA_MUESTRA':
                    PedidoInterno."Tipo Pedido Interno" := Enum::"Enteco Tipo Pedido Interno"::BobinaMuestra;
                'PRECORTE':
                    PedidoInterno."Tipo Pedido Interno" := Enum::"Enteco Tipo Pedido Interno"::Precorte;
                'OTROS':
                    PedidoInterno."Tipo Pedido Interno" := Enum::"Enteco Tipo Pedido Interno"::Otros;
            end;

            Evaluate(PedidoInterno."Fecha Pedido", GetValueAtCell(TempExcelBuffer, RowNo, 5));
            Evaluate(PedidoInterno."Fecha Servicio", GetValueAtCell(TempExcelBuffer, RowNo, 6));

            PedidoInterno."Obs. Expedicion" := GetValueAtCell(TempExcelBuffer, RowNo, 7);
            Evaluate(PedidoInterno.Cantidad, GetValueAtCell(TempExcelBuffer, RowNo, 8));
            PedidoInterno."Cod. Unidad Medida" := GetValueAtCell(TempExcelBuffer, RowNo, 9);
            PedidoInterno."Obs. Pedido" := GetValueAtCell(TempExcelBuffer, RowNo, 10);

            PedidoInterno."No. Producto" := GetValueAtCell(TempExcelBuffer, RowNo, 15) + GetValueAtCell(TempExcelBuffer, RowNo, 16);
            PedidoInterno."Referencia Externa" := GetValueAtCell(TempExcelBuffer, RowNo, 17);
            PedidoInterno."No. Pedido" := GetValueAtCell(TempExcelBuffer, RowNo, 19);
            //PedidoInterno."No. Cliente" := GetValueAtCell(TempExcelBuffer, RowNo, 20);
            PedidoInterno."LFS Code" := GetValueAtCell(TempExcelBuffer, RowNo, 21);
            if Evaluate(PedidoInterno."Ancho mm.", GetValueAtCell(TempExcelBuffer, RowNo, 22)) then;

            ImportedDiametroInterior := GetValueAtCell(TempExcelBuffer, RowNo, 23);

            case ImportedDiametroInterior of
                '70':
                    PedidoInterno."Diametro interior" := PedidoInterno."Diametro interior"::"70";
                '76':
                    PedidoInterno."Diametro interior" := PedidoInterno."Diametro interior"::"76";
                '95':
                    PedidoInterno."Diametro interior" := PedidoInterno."Diametro interior"::"95";
                '150':
                    PedidoInterno."Diametro interior" := PedidoInterno."Diametro interior"::"150";
                '152':
                    PedidoInterno."Diametro interior" := PedidoInterno."Diametro interior"::"152";
                else
                    PedidoInterno."Diametro interior" := PedidoInterno."Diametro interior"::"0";
            end;

            if Evaluate(PedidoInterno."Diametro exterior", GetValueAtCell(TempExcelBuffer, RowNo, 24)) then;
            if Evaluate(PedidoInterno."Diametro exterior ml.", GetValueAtCell(TempExcelBuffer, RowNo, 25)) then;

            //PedidoInterno.ObseRevi
            //PedidoInterno.ObseModi
            //PedidoInterno.ObseMate
            //PedidoInterno.Notas
            if Evaluate(PedidoInterno."Paso Real", GetValueAtCell(TempExcelBuffer, RowNo, 30)) then;

            PedidoInterno."Usu_Alta" := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 11), 1, MaxStrLen(PedidoInterno."Usu_Alta"));
            Evaluate(PedidoInterno."Fec_Alta", GetValueAtCell(TempExcelBuffer, RowNo, 12));
            PedidoInterno."Usu_Modi" := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 13), 1, MaxStrLen(PedidoInterno."Usu_Modi"));
            Evaluate(PedidoInterno."Fec_Modi", GetValueAtCell(TempExcelBuffer, RowNo, 14));

            PedidoInterno.Modify();
        end;
    end;

    local procedure ImportExcelDataPedidosInternosEstructuras(var TempExcelBuffer: Record "Excel Buffer" temporary)
    var
        EstructuraCabecera: Record "Enteco Cabecera Estructura";
        EstructuraLinea: Record "Enteco Linea Estructura";
        PedidoInterno: Record "Enteco Pedido Interno";
        RecItem: Record Item;
        WorkCenter: Record "Work Center";
        RowNo: Integer;
        MaxRowNo: Integer;
        EstructuraPorDefecto: Boolean;
        Importar: Boolean;
        TipAres: Code[1];
        FaseSiguiente: Text[10];
    begin
        if FechaHoraImportacion <> 0DT then begin
            EstructuraCabecera.SetFilter(SystemCreatedAt, '<%1', FechaHoraImportacion);
            EstructuraLinea.SetFilter(SystemCreatedAt, '<%1', FechaHoraImportacion);
        end;

        EstructuraCabecera.SetRange(Tipo, EstructuraCabecera.Tipo::PedidoInterno);
        EstructuraCabecera.DeleteAll();

        EstructuraLinea.SetRange(Tipo, EstructuraCabecera.Tipo::PedidoInterno);
        EstructuraLinea.DeleteAll();
        Commit();

        RowNo := 0;
        MaxRowNo := 0;

        TempExcelBuffer.Reset();
        if TempExcelBuffer.FindLast() then
            MaxRowNo := TempExcelBuffer."Row No.";

        // OJO: los ficheros 01/02/03/12/13 tienen UNA SOLA fila de cabecera, asi que este 3
        // se salta la primera fila de datos. No se corrige a 2 porque el report no se va a
        // relanzar; las filas perdidas se recuperaron con el Report 50130.
        for RowNo := 3 to MaxRowNo do begin
            Clear(EstructuraCabecera);
            EstructuraCabecera.Tipo := EstructuraCabecera.Tipo::PedidoInterno;
            EstructuraCabecera."Source No." := GetValueAtCell(TempExcelBuffer, RowNo, 2);
            Evaluate(EstructuraCabecera."No. Estructura", GetValueAtCell(TempExcelBuffer, RowNo, 4));
            //EstructuraCabecera."Descripcion" := GetValueAtCell(TempExcelBuffer, RowNo, 4);

            if EstructuraCabecera.Insert() then begin
                EstructuraCabecera."Usu_Alta" := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 7), 1, MaxStrLen(EstructuraCabecera."Usu_Alta"));
                Evaluate(EstructuraCabecera."Fec_Alta", GetValueAtCell(TempExcelBuffer, RowNo, 8));
                EstructuraCabecera."Usu_Modi" := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 9), 1, MaxStrLen(EstructuraCabecera."Usu_Modi"));
                Evaluate(EstructuraCabecera."Fec_Modi", GetValueAtCell(TempExcelBuffer, RowNo, 10));
                EstructuraCabecera.Modify();
            end;

            EstructuraPorDefecto := GetValueAtCell(TempExcelBuffer, RowNo, 6) = 'S';

            if EstructuraPorDefecto then
                if PedidoInterno.Get(EstructuraCabecera."Source No.") then begin
                    PedidoInterno."Estructura por Defecto" := EstructuraCabecera."No. Estructura";
                    PedidoInterno.Modify();
                end;

            Clear(EstructuraLinea);
            EstructuraLinea.Tipo := EstructuraLinea.Tipo::PedidoInterno;
            EstructuraLinea."Source No." := EstructuraCabecera."Source No.";
            EstructuraLinea."No. Estructura" := EstructuraCabecera."No. Estructura";
            //  EstructuraLinea."No. Linea" := GetNumLinea(EstructuraCabecera);
            // EstructuraLinea.Fase := GetValueAtCell(TempExcelBuffer, RowNo, 14);
            // EstructuraLinea.Secuencia := GetValueAtCell(TempExcelBuffer, RowNo, 15);
            if GetValueAtCell(TempExcelBuffer, RowNo, 14) <> '' then
                Evaluate(EstructuraLinea.Fase, GetValueAtCell(TempExcelBuffer, RowNo, 14));

            if GetValueAtCell(TempExcelBuffer, RowNo, 15) <> '' then
                Evaluate(EstructuraLinea.Secuencia, GetValueAtCell(TempExcelBuffer, RowNo, 15));

            TipAres := GetValueAtCell(TempExcelBuffer, RowNo, 16);

            Importar := true;
            case TipAres of
                'Q':
                    begin
                        EstructuraLinea."Tipo Linea" := EstructuraLinea."Tipo Linea"::Maquina;
                        EstructuraLinea."No." := GetValueAtCell(TempExcelBuffer, RowNo, 17);
                        Importar := WorkCenter.Get(EstructuraLinea."No.");
                        // Unidad de PRODUCCIÓN (ML) para la cantidad de la línea de máquina; la de preparación
                        // sí es tiempo/capacidad, por eso mantiene la unidad de capacidad del Work Center.
                        EstructuraLinea."Unidad Medida" := WorkCenter."Enteco Unidad Medida Prod.";
                        EstructuraLinea."Unidad Medida Preparacion" := WorkCenter."Unit of Measure Code";
                    end;
                'P', 'M', 'S':
                    begin
                        EstructuraLinea."Tipo Linea" := EstructuraLinea."Tipo Linea"::Producto;
                        EstructuraLinea."No." := TipAres + GetValueAtCell(TempExcelBuffer, RowNo, 17);
                        Importar := RecItem.Get(EstructuraLinea."No.");
                        EstructuraLinea."Unidad Medida" := RecItem."Base Unit of Measure";
                        EstructuraLinea."Unidad Medida Mermas" := RecItem."Base Unit of Measure";
                    end;
            end;

            if Importar then begin
                EstructuraLinea.Insert();

                if Evaluate(EstructuraLinea.Cantidad, GetValueAtCell(TempExcelBuffer, RowNo, 20)) then;
                //Evaluate(EstructuraLinea."Cantidad Mermas", GetValueAtCell(TempExcelBuffer, RowNo, 6));
                if Evaluate(EstructuraLinea."Cantidad Unidad Recurso", GetValueAtCell(TempExcelBuffer, RowNo, 21)) then;
                //EstructuraLinea."Fase Siguiente" := GetValueAtCell(TempExcelBuffer, RowNo, 26);
                FaseSiguiente := GetValueAtCell(TempExcelBuffer, RowNo, 26);
                if FaseSiguiente <> '' then
                    Evaluate(EstructuraLinea."Fase Siguiente", FaseSiguiente);

                EstructuraLinea."Usu_Alta" := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 22), 1, MaxStrLen(EstructuraLinea."Usu_Alta"));
                Evaluate(EstructuraLinea."Fec_Alta", GetValueAtCell(TempExcelBuffer, RowNo, 23));
                EstructuraLinea."Usu_Modi" := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 24), 1, MaxStrLen(EstructuraLinea."Usu_Modi"));
                Evaluate(EstructuraLinea."Fec_Modi", GetValueAtCell(TempExcelBuffer, RowNo, 25));

                EstructuraLinea.Modify();
            end;
        end;
    end;

    local procedure ImportExcelDataPedidosInternosPlanesCorte(var TempExcelBuffer: Record "Excel Buffer" temporary)
    var
        EntecoCabEstructura: Record "Enteco Cabecera Estructura";
        RowNo: Integer;
        MaxRowNo: Integer;
        ItemNo: Code[20];
        EstructuraNo: Code[75];
    begin
        RowNo := 0;
        MaxRowNo := 0;

        TempExcelBuffer.Reset();
        if TempExcelBuffer.FindLast() then
            MaxRowNo := TempExcelBuffer."Row No.";

        // OJO: los ficheros 01/02/03/12/13 tienen UNA SOLA fila de cabecera, asi que este 3
        // se salta la primera fila de datos. No se corrige a 2 porque el report no se va a
        // relanzar; las filas perdidas se recuperaron con el Report 50130.
        for RowNo := 3 to MaxRowNo do begin
            Clear(EntecoCabEstructura);
            ItemNo := GetValueAtCell(TempExcelBuffer, RowNo, 2);
            EstructuraNo := GetValueAtCell(TempExcelBuffer, RowNo, 8);

            EntecoCabEstructura.SetRange(Tipo, EntecoCabEstructura.Tipo::PedidoInterno);
            EntecoCabEstructura.SetRange("Source No.", ItemNo);
            EntecoCabEstructura.SetRange("No. Estructura", EstructuraNo);
            if EntecoCabEstructura.IsEmpty() then begin
                Clear(EntecoCabEstructura);
                EntecoCabEstructura.Tipo := EntecoCabEstructura.Tipo::PedidoInterno;
                EntecoCabEstructura."Source No." := ItemNo;
                EntecoCabEstructura."No. Estructura" := EstructuraNo;
                EntecoCabEstructura.Insert()
            end else
                EntecoCabEstructura.Get(EntecoCabEstructura.Tipo::PedidoInterno, ItemNo, EstructuraNo);

            Evaluate(EntecoCabEstructura."Ancho total", GetValueAtCell(TempExcelBuffer, RowNo, 3));
            Evaluate(EntecoCabEstructura."No. Cortes", GetValueAtCell(TempExcelBuffer, RowNo, 4));
            Evaluate(EntecoCabEstructura."Total Util", GetValueAtCell(TempExcelBuffer, RowNo, 5));
            Evaluate(EntecoCabEstructura."Desbarbe Izquierdo", GetValueAtCell(TempExcelBuffer, RowNo, 6));
            Evaluate(EntecoCabEstructura."Desbarbe Derecho", GetValueAtCell(TempExcelBuffer, RowNo, 7));
            // case GetValueAtCell(TempExcelBuffer, RowNo, 9) of
            //     'S':
            //         EntecoCabEstructura."Estructura Definida" := true;
            //     else
            //         EntecoCabEstructura."Estructura Definida" := false;
            // end;

            // Replica el cálculo del plan de corte sobre los valores importados: fuerza el Total Útil
            // y recalcula los desbarbes a 0 (mismo criterio que el alta interactiva).
            PlanifMgt.NormalizarDesbarbesCabecera(EntecoCabEstructura);

            EntecoCabEstructura."Usu_Alta" := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 10), 1, MaxStrLen(EntecoCabEstructura."Usu_Alta"));
            Evaluate(EntecoCabEstructura."Fec_Alta", GetValueAtCell(TempExcelBuffer, RowNo, 11));
            EntecoCabEstructura."Usu_Modi" := CopyStr(GetValueAtCell(TempExcelBuffer, RowNo, 12), 1, MaxStrLen(EntecoCabEstructura."Usu_Modi"));
            Evaluate(EntecoCabEstructura."Fec_Modi", GetValueAtCell(TempExcelBuffer, RowNo, 13));

            EntecoCabEstructura.Modify();
        end;
    end;

    local procedure CrearNosSeries()
    begin
        CrearNoSeries('PI_RCLCLIENTE', 'Pedido Interno - RCL Cliente', '9090000001', Enum::"Enteco Tipo Pedido Interno"::RCL_Cliente);
        CrearNoSeries('PI_BOBINAMUESTRA', 'Pedido Interno - Bobina Muestra', '9290000001', Enum::"Enteco Tipo Pedido Interno"::BobinaMuestra);
        CrearNoSeries('PI_PRECORTE', 'Pedido Interno - Precorte', '9390000001', Enum::"Enteco Tipo Pedido Interno"::Precorte);
        CrearNoSeries('PI_REPROCESO', 'Pedido Interno - Reproceso', '9490000001', Enum::"Enteco Tipo Pedido Interno"::Reproceso);
        CrearNoSeries('PI_OTROS', 'Pedido Interno - Otros', '9590000001', Enum::"Enteco Tipo Pedido Interno"::Otros);
        CrearNoSeries_OrdenTrabajo_PI('OTT_PI', 'OTT - Pedido Interno', '3');
        CrearNoSeries_OrdenTrabajo_PI('OT_PI', 'OT - Pedido Interno', '4');
    end;

    local procedure CrearNoSeries(Codigo: Code[20]; Descripcion: Text[100]; NumeroInicial: Code[20]; TipoPedidoInterno: Enum "Enteco Tipo Pedido Interno")
    var
        NoSeries: Record "No. Series";
    begin

        if not NoSeries.Get(Codigo) then begin
            NoSeries.Init();
            NoSeries.Validate(Code, Codigo);
            NoSeries.Insert(true);
        end;

        NoSeries.Validate(Description, Descripcion);
        NoSeries.Validate("Enteco Tipo", NoSeries."Enteco Tipo"::PedidoInterno);
        NoSeries.Validate("Enteco Tipo Pedido Interno", TipoPedidoInterno);
        NoSeries.Modify(true);

        CrearLineasNoSeries(Codigo, NumeroInicial, 0D, 1);
    end;

    local procedure CrearNoSeries_OrdenTrabajo_PI(Codigo: Code[20]; Descripcion: Text[100]; DigitoContol: Code[1])
    var
        NoSeries: Record "No. Series";
        Tipo: Enum "Enteco No. Series Type";
        Anno: Integer;
        Suffix: Code[6];
        i: Integer;
    begin
        case DigitoContol of
            '3':
                Tipo := NoSeries."Enteco Tipo"::PedidoInternoOTT;
            '4':
                Tipo := NoSeries."Enteco Tipo"::PedidoInternoOT;
            else
                Error('Proceso cancelado 1');
        end;

        NoSeries.Init();
        NoSeries.Validate(Code, Codigo);
        NoSeries.Validate(Description, Descripcion);
        NoSeries.Validate("Enteco Tipo", Tipo);
        if NoSeries.Insert(true) then;

        Anno := Date2DMY(WorkDate(), 3);
        if CompanyName() = 'Enteco_Pharma' then
            Suffix := DigitoContol + '00001'
        else
            Suffix := DigitoContol + '00002';

        CrearLineasNoSeries(Codigo, Format(Anno) + Suffix, DMY2Date(1, 1, Anno), 2);
        for i := 1 to 3 do begin
            i += 1;
            Anno += 1;
            CrearLineasNoSeries(Codigo, Format(Anno) + Suffix, DMY2Date(1, 1, Anno), 2);
        end;
    end;

    local procedure CrearLineasNoSeries(Codigo: Code[20]; NumeroInicial: Code[20]; FechaInicial: Date;
                                        Incremento: Integer)
    var
        LinNoSeries: Record "No. Series Line";
        LineNo: Integer;
    begin
        LinNoSeries.SetRange("Series Code", Codigo);
        if LinNoSeries.FindLast() then
            LineNo := LinNoSeries."Line No." + 10000
        else
            LineNo := 10000;

        Clear(LinNoSeries);
        LinNoSeries.Validate("Series Code", Codigo);
        LinNoSeries.Validate("Line No.", LineNo);
        LinNoSeries.Validate("Starting No.", NumeroInicial);
        if Incremento <> 1 then
            LinNoSeries.Validate("Increment-by No.", Incremento);
        if FechaInicial <> 0D then
            LinNoSeries.Validate("Starting Date", FechaInicial);
        if LinNoSeries.Insert(true) then;
    end;

    // Rellena la unidad de medida de PRODUCCIÓN de las máquinas (metros lineales, ML). Es un campo propio
    // del Work Center, distinto de la unidad de capacidad estándar ("Unit of Measure Code"), que BC reserva
    // para el cálculo de capacidad/tiempos y no debe llevar ML. La usan las líneas de máquina de las
    // estructuras (al importar) y de las OTT (al crearlas desde el pedido interno).
    local procedure RellenarUnidadProduccionMaquinas()
    var
        WorkCenter: Record "Work Center";
        UnidadProduccionMaquinaTok: Label 'ML', Locked = true;
    begin
        if WorkCenter.FindSet() then
            repeat
                if WorkCenter."Enteco Unidad Medida Prod." <> UnidadProduccionMaquinaTok then begin
                    WorkCenter."Enteco Unidad Medida Prod." := UnidadProduccionMaquinaTok;
                    WorkCenter.Modify();
                end;
            until WorkCenter.Next() = 0;
    end;

    local procedure RellenarEmojis()
    var
        WorkCenter: Record "Work Center";
        TipoProducto: Record "Enteco Tipo Producto";
    begin
        WorkCenter.FindSet();
        repeat
            case WorkCenter."Enteco Tipo Maquina" of
                WorkCenter."Enteco Tipo Maquina"::Cortadora:
                    WorkCenter.Icono := WorkCenter.Icono::Cortar;
                WorkCenter."Enteco Tipo Maquina"::Impresora:
                    WorkCenter.Icono := WorkCenter.Icono::Imprimir;
                WorkCenter."Enteco Tipo Maquina"::Laminadora:
                    WorkCenter.Icono := WorkCenter.Icono::Laminar;
                WorkCenter."Enteco Tipo Maquina"::Laqueadora:
                    WorkCenter.Icono := WorkCenter.Icono::Laquear;
            end;
            WorkCenter.Modify();
        until WorkCenter.Next() = 0;

        TipoProducto.FindSet();
        repeat
            case TipoProducto."Tipo Producto" of
                'A':
                    TipoProducto.Icono := TipoProducto.Icono::Embalaje1;
                'B':
                    TipoProducto.Icono := TipoProducto.Icono::Embalaje2;
                'M':
                    TipoProducto.Icono := TipoProducto.Icono::Material;
                'P':
                    TipoProducto.Icono := TipoProducto.Icono::"Producto Final";
                'S':
                    TipoProducto.Icono := TipoProducto.Icono::Semielaborado;
                'T':
                    TipoProducto.Icono := TipoProducto.Icono::Tintas;
                'U':
                    TipoProducto.Icono := TipoProducto.Icono::Laca;
            end;
            TipoProducto.Modify();
        until TipoProducto.Next() = 0;
    end;

    // Rellena en Company Information los dos parámetros de desbarbe usados por el cálculo del plan
    // de corte (ver "Enteco Planificacion Mgt".GetDesbarbes / CalcMaxNumCortes). Valores ORACLE:
    // DESBLIMI = 30 (límite del desbarbe simétrico) y DESBIZLI = 20 (desbarbe izquierdo fijo).
    // También inicializa la fórmula de fecha de servicio de pedidos internos a 20 días.
    local procedure RellenarConfigDesbarbes()
    var
        CompanyInformation: Record "Company Information";
    begin
        CompanyInformation.Get();
        CompanyInformation."Limite Desbarbe Simetrico" := 30;
        CompanyInformation."Desbarbe Izquierdo Limite" := 20;
        Evaluate(CompanyInformation."Formula Fecha Servicio PI", '20D'); // 20 días por defecto
        CompanyInformation.Modify();
    end;

    local procedure ImportExcelDataCabeceraLotes(var TempExcelBuffer: Record "Excel Buffer" temporary; EntecoProductionOrderType: Enum "Enteco Production Order Type")
    var
        ReservationEntry: Record "Reservation Entry";
        RowNo: Integer;
        MaxRowNo: Integer;
        NextEntryNo: Integer;
        Fase: Integer;
        Secuencia: Integer;
    begin
        RowNo := 0;
        MaxRowNo := 0;

        TempExcelBuffer.Reset();
        if TempExcelBuffer.FindLast() then
            MaxRowNo := TempExcelBuffer."Row No.";

        if ReservationEntry.FindLast() then
            NextEntryNo := ReservationEntry."Entry No." + 1
        else
            NextEntryNo := 1;

        // OJO: los ficheros 01/02/03/12/13 tienen UNA SOLA fila de cabecera, asi que este 3
        // se salta la primera fila de datos. No se corrige a 2 porque el report no se va a
        // relanzar; las filas perdidas se recuperaron con el Report 50130.
        for RowNo := 3 to MaxRowNo do begin
            Clear(ReservationEntry);
            ReservationEntry."Entry No." := NextEntryNo;
            ReservationEntry."Source Type" := Database::"Enteco Production Order Line";
            ReservationEntry."Source Subtype" := EntecoProductionOrderType.AsInteger();
            ReservationEntry."Source ID" := GetValueAtCell(TempExcelBuffer, RowNo, 3);
            if GetValueAtCell(TempExcelBuffer, RowNo, 7) <> '' then
                Evaluate(Fase, GetValueAtCell(TempExcelBuffer, RowNo, 7));

            if GetValueAtCell(TempExcelBuffer, RowNo, 8) <> '' then
                Evaluate(Secuencia, GetValueAtCell(TempExcelBuffer, RowNo, 8));
            ReservationEntry."Source Ref. No." := Fase * 100 + Secuencia; // Combina Fase y Secuencia para crear un identificador único
            ReservationEntry."Lot No." := GetValueAtCell(TempExcelBuffer, RowNo, 10);
            Evaluate(ReservationEntry.Quantity, GetValueAtCell(TempExcelBuffer, RowNo, 11));
            // ReservationEntry.Insert()
        end;
    end;

    local procedure Importar_PedidosInternos()
    begin
        Ventana.Open('Importación de Pedidos Internos');
        ImportarProcesarExcel('Pedidos');
        Commit();
        Ventana.Close();
    end;

    local procedure Importar_Estructuras_PedidosInternos()
    begin
        Ventana.Open('Importación de Estructuras de Pedidos Internos');
        ImportarProcesarExcel('Estructuras');
        Commit();
        Ventana.Close();
    end;

    local procedure ImportarPlanesCortePedidosInternos()
    begin
        Ventana.Open('Importación de Planes de Corte de Pedidos Internos');
        ImportarProcesarExcel('PlanesCorte');
        Commit();
        Ventana.Close();
    end;

    local procedure Importar_CabecerasOTT_PedidosInternos()
    begin
        Ventana.Open('Importación de Cabeceras OTT de Pedidos Internos');
        ImportarProcesarExcel('OTT');
        Commit();
        Ventana.Close();
    end;

    local procedure Importar_CabecerasOT_PedidosInternos()
    begin
        Ventana.Open('Importación de Cabeceras OT');
        ImportarProcesarExcel('OT');
        Commit();
        Ventana.Close();
    end;

    local procedure Importar_CabecerasCortesPersonalizados_PedidosInternos()
    begin
        Ventana.Open('Importación de Cabeceras Cortes Personalizados');
        ImportarProcesarExcel('OTTCortesPerso');
        Commit();

        ImportarProcesarExcel('OTCortesPerso');
        Commit();
        Ventana.Close();
    end;

    local procedure Importar_LineasOTT_PedidosInternos()
    begin
        Ventana.Open('Importación de Líneas OTT de Pedidos Internos');
        ImportarProcesarExcel('LIN_OTT');
        Commit();
        Ventana.Close();
    end;

    local procedure Importar_LineasOT_PedidosInternos()
    begin
        Ventana.Open('Importación de Líneas OT de Pedidos Internos');
        ImportarProcesarExcel('LIN_OT');
        Commit();
        Ventana.Close();
    end;

    local procedure Importar_LineasCortesPersonalizados_PedidosInternos()
    begin
        Ventana.Open('Importación de Líneas Cortes Personalizados');
        ImportarProcesarExcel('LIN_OTTCortesPerso');
        Commit();
        ImportarProcesarExcel('LIN_OTCortesPerso');
        Commit();
        Ventana.Close();
    end;

    local procedure Importar_AsignacionesLotesOTT_PedidosInternos()
    begin
        Ventana.Open('Importación de lotes de OTTs de Pedidos Internos');
        ImportarProcesarExcel('LotesTeoricosOTT');
        Commit();
        Ventana.Close();
    end;

    local procedure Importar_AsignacionesLotesOT_PedidosInternos()
    begin
        Ventana.Open('Importación de lotes de OTs de Pedidos Internos');
        ImportarProcesarExcel('LotesTeoricosOT');
        Commit();
        Ventana.Close();
    end;

    local procedure Importar_ObservacionesPartesTrabajo()
    begin
        Ventana.Open('Importación de Observaciones de Partes de Trabajo');
        ImportarProcesarExcel('ObservacionesPartesTrabajo');
        Commit();
        Ventana.Close();
    end;

    local procedure Importar_FichasTecnicas_Semielaborados()
    begin
        Ventana.Open('Importación de Fichas Técnicas de Semielaborados');
        ImportarProcesarExcel('FichasTecnicasSemielaborados');
        Commit();
        Ventana.Close();
    end;

    var
        Sufijo: Text;
        CodigoEmpresaOracle: Code[2];
        SoloCortesPersonalizados: Boolean;
        Ventana: Dialog;
        PlanifMgt: Codeunit "Enteco Planificacion Mgt";


    local procedure FixOtt()
    var
        RecCabOtt: Record "Enteco Production Order";
        RecCabOttAux: Record "Enteco Production Order";
    begin
        RecCabOtt.SetRange(Tipo, RecCabOtt.Tipo::"OTT");
        if RecCabOtt.FindSet() then
            repeat
                RecCabOttAux.Get(RecCabOtt.Tipo, RecCabOtt."No.");
                if RecCabOtt.Estado = RecCabOtt.Estado::Abierta then
                    RecCabOttAux.Estado := RecCabOttAux.Estado::Cerrada
                else if RecCabOtt.Estado = RecCabOtt.Estado::Cerrada then
                    RecCabOttAux.Estado := RecCabOttAux.Estado::Abierta;
                RecCabOttAux.Modify();
            until RecCabOtt.Next() = 0;
    end;

    local procedure Fix()
    var
        RecCabOt: Record "Enteco Production Order";
    begin
        RecCabOt.SetRange(Tipo, RecCabOt.Tipo::"OT");
        RecCabOt.SetRange(Estado, RecCabOt.Estado::" ");
        RecCabOt.ModifyAll(Estado, RecCabOt.Estado::Cerrada);
    end;

    local procedure RegistrarServiciosWeb()
    var
        WebServiceMgt: Codeunit "Web Service Management";
        TenantWebService: Record "Tenant Web Service";
    begin
        // Publica el codeunit de API. Expone TODOS sus métodos [ServiceEnabled] como unbound actions.
        // El valor del enum se toma del propio campo de la tabla para no tener que nombrar "Web Service Object Type".
        WebServiceMgt.CreateTenantWebService(TenantWebService."Object Type"::Codeunit, Codeunit::"Enteco Prod. Order Line API", 'EntecoProdOrderLineAPI', true);
    end;

    var
        FechaHoraImportacion: DateTime;
}