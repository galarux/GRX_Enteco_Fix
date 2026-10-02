---
id: 00001
titulo: "Reparación de datos tras la ficha 00002 de MigracionBC: recurso finalizado, estado de cola y unidades de los componentes"
repo: GRX_Enteco_Fix
rama: master
estado: en pruebas
creado: 2026-10-02
modificado: 2026-10-02
decision: ENTECO DESARROLLO Recurso Finalizado Estado Cola OT
commits:
  - "2026-10-02 7681e9f [00001] Reports 59901 y 59902: recurso finalizado, estado de cola y unidad de componentes"
---

# Reparación de datos tras la ficha 00002 de MigracionBC: recurso finalizado, estado de cola y unidades de los componentes

> **Cambio de diseño 2026-10-02 (Daniel).** La extensión es OnPrem y la licencia tiene la numeración limitada: no se crean objetos nuevos. Los reports 59901 y 59902 que se hicieron primero se quitan y su lógica pasa a dos procedimientos públicos de la `Codeunit 50089 "GRX Main"`: `RepararRecursoColaOT(Simular: Boolean)` y `RepararUnidadComponentes(Simular: Boolean)`. El `Report 50025 "GRX Fix"` queda básico: comprueba el usuario (d.oton, a.millan), tiene una sola opción Simular (activada por defecto) y en `OnPreReport` llama al procedimiento del proceso en curso; para pasar de un proceso a otro se cambia la llamada y se vuelve a publicar. Los procedimientos se quedan en la codeunit aunque no los llame nadie y se borran de vez en cuando, cuando ya están en git. El Diseño de abajo ya está adaptado; las Desviaciones y el Resultado de la primera versión describen los reports, que dejan de existir.

## Objetivo
La ficha 00002 del repo MigracionBC corrige el código de la sincronización entre las OT de Planificación y la orden de producción estándar, pero no arregla los datos que ya quedaron mal. Esta ficha lo hace con dos reports de un solo uso: uno que carga desde un Excel el recurso finalizado y el estado de cola que tiene Oracle, y otro que completa la unidad de medida de las líneas de material y de los componentes que se quedaron sin ella. Los lanza Tecnología (Daniel), primero simulando, en Enteco_Pharma y en Enteco_Manviel, y se publican con los usuarios trabajando.

## Contexto
El porqué y la cronología están en la nota «ENTECO DESARROLLO Recurso Finalizado Estado Cola OT» de la bóveda. El código corregido está en la ficha `grx/desarrollos/00002_Recurso_Finalizado_Estado_Cola_OT.md` del repo hermano `../MigracionBC`.

**Requisito previo: la ficha 00002 de MigracionBC tiene que estar desplegada antes de ejecutar estos reports.** Sin ella, la siguiente modificación de cada OT en BC vuelve a dejar la orden estándar sin recurso y en «Sin asignar». Cumplido: está en producción desde el 01-10-2026 (versión 26.10.01.1 de `Enteco`).

### Recurso finalizado y estado de cola
- El recurso finalizado de las OT creadas en BC nunca ha llegado a BC. Oracle lo calcula en el trigger `PRODUCCION.T_AUS_PRD_MAQURUTA` y lo guarda en `FICHTECN.FIC_CABEOTRE.INDIFIMA`, pero esas OT no tienen fila en esa tabla, así que no se actualiza nada ni se llama al web service. El cambio en Oracle para que lo mande por el web service se ha pedido a Andrés Holguín y va aparte.
- El estado de cola de la orden estándar quedaba en «Sin asignar» cada vez que se modificaba la OT en BC, aunque Oracle la hubiera puesto en Asignada.
- Los datos buenos salen de Oracle con la consulta de solo lectura `grx/desarrollos/00001_consulta_oracle.sql` (adaptada del bloque PL/SQL de Andrés). Recalcula el recurso con la misma regla que el trigger y da el estado de cola: `1` si la OT está en `PRODUCCION.PRD_CABEOTRE`, `2` si tiene ruta, ya no está en la cola y no está cerrada, vacío si está cerrada.
- Ejecutada el 02-10-2026 sobre producción: 6.481 OT de BC (5.399 de Pharma y 1.082 de Manviel) en cola o con ruta. Validación de la regla: de las 5.924 OT migradas que ya traían recurso en BC, 5.909 coinciden con el recalculado; las 15 restantes son el orden de máquinas repetidas o cadenas antiguas incompletas. Contra la salida de Andrés del 01-10 (106 OT) coinciden todas salvo tres `CI` que pasan a `IC` (la consulta ordena por la ruta) y la 2026400177, que terminó la cortadora entre una ejecución y otra.
- El Excel de entrada es `reparacion_recurso_cola_OT.xlsx`, hoja `Reparar`, columnas `EMPRESA | NUMERO | RECURSO_FINALIZADO | ESTADO_COLA` (todo texto). Celda vacía = no tocar ese dato. 169 filas: Pharma 156 (87 recursos, 106 estados `1` y 1 estado `2`) y Manviel 13 (10 recursos, 7 estados `1`). La hoja `Resumen` explica los criterios y la hoja `Consulta Oracle` guarda la salida completa. Criterios ya aplicados al construir la hoja:
  - Recurso: solo OT de 2026 con el recurso vacío en BC (97). Fuera las 410 OT de 2006 a 2009 sin recurso (Oracle nunca lo calculó para ellas) y las 15 que ya tienen en BC un valor distinto (se respeta el de BC).
  - Estado de cola: solo OT abiertas en BC (114). Fuera las 38 cerradas en BC que siguen en la cola de Oracle.
