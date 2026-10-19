---
id: 00004
titulo: "Marcar el OK Comercial de la especialidad impresa P4TZ3012001 (Enteco_Manviel), que llegó a «En Fabrica» sin él, sin cambiar su estado ni sincronizar con ORACLE"
repo: GRX_Enteco_Fix
rama: master
estado: en pruebas
creado: 2026-10-19
modificado: 2026-10-19
proyecto: ENTECO Comercial Mejoras
commits: []
---

# Marcar el OK Comercial de la especialidad impresa P4TZ3012001 (Enteco_Manviel), que llegó a «En Fabrica» sin él, sin cambiar su estado ni sincronizar con ORACLE

## Objetivo
La especialidad impresa `P4TZ3012001` de Enteco_Manviel está en estado «En Fabrica» sin que el comercial diera el OK Comercial (caso puntual). El botón «Ok Comercial» ya no deja darlo porque solo funciona en «En Comercial» o «En Pre Impresion». Mientras falte, el pedido no admite fecha de compromiso propuesta y los informes la cuentan como pendiente de OK. Se marca una sola vez con un proceso del `Report 50025 "GRX Fix"`, que lanza Daniel (Tecnología) primero simulando.

## Contexto
El porqué está en la tarea del 19-10-2026 del proyecto «ENTECO Comercial Mejoras» de la bóveda; qué es el OK Comercial y qué bloquea está en «ENTECO Comercial», sección «OK Comercial».

Lo que hace hoy el botón (MigracionBC; no se reutiliza):
- Página 50085 «Enteco Especialidades Card New» → `Item.Enteco_PasoOKComercial()` (`TableExt 50004`); página 50051 «Enteco EspecialidadesCardBuff.» → `"Enteco Item Buffer".PasoOKComercial()` (`Table 50038`).
- Ambos: error si el estado no es «En Comercial» o «En Pre Impresion»; ponen `Comercial Ok` = true, `ID Comercial Ok` = `UserId()`, `Fecha Comercial ok` = `Today()`; cambian el estado (a «En Planificacion» o se queda en «En Pre Impresion»); llaman a `FunSincronizarProductoOracle` (el XmlPort 50008 manda `fec_ok`); recalculan la fecha de servicio de la línea del pedido; mandan el pedido a ORACLE (`FunAltaModificacionPedidoVentaOracle`) y, si es Nuevo/Modificado, el correo de importe.
- Repetirlo ahora sería dañino: bajaría el estado de «En Fabrica»; en ORACLE (`general.sql`, carga de `NAV_ARTICULO`) la fecha del OK o bien inserta seguimientos (alertas 397 y 395 en `PREIMPRE.PRI_SEGUTRAB`) en un trabajo ya en fábrica, o bien deja el error «Ya se dio el Ok de Comercial. Esta sincronización no debió llegar»; y reenviaría el pedido y quizá el correo.

Qué cambia en BC al marcar los tres campos del producto:
- `Codeunit 50019`, `FunOnBeforeValidateFechaCompromisoProp`: deja de dar «Especialidad sin OK Comercial. No es posible solicitar fecha.».
- `Report 50064 "Enteco Ventas"`: deja de salir «Pendiente OK Comercial = SI».
- `Report 50061 "Enteco Pedidos Pdtes.Logistica"`: deja de contarla como pendiente.
- Queda bloqueada como cualquier especialidad con OK: observaciones comerciales (páginas 50074/50091/50094) y edición en la página 50085. Es lo normal.

Campos (`TableExt 50004` de Item, sin triggers): `"Enteco Comercial Ok"` (Boolean, 50078), `"Enteco ID Comercial Ok"` (Code[60], 50079), `"Enteco Fecha Comercial ok"` (Date, 50080). El comercial de la ficha es `"Enteco Comercial"` (Code[10], 50090, relación con `Salesperson/Purchaser`): es un código de vendedor, no un usuario de BC.

Decisión de Daniel (19-10-2026): `ID Comercial Ok` = el usuario de BC del comercial de la ficha; fecha = día de ejecución.

## Diseño
Sin objetos, tablas ni campos nuevos.

1. `Codeunit 50089 "GRX Main"`, procedimiento nuevo `MarcarOkComercialEnFabrica(Simular: Boolean)`:
   1. Comprueba `CompanyName() = 'Enteco_Manviel'`; si no, error claro.
   2. `Item.Get('P4TZ3012001')`. Comprueba `"Enteco Tipo Producto" = 'P'`, `"Enteco Impreso"` = true, `"Enteco Estado Ficha Tecnica"` = «En Fabrica» y `"Enteco Comercial Ok"` = false. Si ya tiene el OK, no es error: resultado «Ya estaba» y no graba.
   3. Usuario: `User Setup` filtrado por `"Salespers./Purch. Code"` = `Item."Enteco Comercial"`. Si hay exactamente uno, su `User ID`. Si no hay ninguno o hay varios, error con el código del comercial y los usuarios encontrados; no graba y Daniel decide.
   4. Si no es Simular: asigna los tres campos (`true`, el usuario, `Today()`) y `Modify(false)`. Nada más: ni estado, ni buffer, ni versiones, ni ORACLE, ni pedido.
   5. Resultado con los helpers que ya existen (`IniciarResultado`, `AnadirResultado`, `ExportarResultado`): una fila por campo (Tabla `Item`, Clave el código, Campo, Valor anterior, Valor nuevo, Resultado) y el `Message` de siempre.
