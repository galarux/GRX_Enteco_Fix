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

    // Ficha 00004. Marca el OK Comercial de la especialidad impresa P4TZ3012001 de Enteco_Manviel, que llegó
    // a «En Fabrica» sin él. Solo los tres campos del producto: ni estado, ni buffer, ni Oracle, ni pedido.
    procedure MarcarOkComercialEnFabrica(Simular: Boolean)
    var
        Item: Record Item;
        Usuario: Code[50];
    begin
        if CompanyName() <> 'Enteco_Manviel' then
            Error(EmpresaOkComercialErr, CompanyName());

        Item.Get(EspecialidadOkComercialTxt);
        if (Item."Enteco Tipo Producto" <> 'P') or not Item."Enteco Impreso" then
            Error(NoEsEspecialidadImpresaErr, Item."No.", Item."Enteco Tipo Producto", Item."Enteco Impreso");
        if Item."Enteco Estado Ficha Tecnica" <> Item."Enteco Estado Ficha Tecnica"::"En Fabrica" then
            Error(EstadoFichaTecnicaErr, Item."No.", Item."Enteco Estado Ficha Tecnica");

        IniciarResultado(Simular);
        if Item."Enteco Comercial Ok" then begin
            AnadirResultado(TablaItemTxt, Item."No.", Item.FieldCaption("Enteco Comercial Ok"), Format(Item."Enteco Comercial Ok"), Format(Item."Enteco Comercial Ok"), YaEstabaTxt);
            AnadirResultado(TablaItemTxt, Item."No.", Item.FieldCaption("Enteco ID Comercial Ok"), Item."Enteco ID Comercial Ok", Item."Enteco ID Comercial Ok", YaEstabaTxt);
            AnadirResultado(TablaItemTxt, Item."No.", Item.FieldCaption("Enteco Fecha Comercial ok"), Format(Item."Enteco Fecha Comercial ok"), Format(Item."Enteco Fecha Comercial ok"), YaEstabaTxt);
        end else begin
            Usuario := UsuarioDelComercial(Item."Enteco Comercial");
            AnadirResultado(TablaItemTxt, Item."No.", Item.FieldCaption("Enteco Comercial Ok"), Format(Item."Enteco Comercial Ok"), Format(true), CambiadoTxt);
            AnadirResultado(TablaItemTxt, Item."No.", Item.FieldCaption("Enteco ID Comercial Ok"), Item."Enteco ID Comercial Ok", Usuario, CambiadoTxt);
            AnadirResultado(TablaItemTxt, Item."No.", Item.FieldCaption("Enteco Fecha Comercial ok"), Format(Item."Enteco Fecha Comercial ok"), Format(Today()), CambiadoTxt);

            // Sin triggers: el OK por el botón cambia el estado y sincroniza el producto y el pedido con Oracle.
            if not SimularActivo then begin
                Item."Enteco Comercial Ok" := true;
                Item."Enteco ID Comercial Ok" := Usuario;
                Item."Enteco Fecha Comercial ok" := Today();
                Item.Modify(false);
            end;
        end;

        ExportarResultado('GRX Fix OK Comercial');
        Message(OkComercialTotalesMsg, ModoTxt(), NumCambiado, NumYaEstaba);
    end;

    // El comercial de la ficha es un vendedor; su usuario de BC es el único de User Setup que lo tiene.
    local procedure UsuarioDelComercial(Comercial: Code[10]): Code[50]
    var
        UserSetup: Record "User Setup";
        Usuarios: Text;
    begin
        if Comercial = '' then
            Error(SinComercialErr, EspecialidadOkComercialTxt);

        UserSetup.SetRange("Salespers./Purch. Code", Comercial);
        case UserSetup.Count() of
            0:
                Error(ComercialSinUsuarioErr, Comercial);
            1:
                begin
                    UserSetup.FindFirst();
                    exit(UserSetup."User ID");
                end;
            else begin
                UserSetup.FindSet();
                repeat
                    if Usuarios <> '' then
                        Usuarios += ', ';
                    Usuarios += UserSetup."User ID";
                until UserSetup.Next() = 0;
                Error(ComercialVariosUsuariosErr, Comercial, Usuarios);
            end;
        end;
    end;

    // Ficha 00005. Pasa la configuración MOD322 (declaración de IVA y «Formato transferencia») de
    // Pharma, Manviel y Extremadura al diseño de 2026. Por empresa, todo o nada: si una sola línea no
    // está ni en el estado de origen ni en el de destino, no graba nada en esa empresa.
    procedure CorregirConfiguracionMod322(Simular: Boolean)
    var
        ResumenPharma: Text;
        ResumenManviel: Text;
        ResumenExtremadura: Text;
    begin
        IniciarResultado(Simular);
        ResumenPharma := CorregirMod322Empresa('Enteco_Pharma');
        ResumenManviel := CorregirMod322Empresa('Enteco_Manviel');
        ResumenExtremadura := CorregirMod322Empresa('Enteco_Extremadura');
        ExportarResultado('GRX Fix MOD322');
        Message(Mod322TotalesMsg, ModoTxt(), ResumenPharma, ResumenManviel, ResumenExtremadura);
    end;

    local procedure CorregirMod322Empresa(Empresa: Text[30]): Text
    var
        Company: Record Company;
    begin
        if not Company.Get(Empresa) then begin
            AnadirResultado('', Empresa, '', '', '', EmpresaNoExisteTxt);
            exit(StrSubstNo(EmpresaNoExisteMod322Msg, Empresa));
        end;
        EmpresaActual := Empresa;

        // Primera pasada: solo cuenta las líneas que no coinciden. Segunda: informa y, si no hay
        // ninguna, graba.
        InformarMod322 := false;
        NumNoCoincide := 0;
        AplicarCambiosMod322();

        InformarMod322 := true;
        EmpresaCoincide := NumNoCoincide = 0;
        NumCambiadoMod322 := 0;
        NumYaEstabaMod322 := 0;
        NumNoCoincide := 0;
        AplicarCambiosMod322();

        exit(StrSubstNo(EmpresaMod322Msg, Empresa, NumCambiadoMod322, NumYaEstabaMod322, NumNoCoincide));
    end;

    local procedure AplicarCambiosMod322()
    begin
        // Declaración: las filas del 21 % pasan de [150]/[152] a [18]/[20].
        CambiarCasillaDeclaracion('152', '20');
        CambiarCasillaDeclaracion('150', '18');

        // Formato transferencia, por posición: el Nº de línea puede variar de una empresa a otra.
        CambiarCasillaFormato(733, '150', '');
        CambiarCasillaFormato(755, '152', '');
        PonerValorFormato(828, '00000');
        PonerValorFormato(945, '02100');
        ComprobarCasillaFormato(928, '18');
        ComprobarCasillaFormato(950, '20');
        CambiarCasillaFormato(2180, '65', '63');
        CambiarCasillaFormato(2299, '70', '63');
        BorrarLineaFormato(1948);
        MoverLineaFormato(2067, 2452);
        MoverLineaFormato(2081, 2466);
    end;

    local procedure CambiarCasillaDeclaracion(BoxOrigen: Code[5]; BoxDestino: Code[5])
    var
        VATStatementLine: Record "VAT Statement Line";
        NumOrigen: Integer;
        NumDestino: Integer;
    begin
        VATStatementLine.ChangeCompany(EmpresaActual);
        VATStatementLine.SetRange("Statement Name", Mod322Txt);
        VATStatementLine.SetRange(Box, BoxDestino);
        NumDestino := VATStatementLine.Count();
        VATStatementLine.SetRange(Box, BoxOrigen);
        NumOrigen := VATStatementLine.Count();

        if (NumOrigen = 1) and (NumDestino = 0) then begin
            VATStatementLine.FindFirst();
            if AnotarACambiar(TablaDeclaracionTxt, ClaveDeclaracion(VATStatementLine), VATStatementLine.FieldCaption(Box), BoxOrigen, BoxDestino) then begin
                VATStatementLine.Box := BoxDestino;
                VATStatementLine.Modify(false);
            end;
        end else
            if (NumOrigen = 0) and (NumDestino = 1) then begin
                VATStatementLine.SetRange(Box, BoxDestino);
                VATStatementLine.FindFirst();
                AnotarYaEstaba(TablaDeclaracionTxt, ClaveDeclaracion(VATStatementLine), VATStatementLine.FieldCaption(Box), BoxDestino, BoxDestino);
            end else
                AnotarNoCoincide(TablaDeclaracionTxt, StrSubstNo(ClaveCasillasTxt, EmpresaActual, BoxOrigen, BoxDestino), VATStatementLine.FieldCaption(Box),
                    StrSubstNo(FilasCasillasTxt, BoxOrigen, NumOrigen, BoxDestino, NumDestino), BoxDestino);
    end;

    // Con casilla, el Value lo pone el Report 50110 al generar el fichero; sin casilla tiene que
    // quedar vacío para que la posición salga a ceros.
    local procedure CambiarCasillaFormato(Posicion: Integer; BoxOrigen: Code[5]; BoxDestino: Code[5])
    var
        Formato: Record "AEAT Transference Format";
        NumLineas: Integer;
    begin
        NumLineas := LineaFormato(Formato, Posicion);
        if (NumLineas = 1) and EsNumerica(Formato, 17) then begin
            if (Formato.Box = BoxDestino) and ((BoxDestino <> '') or (Formato.Value = '')) then begin
                AnotarYaEstaba(TablaFormatoTxt, ClaveFormato(Formato), CampoCasillaValor(Formato),
                    CasillaValor(Formato.Box, Formato.Value), CasillaValor(Formato.Box, Formato.Value));
                exit;
            end;
            if Formato.Box in [BoxOrigen, BoxDestino] then begin
                if AnotarACambiar(TablaFormatoTxt, ClaveFormato(Formato), CampoCasillaValor(Formato),
                    CasillaValor(Formato.Box, Formato.Value), CasillaValor(BoxDestino, ''))
                then begin
                    Formato.Box := BoxDestino;
                    Formato.Value := '';
                    Formato.Modify(false);
                end;
                exit;
            end;
        end;
        AnotarNoCoincide(TablaFormatoTxt, ClavePosicion(Posicion), CampoCasillaValor(Formato),
            EstadoPosicion(Formato, NumLineas), CasillaValor(BoxDestino, ''));
    end;

    local procedure PonerValorFormato(Posicion: Integer; Valor: Text[250])
    var
        Formato: Record "AEAT Transference Format";
        NumLineas: Integer;
    begin
        NumLineas := LineaFormato(Formato, Posicion);
        if (NumLineas = 1) and EsNumerica(Formato, 5) then begin
            if Formato.Value = Valor then
                AnotarYaEstaba(TablaFormatoTxt, ClaveFormato(Formato), Formato.FieldCaption(Value), Formato.Value, Valor)
            else
                if AnotarACambiar(TablaFormatoTxt, ClaveFormato(Formato), Formato.FieldCaption(Value), Formato.Value, Valor) then begin
                    Formato.Value := Valor;
                    Formato.Modify(false);
                end;
            exit;
        end;
        AnotarNoCoincide(TablaFormatoTxt, ClavePosicion(Posicion), Formato.FieldCaption(Value), EstadoPosicion(Formato, NumLineas), Valor);
    end;

    local procedure ComprobarCasillaFormato(Posicion: Integer; Box: Code[5])
    var
        Formato: Record "AEAT Transference Format";
        NumLineas: Integer;
    begin
        NumLineas := LineaFormato(Formato, Posicion);
        if (NumLineas = 1) and EsNumerica(Formato, 17) and (Formato.Box = Box) then
            AnotarYaEstaba(TablaFormatoTxt, ClaveFormato(Formato), Formato.FieldCaption(Box), Formato.Box, Box)
        else
            AnotarNoCoincide(TablaFormatoTxt, ClavePosicion(Posicion), Formato.FieldCaption(Box), EstadoPosicion(Formato, NumLineas), Box);
    end;

    local procedure BorrarLineaFormato(Posicion: Integer)
    var
        Formato: Record "AEAT Transference Format";
        NumLineas: Integer;
    begin
        NumLineas := LineaFormato(Formato, Posicion);
        if NumLineas = 0 then
            AnotarYaEstaba(TablaFormatoTxt, ClavePosicion(Posicion), LineaTxt, SinLineaTxt, SinLineaTxt)
        else
            if (NumLineas = 1) and EsNumerica(Formato, 17) then begin
                if AnotarACambiar(TablaFormatoTxt, ClaveFormato(Formato), LineaTxt, DescribirFormato(Formato), BorradaTxt) then
                    Formato.Delete(false);
            end else
                AnotarNoCoincide(TablaFormatoTxt, ClavePosicion(Posicion), LineaTxt, EstadoPosicion(Formato, NumLineas), SinLineaTxt);
    end;

    local procedure MoverLineaFormato(Origen: Integer; Destino: Integer)
    var
        Formato: Record "AEAT Transference Format";
        FormatoDestino: Record "AEAT Transference Format";
        FormatoOcupa: Record "AEAT Transference Format";
        NumOrigen: Integer;
        NumDestino: Integer;
        EstadoDestino: Text;
    begin
        NumOrigen := LineaFormato(Formato, Origen);
        NumDestino := LineaFormato(FormatoDestino, Destino);

        if (NumOrigen = 0) and (NumDestino = 1) and (FormatoDestino.Length = 1) then begin
            AnotarYaEstaba(TablaFormatoTxt, ClaveFormato(FormatoDestino), FormatoDestino.FieldCaption(Position), Format(Origen), Format(Destino));
            exit;
        end;

        if PosicionOcupada(Destino, FormatoOcupa) then
            EstadoDestino := StrSubstNo(OcupadaTxt, FormatoOcupa.Position, FormatoOcupa."No.", FormatoOcupa.Length)
        else
            if (NumOrigen = 1) and (Formato.Length = 1) then begin
                if AnotarACambiar(TablaFormatoTxt, ClaveFormato(Formato), Formato.FieldCaption(Position), Format(Origen), Format(Destino)) then begin
                    Formato.Position := Destino;
                    Formato.Modify(false);
                end;
                exit;
            end else
                EstadoDestino := SinLineaTxt;

        AnotarNoCoincide(TablaFormatoTxt, ClavePosicion(Origen), Formato.FieldCaption(Position),
            StrSubstNo(EstadoMoverTxt, Origen, EstadoPosicion(Formato, NumOrigen), Destino, EstadoDestino), Format(Destino));
    end;

    // Devuelve cuántas líneas de MOD322 empiezan en la posición y, si es una, la deja en Formato.
    local procedure LineaFormato(var Formato: Record "AEAT Transference Format"; Posicion: Integer) NumLineas: Integer
    begin
        Formato.ChangeCompany(EmpresaActual);
        Formato.SetRange("VAT Statement Name", Mod322Txt);
        Formato.SetRange(Position, Posicion);
        NumLineas := Formato.Count();
        if NumLineas = 1 then
            Formato.FindFirst();
    end;

    local procedure PosicionOcupada(Posicion: Integer; var FormatoOcupa: Record "AEAT Transference Format"): Boolean
    begin
        FormatoOcupa.ChangeCompany(EmpresaActual);
        FormatoOcupa.SetRange("VAT Statement Name", Mod322Txt);
        FormatoOcupa.SetFilter(Position, '<=%1', Posicion);
        if FormatoOcupa.FindSet() then
            repeat
                if FormatoOcupa.Position + FormatoOcupa.Length > Posicion then
                    exit(true);
            until FormatoOcupa.Next() = 0;
        exit(false);
    end;

    local procedure EsNumerica(Formato: Record "AEAT Transference Format"; Longitud: Integer): Boolean
    begin
        exit((Formato.Length = Longitud) and (Formato.Type = Formato.Type::Numerical));
    end;

    local procedure EstadoPosicion(Formato: Record "AEAT Transference Format"; NumLineas: Integer): Text
    begin
        case NumLineas of
            0:
                exit(SinLineaTxt);
            1:
                exit(DescribirFormato(Formato));
            else
                exit(StrSubstNo(VariasLineasTxt, NumLineas));
        end;
    end;

    local procedure DescribirFormato(Formato: Record "AEAT Transference Format"): Text
    begin
        exit(StrSubstNo(DescripcionFormatoTxt, Formato.Length, Formato.Type, Formato.Box, Formato.Value));
    end;

    local procedure CampoCasillaValor(Formato: Record "AEAT Transference Format"): Text
    begin
        exit(StrSubstNo(DosValoresTxt, Formato.FieldCaption(Box), Formato.FieldCaption(Value)));
    end;

    local procedure CasillaValor(Box: Code[5]; Valor: Text): Text
    begin
        exit(StrSubstNo(DosValoresTxt, Box, Valor));
    end;

    local procedure ClaveDeclaracion(VATStatementLine: Record "VAT Statement Line"): Text
    begin
        exit(StrSubstNo(ClaveDeclaracionTxt, EmpresaActual, VATStatementLine."Line No.", VATStatementLine.Description));
    end;

    local procedure ClaveFormato(Formato: Record "AEAT Transference Format"): Text
    begin
        exit(StrSubstNo(ClaveFormatoTxt, EmpresaActual, Formato.Position, Formato."No.", Formato.Description));
    end;

    local procedure ClavePosicion(Posicion: Integer): Text
    begin
        exit(StrSubstNo(ClavePosicionTxt, EmpresaActual, Posicion));
    end;

    // Devuelve si hay que grabar el cambio: solo en la segunda pasada, sin Simular y si en la
    // empresa no hay ninguna línea que no coincida.
    local procedure AnotarACambiar(Tabla: Text; Clave: Text; Campo: Text; ValorAnterior: Text; ValorNuevo: Text): Boolean
    begin
        if not InformarMod322 then
            exit(false);
        if not EmpresaCoincide then begin
            AnadirResultado(Tabla, Clave, Campo, ValorAnterior, ValorNuevo, SinCambiarTxt);
            exit(false);
        end;
        NumCambiadoMod322 += 1;
        AnadirResultado(Tabla, Clave, Campo, ValorAnterior, ValorNuevo, CambiadoTxt);
        exit(not SimularActivo);
    end;

    local procedure AnotarYaEstaba(Tabla: Text; Clave: Text; Campo: Text; ValorAnterior: Text; ValorNuevo: Text)
    begin
        if not InformarMod322 then
            exit;
        NumYaEstabaMod322 += 1;
        AnadirResultado(Tabla, Clave, Campo, ValorAnterior, ValorNuevo, YaEstabaTxt);
    end;

    local procedure AnotarNoCoincide(Tabla: Text; Clave: Text; Campo: Text; ValorAnterior: Text; ValorNuevo: Text)
    begin
        NumNoCoincide += 1;
        if InformarMod322 then
            AnadirResultado(Tabla, Clave, Campo, ValorAnterior, ValorNuevo, NoCoincideTxt);
    end;

    // Ficha 00006. Copia el «Formato transferencia» MOD322 de Pharma (diseño de 2026, corregido con la
    // 00005) a Manviel, Extremadura y Gestión, con el mismo Nº de línea porque el Report 50110 busca
    // líneas por Nº, y deja en cada una sus datos de identificación. Las empresas se buscan por NIF.
    // Por empresa, todo o nada: si algo no coincide, esa empresa no se toca y las demás siguen.
    procedure CopiarFormatoMod322DesdePharma(Simular: Boolean)
    var
        Encontradas: Text;
        NumEmpresas: Integer;
        ResumenManviel: Text;
        ResumenExtremadura: Text;
        ResumenGestion: Text;
    begin
        NumEmpresas := EmpresasConNif(NifPharmaTxt, EmpresaOrigen, Encontradas);
        if NumEmpresas <> 1 then
            Error(OrigenEmpresaErr, NifPharmaTxt, NumEmpresas, Encontradas);
        ComprobarOrigenMod322();

        IniciarResultado(Simular);
        ResumenManviel := CopiarMod322AEmpresa(NifManvielTxt);
        ResumenExtremadura := CopiarMod322AEmpresa(NifExtremaduraTxt);
        ResumenGestion := CopiarMod322AEmpresa(NifGestionTxt);
        ExportarResultado('GRX Fix Copia MOD322');
        Message(CopiaMod322TotalesMsg, ModoTxt(), EmpresaOrigen, ResumenManviel, ResumenExtremadura, ResumenGestion);
    end;

    // Devuelve cuántas empresas tienen el NIF en Información de empresa; si es una, la deja en Empresa.
    local procedure EmpresasConNif(Nif: Text; var Empresa: Text[30]; var Encontradas: Text) NumEmpresas: Integer
    var
        Company: Record Company;
        CompanyInformation: Record "Company Information";
    begin
        Empresa := '';
        Encontradas := '';
        if Company.FindSet() then
            repeat
                CompanyInformation.ChangeCompany(Company.Name);
                CompanyInformation.SetLoadFields("VAT Registration No.");
                if CompanyInformation.Get() then
                    if NormalizarNif(CompanyInformation."VAT Registration No.") = Nif then begin
                        NumEmpresas += 1;
                        Empresa := Company.Name;
                        if Encontradas <> '' then
                            Encontradas += ', ';
                        Encontradas += Company.Name;
                    end;
            until Company.Next() = 0;
    end;

    local procedure NormalizarNif(Nif: Text): Text
    begin
        Nif := DelChr(UpperCase(Nif), '=', ' ');
        if Nif.StartsWith('ES') then
            Nif := CopyStr(Nif, 3);
        exit(Nif);
    end;

    // La copia solo vale si Pharma ya tiene la 00005 aplicada y las cuatro líneas de identificación;
    // si no, error y no se toca ninguna empresa. Deja en listas las casillas de Pharma.
    local procedure ComprobarOrigenMod322()
    var
        Formato: Record "AEAT Transference Format";
        VATStatementLine: Record "VAT Statement Line";
        NumLineas: Integer;
        Indice: Integer;
    begin
        EmpresaActual := EmpresaOrigen;
        NumLineas := LineaFormato(Formato, 2180);
        if (NumLineas <> 1) or (Formato.Box <> '63') then
            Error(OrigenSinCorregirErr, EmpresaOrigen, StrSubstNo(EstadoOrigenTxt, 2180, EstadoPosicion(Formato, NumLineas)));
        NumLineas := LineaFormato(Formato, 1948);
        if NumLineas <> 0 then
            Error(OrigenSinCorregirErr, EmpresaOrigen, StrSubstNo(EstadoOrigenTxt, 1948, EstadoPosicion(Formato, NumLineas)));
        NumLineas := LineaFormato(Formato, 945);
        if (NumLineas <> 1) or (Formato.Value <> '02100') then
            Error(OrigenSinCorregirErr, EmpresaOrigen, StrSubstNo(EstadoOrigenTxt, 945, EstadoPosicion(Formato, NumLineas)));

        IniciarIdentificacion();
        for Indice := 1 to ArrayLen(PosicionesIdentificacion) do begin
            NumLineas := LineaFormato(Formato, PosicionesIdentificacion[Indice]);
            if (NumLineas <> 1) or (Formato.Length <> LongitudesIdentificacion[Indice]) then
                Error(OrigenIdentificacionErr, EmpresaOrigen,
                    StrSubstNo(EstadoOrigenTxt, PosicionesIdentificacion[Indice], EstadoPosicion(Formato, NumLineas)));
        end;

        Clear(CasillasDeclaracionPharma);
        Clear(CasillasPharma);
        VATStatementLine.ChangeCompany(EmpresaOrigen);
        VATStatementLine.SetRange("Statement Name", Mod322Txt);
        VATStatementLine.SetFilter(Box, '<>%1', '');
        if VATStatementLine.FindSet() then
            repeat
                AnadirCasilla(CasillasDeclaracionPharma, VATStatementLine.Box);
                AnadirCasilla(CasillasPharma, VATStatementLine.Box);
            until VATStatementLine.Next() = 0;
        Formato.Reset();
        Formato.ChangeCompany(EmpresaOrigen);
        Formato.SetRange("VAT Statement Name", Mod322Txt);
        Formato.SetFilter(Box, '<>%1', '');
        if Formato.FindSet() then
            repeat
                AnadirCasilla(CasillasPharma, Formato.Box);
            until Formato.Next() = 0;
    end;

    local procedure IniciarIdentificacion()
    begin
        PosicionesIdentificacion[1] := 342;
        LongitudesIdentificacion[1] := 9;
        PosicionesIdentificacion[2] := 351;
        LongitudesIdentificacion[2] := 60;
        PosicionesIdentificacion[3] := 447;
        LongitudesIdentificacion[3] := 1;
        PosicionesIdentificacion[4] := 448;
        LongitudesIdentificacion[4] := 9;
    end;

    local procedure EsPosicionIdentificacion(Posicion: Integer; var Indice: Integer): Boolean
    begin
        for Indice := 1 to ArrayLen(PosicionesIdentificacion) do
            if PosicionesIdentificacion[Indice] = Posicion then
                exit(true);
        exit(false);
    end;

    local procedure CopiarMod322AEmpresa(Nif: Text[20]): Text
    var
        Encontradas: Text;
        NumEmpresas: Integer;
    begin
        NumEmpresas := EmpresasConNif(Nif, EmpresaActual, Encontradas);
        if NumEmpresas <> 1 then begin
            AnadirResultado('', StrSubstNo(ClaveNifTxt, Nif), '', Encontradas, '', EmpresaNoEncontradaTxt);
            exit(StrSubstNo(EmpresaNoEncontradaMsg, Nif, NumEmpresas));
        end;
        NifActual := Nif;

        // Primera pasada: solo cuenta lo que no coincide. Segunda: informa y, si no hay nada, graba.
        InformarMod322 := false;
        NumNoCoincide := 0;
        ValidarDestinoMod322();

        InformarMod322 := true;
        EmpresaCoincide := NumNoCoincide = 0;
        NumCambiadoMod322 := 0;
        NumYaEstabaMod322 := 0;
        NumNoCoincide := 0;
        NumBorradas := 0;
        NumInsertadas := 0;
        NumRevisar := 0;
        ValidarDestinoMod322();
        AnotarRevisarMod322();
        if EmpresaCoincide then
            CopiarLineasFormatoMod322();

        AnadirResultado('', EmpresaActual, TotalTxt, '',
            StrSubstNo(TotalCopiaTxt, NumBorradas, NumInsertadas, NumRevisar, NumNoCoincide), TotalTxt);
        exit(StrSubstNo(EmpresaCopiaMod322Msg, EmpresaActual, NumBorradas, NumInsertadas, NumRevisar, NumNoCoincide));
    end;

    local procedure ValidarDestinoMod322()
    var
        Indice: Integer;
    begin
        for Indice := 1 to ArrayLen(PosicionesIdentificacion) do
            ComprobarIdentificacion(Indice);
        ComprobarCasillasDeclaracion();
        CambiarCasillaDeclaracion('152', '20');
        CambiarCasillaDeclaracion('150', '18');
    end;

    // El valor de identificación del formato actual del destino es el que se queda en la copia; la razón
    // social, en mayúsculas y sin acentos.
    local procedure ComprobarIdentificacion(Indice: Integer)
    var
        Formato: Record "AEAT Transference Format";
        Posicion: Integer;
        NumLineas: Integer;
        Esperado: Text;
    begin
        Posicion := PosicionesIdentificacion[Indice];
        NumLineas := LineaFormato(Formato, Posicion);
        if (NumLineas = 1) and (Formato.Length = LongitudesIdentificacion[Indice]) and (Formato.Value <> '') and
           ((Posicion <> 342) or (NormalizarNif(Formato.Value) = NifActual))
        then begin
            ValoresIdentificacion[Indice] := Formato.Value;
            if Posicion = 351 then
                ValoresIdentificacion[Indice] := CopyStr(QuitarAcentos(Formato.Value), 1, MaxStrLen(ValoresIdentificacion[Indice]));
            if InformarMod322 then
                AnadirResultado(TablaFormatoTxt, ClaveFormato(Formato), Formato.FieldCaption(Value), Formato.Value, ValoresIdentificacion[Indice], SeMantieneTxt);
            exit;
        end;

        Esperado := StrSubstNo(IdentificacionEsperadaTxt, LongitudesIdentificacion[Indice]);
        if Posicion = 342 then
            Esperado := StrSubstNo(DosValoresTxt, Esperado, NifActual);
        AnotarNoCoincide(TablaFormatoTxt, ClavePosicion(Posicion), Formato.FieldCaption(Value), EstadoPosicion(Formato, NumLineas), Esperado);
    end;

    local procedure QuitarAcentos(Texto: Text): Text
    begin
        exit(ConvertStr(UpperCase(Texto), 'ÁÉÍÓÚÜ', 'AEIOUU'));
    end;

    // Toda casilla de la declaración del destino (con el cambio D1/D2 hecho) tiene que estar en la
    // declaración o en el formato de Pharma: si no, su importe no saldría en el fichero.
    local procedure ComprobarCasillasDeclaracion()
    var
        VATStatementLine: Record "VAT Statement Line";
        Faltan: List of [Code[5]];
        Casilla: Code[5];
    begin
        Clear(CasillasDestino);
        VATStatementLine.ChangeCompany(EmpresaActual);
        VATStatementLine.SetRange("Statement Name", Mod322Txt);
        VATStatementLine.SetFilter(Box, '<>%1', '');
        if VATStatementLine.FindSet() then
            repeat
                Casilla := CasillaTrasCambio(VATStatementLine.Box);
                AnadirCasilla(CasillasDestino, Casilla);
                if not CasillasPharma.Contains(Casilla) then
                    AnadirCasilla(Faltan, Casilla);
            until VATStatementLine.Next() = 0;

        if Faltan.Count() > 0 then
            AnotarNoCoincide(TablaDeclaracionTxt, StrSubstNo(ClaveCasillasPharmaTxt, EmpresaActual), VATStatementLine.FieldCaption(Box),
                UnirCasillas(Faltan), '');
    end;

    local procedure CasillaTrasCambio(Box: Code[5]): Code[5]
    begin
        case Box of
            '152':
                exit('20');
            '150':
                exit('18');
        end;
        exit(Box);
    end;

    local procedure AnadirCasilla(var Casillas: List of [Code[5]]; Casilla: Code[5])
    begin
        if not Casillas.Contains(Casilla) then
            Casillas.Add(Casilla);
    end;

    local procedure UnirCasillas(Casillas: List of [Code[5]]) Texto: Text
    var
        Casilla: Code[5];
    begin
        foreach Casilla in Casillas do begin
            if Texto <> '' then
                Texto += ', ';
            Texto += Casilla;
        end;
    end;

    // Informativo, no bloquea: líneas de texto de Pharma con valor que en el formato antiguo del destino,
    // en la misma posición y longitud, tienen otro valor (por si es un dato propio de la empresa).
    local procedure AnotarRevisarMod322()
    var
        FormatoOrigen: Record "AEAT Transference Format";
        Formato: Record "AEAT Transference Format";
        Indice: Integer;
    begin
        FormatoOrigen.ChangeCompany(EmpresaOrigen);
        FormatoOrigen.SetRange("VAT Statement Name", Mod322Txt);
        FormatoOrigen.SetFilter(Type, '<>%1', FormatoOrigen.Type::Numerical);
        FormatoOrigen.SetFilter(Value, '<>%1', '');
        if FormatoOrigen.FindSet() then
            repeat
                if not EsPosicionIdentificacion(FormatoOrigen.Position, Indice) then
                    if LineaFormato(Formato, FormatoOrigen.Position) = 1 then
                        if (Formato.Length = FormatoOrigen.Length) and (Formato.Value <> FormatoOrigen.Value) then begin
                            NumRevisar += 1;
                            AnadirResultado(TablaFormatoTxt, ClaveFormato(Formato), Formato.FieldCaption(Value), Formato.Value, FormatoOrigen.Value, RevisarTxt);
                        end;
            until FormatoOrigen.Next() = 0;
    end;

    // Borra el formato MOD322 del destino (cada línea queda en el Excel como copia de seguridad) e
    // inserta las de Pharma con el mismo Nº.
    local procedure CopiarLineasFormatoMod322()
    var
        Formato: Record "AEAT Transference Format";
        FormatoOrigen: Record "AEAT Transference Format";
    begin
        Formato.ChangeCompany(EmpresaActual);
        Formato.SetRange("VAT Statement Name", Mod322Txt);
        if Formato.FindSet() then
            repeat
                NumBorradas += 1;
                AnadirResultado(TablaFormatoTxt, ClaveFormato(Formato), DescribirLineaFormato(Formato), Formato.Value, '', BorradaTxt);
            until Formato.Next() = 0;
        if not SimularActivo then
            Formato.DeleteAll(false);

        FormatoOrigen.ChangeCompany(EmpresaOrigen);
        FormatoOrigen.SetRange("VAT Statement Name", Mod322Txt);
        if FormatoOrigen.FindSet() then
            repeat
                Formato.Init();
                Formato.TransferFields(FormatoOrigen);
                Formato.Value := ValorEnDestino(FormatoOrigen);
                NumInsertadas += 1;
                AnadirResultado(TablaFormatoTxt, ClaveFormato(Formato), DescribirLineaFormato(Formato), '', Formato.Value, InsertadaTxt);
                if not SimularActivo then
                    Formato.Insert(false);
            until FormatoOrigen.Next() = 0;
    end;

    // Identificación: la del destino. Numéricas con casilla de la declaración: vacías, las recalcula el
    // Report 50110 y así no viaja ningún importe de Pharma. Numéricas con casilla que no está en ninguna
    // declaración (tipos como el 02100 de la 945): el report no las toca y se copian tal cual.
    local procedure ValorEnDestino(FormatoOrigen: Record "AEAT Transference Format"): Text[250]
    var
        Indice: Integer;
    begin
        if EsPosicionIdentificacion(FormatoOrigen.Position, Indice) then
            exit(ValoresIdentificacion[Indice]);
        if (FormatoOrigen.Type <> FormatoOrigen.Type::Numerical) or (FormatoOrigen.Box = '') then
            exit(FormatoOrigen.Value);
        if CasillasDeclaracionPharma.Contains(FormatoOrigen.Box) or CasillasDestino.Contains(FormatoOrigen.Box) then
            exit('');
        if DelChr(FormatoOrigen.Value, '=', '0 ') <> '' then begin
            NumRevisar += 1;
            AnadirResultado(TablaFormatoTxt, ClaveFormato(FormatoOrigen), FormatoOrigen.FieldCaption(Value), '', FormatoOrigen.Value, RevisarCasillaTxt);
        end;
        exit(FormatoOrigen.Value);
    end;

    local procedure DescribirLineaFormato(Formato: Record "AEAT Transference Format"): Text
    begin
        exit(StrSubstNo(DescripcionLineaTxt, Formato.Length, Formato.Type, Formato.Subtype, Formato.Box));
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
        // La celda del Excel Buffer admite 250 caracteres; la clave lleva la descripción de la línea.
        TempResultado.NewRow();
        TempResultado.AddColumn(Tabla, false, '', false, false, false, '', TempResultado."Cell Type"::Text);
        TempResultado.AddColumn(CopyStr(Clave, 1, MaxStrLen(TempResultado."Cell Value as Text")), false, '', false, false, false, '', TempResultado."Cell Type"::Text);
        TempResultado.AddColumn(Campo, false, '', false, false, false, '', TempResultado."Cell Type"::Text);
        TempResultado.AddColumn(CopyStr(ValorAnterior, 1, MaxStrLen(TempResultado."Cell Value as Text")), false, '', false, false, false, '', TempResultado."Cell Type"::Text);
        TempResultado.AddColumn(CopyStr(ValorNuevo, 1, MaxStrLen(TempResultado."Cell Value as Text")), false, '', false, false, false, '', TempResultado."Cell Type"::Text);
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
        EmpresaActual: Text[30];
        InformarMod322: Boolean;
        EmpresaCoincide: Boolean;
        NumCambiadoMod322: Integer;
        NumYaEstabaMod322: Integer;
        NumNoCoincide: Integer;
        EmpresaOrigen: Text[30];
        NifActual: Text[20];
        PosicionesIdentificacion: array[4] of Integer;
        LongitudesIdentificacion: array[4] of Integer;
        ValoresIdentificacion: array[4] of Text[250];
        CasillasDeclaracionPharma: List of [Code[5]];
        CasillasPharma: List of [Code[5]];
        CasillasDestino: List of [Code[5]];
        NumBorradas: Integer;
        NumInsertadas: Integer;
        NumRevisar: Integer;
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
        EmpresaOkComercialErr: Label 'Este proceso es solo para Enteco_Manviel; está en %1.', Comment = '%1 = nombre de la empresa';
        NoEsEspecialidadImpresaErr: Label 'El producto %1 no es una especialidad impresa (Tipo Producto %2, Impreso %3).', Comment = '%1 = producto, %2 = tipo de producto, %3 = impreso';
        EstadoFichaTecnicaErr: Label 'La especialidad %1 está en estado %2, no en En Fabrica.', Comment = '%1 = producto, %2 = estado de la ficha técnica';
        SinComercialErr: Label 'La especialidad %1 no tiene comercial.', Comment = '%1 = producto';
        ComercialSinUsuarioErr: Label 'Ningún usuario de Configuración usuarios tiene el comercial %1.', Comment = '%1 = código del comercial';
        ComercialVariosUsuariosErr: Label 'Varios usuarios de Configuración usuarios tienen el comercial %1: %2.', Comment = '%1 = código del comercial, %2 = usuarios';
        OkComercialTotalesMsg: Label '%1. Cambiado: %2. Ya estaba: %3.', Comment = '%1 = Simulación o Ejecución, %2 = cambiados, %3 = ya estaban';
        Mod322TotalesMsg: Label '%1.\%2\%3\%4', Comment = '%1 = Simulación o Ejecución, %2 = resumen de Pharma, %3 = resumen de Manviel, %4 = resumen de Extremadura';
        EmpresaMod322Msg: Label '%1: cambiados %2, ya estaba %3, no coincide %4.', Comment = '%1 = empresa, %2 = cambiados, %3 = ya estaban, %4 = no coinciden';
        EmpresaNoExisteMod322Msg: Label '%1: la empresa no existe.', Comment = '%1 = empresa';
        EmpresaNoExisteTxt: Label 'Empresa no existe';
        NoCoincideTxt: Label 'No coincide';
        SinCambiarTxt: Label 'Sin cambiar: hay líneas que no coinciden en la empresa';
        LineaTxt: Label 'Línea';
        SinLineaTxt: Label 'Sin línea';
        BorradaTxt: Label 'Borrada';
        VariasLineasTxt: Label '%1 líneas', Comment = '%1 = número de líneas';
        OcupadaTxt: Label 'ocupada por la línea de la posición %1 (Nº %2, long. %3)', Comment = '%1 = posición, %2 = Nº de línea, %3 = longitud';
        EstadoMoverTxt: Label '%1: %2; %3: %4', Comment = '%1 = posición de origen, %2 = su estado, %3 = posición de destino, %4 = su estado';
        DescripcionFormatoTxt: Label 'Long. %1, tipo %2, casilla %3, valor %4', Comment = '%1 = longitud, %2 = tipo, %3 = casilla, %4 = valor';
        FilasCasillasTxt: Label 'Casilla %1: %2 filas; casilla %3: %4 filas', Comment = '%1 = casilla de origen, %2 = filas, %3 = casilla de destino, %4 = filas';
        ClaveDeclaracionTxt: Label '%1 · Nº línea %2 %3', Comment = '%1 = empresa, %2 = Nº de línea, %3 = descripción';
        ClaveFormatoTxt: Label '%1 · posición %2 (Nº %3) %4', Comment = '%1 = empresa, %2 = posición, %3 = Nº de línea, %4 = descripción';
        ClavePosicionTxt: Label '%1 · posición %2', Comment = '%1 = empresa, %2 = posición';
        ClaveCasillasTxt: Label '%1 · casilla %2 → %3', Comment = '%1 = empresa, %2 = casilla de origen, %3 = casilla de destino';
        OrigenEmpresaErr: Label 'Tiene que haber exactamente una empresa con el NIF %1 (Pharma, origen de la copia); hay %2: %3. No se ha tocado nada.', Comment = '%1 = NIF, %2 = número de empresas, %3 = empresas';
        OrigenSinCorregirErr: Label 'El formato MOD322 de %1 no tiene aplicada la ficha 00005 (%2). No se ha tocado nada.', Comment = '%1 = empresa, %2 = estado de la posición';
        OrigenIdentificacionErr: Label 'El formato MOD322 de %1 no tiene la línea de identificación esperada (%2). No se ha tocado nada.', Comment = '%1 = empresa, %2 = estado de la posición';
        EstadoOrigenTxt: Label 'posición %1: %2', Comment = '%1 = posición, %2 = estado de la posición';
        CopiaMod322TotalesMsg: Label '%1. Origen: %2.\%3\%4\%5', Comment = '%1 = Simulación o Ejecución, %2 = empresa de origen, %3 = resumen de Manviel, %4 = resumen de Extremadura, %5 = resumen de Gestión';
        EmpresaCopiaMod322Msg: Label '%1: borradas %2, insertadas %3, revisar %4, no coincide %5.', Comment = '%1 = empresa, %2 = líneas borradas, %3 = líneas insertadas, %4 = filas a revisar, %5 = no coinciden';
        EmpresaNoEncontradaMsg: Label 'NIF %1: %2 empresas con ese NIF, sin tocar.', Comment = '%1 = NIF, %2 = número de empresas';
        EmpresaNoEncontradaTxt: Label 'Empresa no encontrada';
        ClaveNifTxt: Label 'NIF %1', Comment = '%1 = NIF';
        ClaveCasillasPharmaTxt: Label '%1 · casillas que no están en Pharma', Comment = '%1 = empresa';
        IdentificacionEsperadaTxt: Label 'Una línea de long. %1 con valor', Comment = '%1 = longitud';
        DescripcionLineaTxt: Label 'Long. %1, tipo %2, subtipo %3, casilla %4', Comment = '%1 = longitud, %2 = tipo, %3 = subtipo, %4 = casilla';
        SeMantieneTxt: Label 'Se mantiene';
        InsertadaTxt: Label 'Insertada';
        RevisarTxt: Label 'Revisar';
        RevisarCasillaTxt: Label 'Revisar: casilla sin fila en la declaración, se copia el valor de Pharma';
        TotalTxt: Label 'Total';
        TotalCopiaTxt: Label 'Borradas %1, insertadas %2, revisar %3, no coincide %4', Comment = '%1 = líneas borradas, %2 = líneas insertadas, %3 = filas a revisar, %4 = no coinciden';
        NifPharmaTxt: Label 'B28296812', Locked = true;
        NifManvielTxt: Label 'B28630796', Locked = true;
        NifExtremaduraTxt: Label 'B10382638', Locked = true;
        NifGestionTxt: Label 'B82770652', Locked = true;
        DosValoresTxt: Label '%1 / %2', Locked = true;
        Mod322Txt: Label 'MOD322', Locked = true;
        TablaDeclaracionTxt: Label '256 VAT Statement Line', Locked = true;
        TablaFormatoTxt: Label '10705 AEAT Transference Format', Locked = true;
        EspecialidadOkComercialTxt: Label 'P4TZ3012001', Locked = true;
        TablaItemTxt: Label '27 Item', Locked = true;
        TablaOTTxt: Label '50050 Enteco Production Order', Locked = true;
        TablaOrdenTxt: Label '5405 Production Order', Locked = true;
        ClaveEstructuraTxt: Label '%1 %2 / %3 / %4 / F%5 S%6', Locked = true;
        ClaveLineaOTTxt: Label '%1 %2 / %3 / F%4 S%5', Locked = true;
        ClaveComponenteTxt: Label '%1 %2 / %3 / %4 / %5', Locked = true;
}