- Precedente en este repo: el report 50133 «GRX Fix Import Planif» lee Excel con `Excel Buffer`, saca el código de empresa de Oracle del nombre de la empresa y restringe el uso por usuario.

### Unidades de medida de los componentes
- Con las OT creadas en BC, a veces el cierre falla porque un componente de la orden estándar (tabla 5407 `Prod. Order Component`) no tiene unidad de medida. El origen eran líneas de material de la estructura del pedido interno (tabla 50021) sin unidad, que heredaban la línea de OTT/OT (tabla 50051) y el componente. La ficha 00002 de MigracionBC rellena la unidad desde ahora y la completa al pasar a OT y al cerrar, pero los datos ya grabados siguen en blanco.
- No hay recuento de cuántos registros hay: lo dará la primera simulación.

## Diseño
Reglas comunes a los dos procesos:
- Sin tablas, extensiones de tabla ni campos nuevos: es la regla de esta extensión, que se publica con los usuarios trabajando.
- Uso restringido a Tecnología: la comprobación de usuario va en el `Report 50025`, con la misma lista que el report 50133.
- Opción **Simular** en la página de petición del `Report 50025`, activada por defecto, que se pasa al procedimiento: hace todo menos grabar.
- Al terminar, descarga un Excel de resultado (Excel Buffer temporal) con una fila por registro revisado: tabla, clave, campo, valor anterior, valor nuevo y resultado (`Cambiado`, `Ya estaba`, `No existe en BC`, `Error: …`). Un `Message` con los totales. No se guarda ningún log en tablas.
- Escritura directa sin disparar triggers (`Modify(false)`): el `OnModify` de la 50050 y de la 50051 resincroniza con la orden estándar por `fncCreaCabeceraOP`/`fncCreaTipoLineaOP`, que hacen `Commit` y aquí no hacen falta.
- Sin objetos nuevos: dos procedimientos públicos en la `Codeunit 50089 "GRX Main"`, con sus auxiliares locales (lectura del Excel, Excel de resultado) compartidos entre los dos, y la llamada desde el `Report 50025 "GRX Fix"`. Los reports 59901 y 59902 se borran.

### `RepararRecursoColaOT(Simular)` (antes report 59901)
1. Al empezar, el procedimiento pide el Excel (`UploadIntoStream`, `TempExcelBuffer.OpenBookStream(InStr, 'Reparar')`, `ReadSheet`).
2. Código de empresa de Oracle según `CompanyName()`, como en el report 50133: `Enteco_Pharma` → `10`, `Enteco_Manviel` → `05`; otra empresa → error.
3. Por cada fila desde la 2 cuya columna A sea el código de la empresa (aceptar también `5` por si Excel quita el cero):
   - OT Enteco: `"Enteco Production Order".Get(Tipo::OT, NUMERO)`. Orden estándar: `"Production Order"` con `SetRange("No.", NUMERO)` y `FindFirst`, en cualquier estado, igual que `fncCreaCabeceraOP`. Si no existe ninguna de las dos, resultado `No existe en BC` y siguiente fila.
   - `RECURSO_FINALIZADO` (columna C) informado: 50050 `"Recurso finalizado"` y 5405 `"Enteco Recurso finalizado"` := valor, solo si es distinto.
   - `ESTADO_COLA` (columna D): `1` → 50050 `"Estado Cola"` = `AsignadaCola` y 5405 `"Enteco Estado Cola"` = `Asignada`; `2` → `DesasignadaCola` y `Desasignada`; vacío → no se toca; otro valor → `Error` en esa fila.
   - Se escribe en las dos tablas a la vez, con `Modify(false)`.