2. `Report 50025 "GRX Fix"`, `OnPreReport`: la llamada pasa de `RepararRecursoColaOT(Simular)` a `MarcarOkComercialEnFabrica(Simular)`. Daniel da por ejecutada la ficha 00003.
3. `app.json`: versión `26.10.19.1`. Compilar con CodeCop sin warnings nuevos.

Con `Modify(false)` solo salta `FunOnModifyItem` (`Codeunit 50019`, ajusta las unidades ML/KG y no cambia nada si no han cambiado); la sincronización de `Codeunit 50028` exige `RunTrigger` y excluye los productos `P`.

Qué NO se toca: MigracionBC, el estado de la ficha técnica, `"Enteco Item Buffer"` (se rellena desde el producto al editar), `"Enteco Versiones Ficha Tecnica"`, ORACLE (`ARTICULOS.FECHOKCO` se queda como esté), el pedido de venta y su fecha de servicio.

## Casos
1. Manviel, especialidad en «En Fabrica» sin OK y comercial con un único usuario: Simular lista los tres cambios sin grabar; ejecutar los graba.
2. Segunda ejecución: «Ya estaba», 0 cambios.
3. Lanzado en otra empresa: error, nada cambia.
4. Estado distinto de «En Fabrica», o producto no impreso: error, nada cambia.
5. Comercial vacío, sin usuario o con varios usuarios en `User Setup`: error con el detalle, nada cambia.

## Pruebas de aceptación
1. Compila con CodeCop sin warnings nuevos; publicar en PRE (`BC25_DESARROLLO`) con usuarios conectados no pide sincronizar esquema.
2. PRE, Enteco_Pharma: error de empresa, nada cambia.
3. Producción (`BC252`), Enteco_Manviel, Simular: Excel con 3 filas (`Enteco Comercial Ok` No → Sí, `Enteco ID Comercial Ok` vacío → usuario del comercial, `Enteco Fecha Comercial ok` vacío → fecha del día); el producto no cambia.
4. Producción, Manviel, sin Simular: la ficha de `P4TZ3012001` muestra OK Comercial con ese usuario y fecha y sigue en «En Fabrica»; ninguna sincronización a ORACLE en el log de web services; el pedido de la especialidad ya admite fecha de compromiso propuesta.
5. Repetir: «Ya estaba».

## Después
- El `Report 50025` queda apuntando a `MarcarOkComercialEnFabrica`. `RepararRecursoColaOT` sigue en la codeunit.
- Si ORACLE necesitara la fecha del OK (`ARTICULOS.FECHOKCO`), se pediría aparte a su equipo; hoy no se ha visto nada que la use salvo la propia carga.
- Averiguar cómo llegó la especialidad a «En Fabrica» sin OK (pendiente en el proyecto).
- No cambia nada que vea el usuario: no hay que tocar el manual.

## Desviaciones del plan
Ninguna en el código. Dos detalles que la ficha no fijaba:
- Las comprobaciones de tipo `P` e impreso dan un único error («no es una especialidad impresa») con los dos valores.
- Con el OK ya puesto, el Excel lleva igualmente las tres filas, como «Ya estaba» y con el valor actual en las dos columnas.

Como en la 00003, se ha compilado llamando a `alc.exe` con `/analyzer:` CodeCop (`tools/compile.ps1` no lo carga) y el paquete está en la raíz como `Galarux_GRX_Enteco_Fix_26.10.19.1.app` (ignorado por git).

## Resultado
- `Codeunit 50089 "GRX Main"`: procedimiento nuevo `MarcarOkComercialEnFabrica(Simular)` y el local `UsuarioDelComercial(Comercial)`, con sus etiquetas.
  - Error si la empresa no es Enteco_Manviel, si `P4TZ3012001` no es tipo `P` impreso o si no está en «En Fabrica».
  - Con el OK ya puesto: tres filas «Ya estaba» y no graba.
  - Sin OK: busca en `User Setup` el usuario con `"Salespers./Purch. Code"` = `"Enteco Comercial"`. Error si el comercial está vacío, si no lo tiene nadie o si lo tienen varios (con la lista de usuarios). Con uno solo, tres filas «Cambiado» (`Enteco Comercial Ok` No → Sí, `Enteco ID Comercial Ok` → usuario, `Enteco Fecha Comercial ok` → hoy) y, sin Simular, asigna los tres campos y `Modify(false)`.
  - Excel `GRX Fix OK Comercial <empresa> <modo>` y `Message` con cambiados y «Ya estaba».
- `Report 50025 "GRX Fix"`, `OnPreReport`: llama a `cuGrxFix.MarcarOkComercialEnFabrica(Simular)`. `RepararRecursoColaOT` sigue en la codeunit.
- `app.json`: versión 26.10.19.1 (dependencia de `Enteco` sin tocar, 26.9.2.1).
- Compilado con `alc` 17.0 y CodeCop: 0 errores y los mismos 6 warnings que la 26.10.14.2 (AA0215 nombres de fichero, AA0139 en `Fix_Imprimase`, AA0137 en `BorraCortePersonalizado`), ninguno nuevo.
- Pendiente (Daniel): publicar en PRE y en producción y ejecutar según las pruebas de aceptación 1 a 5.

## Historial
- 2026-10-19 Cowork: ficha creada.
- 2026-10-19 Claude Code: `MarcarOkComercialEnFabrica` en la `Codeunit 50089`, `Report 50025` apuntado a él, versión 26.10.19.1, compilado con CodeCop sin warnings nuevos; `.app` en la raíz. Estado `en pruebas`: falta publicar y probar en PRE y producción.