4. Las filas de la otra empresa se ignoran sin listarlas.

### `RepararUnidadComponentes(Simular)` (antes report 59902)
Sin fichero de entrada. En la empresa en la que se lanza:
1. Tabla 50021 `"Enteco Linea Estructura"`: líneas con `"Tipo Linea"` = Producto y `"Unidad Medida"` vacía → `Item."Base Unit of Measure"`.
2. Tabla 50051 `"Enteco Production Order Line"`: líneas con `"Tipo Linea"` = Producto y `"Cod. Unidad Medida"` vacío → unidad base del producto.
3. Tabla 5407 `"Prod. Order Component"`: componentes de órdenes en estado Planned, Firm Planned o Released con `"Unit of Measure Code"` vacío e `"Item No."` informado → unidad base y `"Qty. per Unit of Measure"` := 1, por asignación directa sin `Validate`. Es el mismo criterio que `CompletarUnidadMedidaComponentes` de la Codeunit 50005 (ficha 00002): con la unidad en blanco el estándar ya aplicaba factor 1, así que no cambia ninguna cantidad. Las órdenes Finished no se tocan.
4. Producto sin unidad base: resultado `Error: producto sin unidad base` y no se toca.
5. Las líneas de máquina no se tocan.

Qué NO se toca: nada de MigracionBC, ni ningún objeto existente de esta extensión, ni Oracle.

## Casos
1. OT abierta y en cola con el recurso vacío en BC: Pharma 2026400095 → `IC` y Asignada en la OT y en la orden estándar.
2. OT abierta que ya salió de la cola: Pharma 2026400035 → solo estado Desasignada.
3. OT cerrada con recurso nuevo: Pharma 2026107669 → `Q`; el estado de cola no se toca.
4. OT cerrada en BC que sigue en la cola de Oracle: Pharma 2026400069 → `I`; el estado de cola no se toca.
5. OT con recurso en BC que la consulta no recalcula: Pharma 2026101253 tiene `I` en BC y no está en el Excel; sigue con `I`.
6. Fila de la otra empresa: se ignora.
7. OT del Excel que ya no existe en BC (anulada después de la consulta): `No existe en BC`.
8. Segunda ejecución con el mismo Excel: todas las filas `Ya estaba`.
9. Línea de material de una estructura sin unidad: queda con la unidad base.
10. Componente de una orden Released sin unidad: unidad base y factor 1, mismas cantidades.
11. Componente sin unidad de una orden Finished: no se toca.
12. Producto sin unidad base: se lista como error y no se toca.
13. Simular: nada cambia y el Excel de resultado es el mismo que al ejecutar.

## Pruebas de aceptación
En PRE (`BC25_DESARROLLO`), con la versión de `Enteco` que lleva la ficha 00002 de MigracionBC. Si PRE no tiene las OT del Excel de producción, se prepara un Excel con el mismo formato y OT de PRE que reproduzcan los casos (recurso vacío, en cola, fuera de cola, cerrada, de la otra empresa, inexistente).

1. `Report 50025` llamando a `RepararRecursoColaOT`, en Pharma y con Simular: el Excel de resultado lista las filas de Pharma (156 con el Excel de producción) y no cambia nada en la 50050 ni en la 5405.
2. Ejecutar sin Simular: 2026400095 queda con `IC` y Asignada en la OT y en la orden estándar; 2026400035 en Desasignada; 2026107669 con `Q` y el estado de cola sin cambios; 2026101253 sigue con `I`.
3. Repetir la ejecución: todo `Ya estaba`, 0 cambios.
4. En Manviel: solo trata sus 13 filas; 2026400006 queda con `IC` y Asignada.
5. Modificar en BC una OT reparada (p. ej. sus observaciones): la orden estándar conserva el recurso y el estado de cola.
6. `Report 50025` llamando a `RepararUnidadComponentes`, con Simular: lista estructuras, líneas y componentes sin unidad. Ejecutar: quedan con la unidad base; en los componentes `Quantity`, `Expected Quantity` y `Remaining Quantity` no cambian. Cerrar una OT que antes fallaba por un componente sin unidad: cierra.
7. Compilar con CodeCop sin warnings nuevos. Publicar en PRE con usuarios conectados: no pide sincronizar esquema ni expulsa a nadie.

## Después
- En producción: publicar la extensión, simular, revisar el Excel de resultado con Daniel y ejecutar, en Pharma y después en Manviel. Guardar los Excel de resultado como registro.
- Las OT que aún no han terminado ninguna máquina recibirán el recurso cuando Oracle lo mande por el web service. Si la reparación se repite antes de ese cambio, hay que volver a lanzar la consulta y regenerar el Excel.
- Pendiente de decidir: qué hacer con las 38 OT cerradas en BC que siguen en la cola de Oracle (posible limpieza de la cola en Oracle) y cuándo se borran estos procedimientos de la codeunit.
- No cambia nada que vea el usuario: no hay que tocar el manual.

## Desviaciones del plan
- `RepararRecursoColaOT`, OT que existe solo en una de las dos tablas (la 50050 o la 5405): la ficha solo dice qué hacer si no existe en ninguna. Se escribe en la que existe y la otra sale en el Excel como `No existe en BC`.
- `RepararRecursoColaOT`, `ESTADO_COLA` no válido: la fila de error se lista una vez, sin tabla; el recurso de esa misma fila se trata igual.
- `RepararUnidadComponentes`, producto que no existe (código vacío o borrado en la línea): resultado `Error: producto no existe`, que la ficha no contemplaba; no se toca.
- `RepararUnidadComponentes`: como solo revisa registros sin unidad, todas sus filas son `Cambiado` o `Error`; no hay `Ya estaba`. En una segunda ejecución el Excel sale vacío.
- El `Report 50025` ya no muestra «Proceso finalizado correctamente» en `OnPostReport`: el procedimiento saca su propio mensaje con los totales.
- La dependencia de `Enteco` sigue en 26.9.2.1: los campos que se usan ya existían y no hay símbolos de la 26.10.01.1 en `.alpackages`. El requisito de tener desplegada la ficha 00002 de MigracionBC no lo garantiza la extensión.

## Resultado
- `Codeunit 50089 "GRX Main"` (`src/GRX_Main.Codeunit.al`): procedimientos públicos `RepararRecursoColaOT(Simular)` y `RepararUnidadComponentes(Simular)`, según el diseño, con auxiliares locales compartidos (lectura del Excel, Excel de resultado con Tabla, Clave, Campo, Valor anterior, Valor nuevo y Resultado, y recuentos). Escriben con `Modify(false)` y acaban con un `Message` de totales. El nombre del Excel lleva el proceso, la empresa y «Simulación» o «Ejecución».
- `Report 50025 "GRX Fix"` (`src/GRX_Fix.Report.al`): comprobación de usuario (d.oton, a.millan), opción Simular activada por defecto y llamada a `RepararRecursoColaOT`. Para lanzar `RepararUnidadComponentes` hay que cambiar la llamada y volver a publicar.
- Los reports 59901 y 59902 se han borrado. Versión de la extensión 26.10.2.1. Sin objetos, tablas ni campos nuevos.
- Compila con CodeCop sin warnings nuevos (los que salen en `GRX_Main.Codeunit.al` y `GRX_Fix.Report.al` son anteriores: nombre de fichero y código antiguo de la codeunit).
- Sin probar en PRE: faltan las pruebas de aceptación 1 a 7.

## Historial
- 2026-10-02 Cowork: ficha creada con la consulta a Oracle (`00001_consulta_oracle.sql`) y el Excel de entrada analizados; los reports están por hacer.
- 2026-10-02 Claude Code: commit previo de limpieza del repo (plantilla, publish/, scripts/ → tools/, grx/utils/ ignorada); reports 59901 y 59902 escritos y compilados con CodeCop; pendiente probar en PRE.
- 2026-10-02 Cowork: `estado` pasa de `desarrollado` (no existe) a `en pruebas`; la lista de estados válidos queda en el `CLAUDE.md`. Revisadas las desviaciones: se aceptan tal cual.
- 2026-10-02 Cowork: cambio de diseño de Daniel (nota al principio): sin objetos nuevos; la lógica de los reports 59901 y 59902 pasa a la `Codeunit 50089` y la llama el `Report 50025`. Estado vuelve a `en desarrollo`. `CLAUDE.md` actualizado con la regla.
- 2026-10-02 Claude Code: lógica de los reports 59901 y 59902 pasada a `RepararRecursoColaOT` y `RepararUnidadComponentes` de la `Codeunit 50089`; reports borrados; `Report 50025` básico con Simular y llamada a `RepararRecursoColaOT`. Compilado con CodeCop; pendiente probar en PRE.
