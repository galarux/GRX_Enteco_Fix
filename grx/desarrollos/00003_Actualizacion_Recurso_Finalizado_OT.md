---
id: 00003
titulo: "Actualización del recurso finalizado de 129 OT (Pharma y Manviel) con la lista de Oracle de octubre de 2026, reutilizando RepararRecursoColaOT"
repo: GRX_Enteco_Fix
rama: master
estado: en pruebas
creado: 2026-10-14
modificado: 2026-10-14
proyecto: ENTECO Planificación Mejoras
commits:
  - "2026-10-14 e32b403 [00003] Report 50025 llama a RepararRecursoColaOT; versión 26.10.14.1"
  - "2026-10-14 98d5000 [00003] Ficha: commits al día"
  - "2026-10-14 5c35a08 [00003] Versión 26.10.14.2"
---

# Actualización del recurso finalizado de 129 OT (Pharma y Manviel) con la lista de Oracle de octubre de 2026, reutilizando RepararRecursoColaOT

## Objetivo
Poner en BC el recurso finalizado que Oracle tiene hoy para 129 OT creadas en BC (114 de Enteco_Pharma y 15 de Enteco_Manviel), en la OT de Planificación (tabla 50050) y en la orden de producción estándar (tabla 5405). Lo lanza Daniel (Tecnología) con el `Report 50025 "GRX Fix"`, primero simulando, en cada empresa. **No hay código nuevo:** el procedimiento `RepararRecursoColaOT(Simular)` de la ficha 00001 hace exactamente esto a partir de un Excel; solo hay que volver a apuntar el report a él y publicar.

## Contexto
El porqué está en la tarea del 14-10-2026 del proyecto «ENTECO Planificación Mejoras» de la bóveda; qué es el recurso finalizado y por qué Oracle no lo manda para las OT creadas en BC está en «ENTECO Planificación», sección «Recurso finalizado y estado de cola».

- La lista la trae Daniel el 14-10-2026 con tres columnas (`EMPRESA | NUMERO | INDIFIMA`): 129 OT, 114 con empresa `10` (Pharma) y 15 con `05` (Manviel). Reparto de valores: `C` 65, `IC` 44, `CI` 13, `I` 3, `L` 1, `LC` 1, `Q` 1, `IL` 1. La copia completa está al lado de esta ficha, en `00003_lista_ot.csv` (mismas columnas que la hoja `Reparar`, con `ESTADO_COLA` vacío).
- Comparada con el Excel de la ficha 00001 (`reparacion_recurso_cola_OT.xlsx`, ejecutado en producción el 02-10-2026): 86 OT traen el mismo valor (saldrán «Ya estaba» si nadie las ha tocado desde entonces), 32 no estaban en aquel Excel (5 de Manviel: 2025101225, 2026400028, 2026400032, 2026400036, 2026400042; 27 de Pharma, entre ellas 2026101029, 2026107351, 2026400147, 2026400185 a 2026400241) y 11 de Pharma tenían `IC` y ahora vienen `CI` (2026400095, 2026400099, 2026400115, 2026400137, 2026400141, 2026400143, 2026400159, 2026400161, 2026400163, 2026400165, 2026400169). La ficha 00001 ya avisó de esa diferencia de orden entre la consulta de Daniel (ordenada por la ruta) y lo que calcula Oracle.
- **Decisión de Daniel (14-10-2026): se sobrescribe con el valor de la lista**, también donde BC ya tiene otro valor; es lo que hace el procedimiento. Descartado un procedimiento nuevo con la lista en el código y descartado tocar solo las OT con el campo vacío.
- Lo que hay hoy en el repo y se reutiliza tal cual (ficha 00001): `Codeunit 50089 "GRX Main"`, `RepararRecursoColaOT(Simular)`: pide el Excel (`UploadIntoStream`), lee la hoja `Reparar` (`EMPRESA`, `NUMERO`, `RECURSO_FINALIZADO`, `ESTADO_COLA`, todo texto), trata solo las filas cuya empresa coincide con `CompanyName()` (`Enteco_Pharma` → `10`, `Enteco_Manviel` → `05`), escribe `"Recurso finalizado"` en la 50050 y `"Enteco Recurso finalizado"` en la 5405 (en cualquier estado de la orden) cuando el valor es distinto, no toca el estado de cola si `ESTADO_COLA` viene vacío, graba con `Modify(false)` y descarga un Excel de resultado (Tabla, Clave, Campo, Valor anterior, Valor nuevo, Resultado) más un `Message` con los totales.
- El `Report 50025` llama hoy a `RepararUnidadComponentes` (commit `d567790` del 02-10-2026). Versión publicada de la extensión: 26.10.2.1. Dependencia de `Enteco` 26.9.2.1, suficiente: los campos existen desde antes.
- Requisito previo cumplido: la ficha 00002 de MigracionBC (que conserva el recurso al modificar la OT) está en producción desde el 01-10-2026.

## Diseño
Sin objetos, tablas ni campos nuevos; sin cambios en la `Codeunit 50089`.

1. `Report 50025 "GRX Fix"` (`src/GRX_Fix.Report.al`), `OnPreReport`: la llamada pasa de `cuGrxFix.RepararUnidadComponentes(Simular)` a `cuGrxFix.RepararRecursoColaOT(Simular)`. Es la convención del repo: para lanzar otro proceso se cambia la llamada y se vuelve a publicar.
2. `app.json`: subir la versión (pauta del repo: `26.10.14.1`).
3. Compilar con `tools/compile.ps1` y CodeCop, sin warnings nuevos.
4. Excel de entrada `actualizar_recurso_finalizado_OT.xlsx`, generado por Cowork a partir de la lista: hoja `Reparar` con `EMPRESA | NUMERO | RECURSO_FINALIZADO | ESTADO_COLA` (todo texto, `ESTADO_COLA` vacío en todas las filas, 129 filas) y hoja `Resumen` con el origen y la comparación con el Excel del 02-10. Daniel lo guarda en `grx/utils/` (ignorada por git) como el de la 00001; `00003_lista_ot.csv` permite regenerarlo.
5. Ejecución (Daniel): publicar en producción (`BC252`) con los usuarios trabajando; en Pharma, `Report 50025` con Simular, revisar el Excel de resultado, ejecutar sin Simular; lo mismo en Manviel. Guardar los Excel de resultado.

Qué NO se toca: la `Codeunit 50089` y sus procedimientos, nada de MigracionBC, Oracle, el estado de cola de ninguna OT (la columna va vacía) y las OT que no están en la lista.

## Casos
1. OT con el mismo valor en BC (p. ej. Pharma 2026107669 `Q`, Manviel 2026400006 `IC`): «Ya estaba» en la 50050 y en la 5405.
2. OT con otro valor en BC (Pharma 2026400095: `IC` desde la 00001, `CI` en la lista): «Cambiado» a `CI` en las dos tablas.
3. OT nueva en la lista con el recurso vacío en BC (Pharma 2026400241 `I`, Manviel 2026400028 `L`): «Cambiado».
4. OT cerrada en BC (orden estándar Finished): se actualiza igual; el procedimiento no mira el estado.
5. OT de la lista que ya no existe en BC: «No existe en BC» y no se toca.
6. Filas de la otra empresa: se ignoran sin listarlas.
7. Estado de cola: no cambia en ninguna OT.
8. Segunda ejecución con el mismo Excel: todo «Ya estaba», 0 cambios.
9. Simular: nada cambia y el Excel de resultado es el mismo que al ejecutar.

## Pruebas de aceptación
1. Compila con CodeCop sin warnings nuevos. Publicar en PRE (`BC25_DESARROLLO`) con usuarios conectados: no pide sincronizar esquema. Simular en PRE con el Excel: las OT que PRE no tenga salen «No existe en BC»; ningún error.
2. Producción, Pharma, Simular: 114 filas tratadas y ningún error. Orientativo, si nadie ha tocado esas OT desde el 02-10 y todas existen: 76 «Cambiado» (38 OT × 2 tablas: 27 nuevas y 11 `IC`→`CI`) y 152 «Ya estaba» (76 OT × 2). Revisar con Daniel las filas «Cambiado» cuyo valor anterior no esté vacío.
3. Producción, Pharma, sin Simular: 2026400095 queda `CI` en la 50050 y en la 5405; 2026400241 queda `I`; 2026107669 sigue `Q`.
4. Repetir la ejecución en Pharma: todo «Ya estaba», 0 cambios.
5. Producción, Manviel: 15 filas tratadas; orientativo, 10 «Cambiado» (5 OT × 2) y 20 «Ya estaba». Ejecutar: 2026400028 queda `L`, 2026400006 sigue `IC`.
6. Modificar en BC una OT actualizada (p. ej. sus observaciones): la orden estándar conserva el recurso nuevo.

## Después
- El `Report 50025` queda apuntando a `RepararRecursoColaOT`; el siguiente proceso cambiará la llamada otra vez. `RepararUnidadComponentes` sigue en la codeunit por si hay que relanzarlo.
- Guardar los Excel de resultado (Pharma y Manviel) como registro, y anotar la ejecución en la tarea del proyecto «ENTECO Planificación Mejoras».
- Mientras el equipo de Oracle no cambie el trigger para enviar el recurso finalizado de las OT de BC por el web service, cada actualización se hará así: lista nueva, Excel nuevo, mismo procedimiento.
- No cambia nada que vea el usuario: no hay que tocar el manual.

## Desviaciones del plan
Ninguna en el código. `tools/compile.ps1` no carga CodeCop ni saca el `.app` con el nombre que se publica, así que se ha compilado llamando a `alc.exe` con `/analyzer:` CodeCop y el paquete se ha dejado en la raíz como `Galarux_GRX_Enteco_Fix_26.10.14.1.app` (ignorado por git).

## Resultado
- `Report 50025 "GRX Fix"`, `OnPreReport`: llama a `cuGrxFix.RepararRecursoColaOT(Simular)` en lugar de `RepararUnidadComponentes`. Sin cambios en la `Codeunit 50089`.
- `app.json`: versión 26.10.14.1 y, tras recompilar Daniel el mismo día, 26.10.14.2 (dependencia de `Enteco` sin tocar, 26.9.2.1).
- Compilado con `alc` 17.0 y CodeCop: 0 errores y los mismos 6 warnings que la 26.10.2.1 (AA0215 nombres de fichero, AA0139 en `Fix_Imprimase`, AA0137 en `BorraCortePersonalizado`), ninguno nuevo.
- Pendiente (Daniel): publicar en PRE y en producción y ejecutar con el Excel `actualizar_recurso_finalizado_OT.xlsx` según las pruebas de aceptación 1 a 6.

## Historial
- 2026-10-14 Cowork: ficha creada con la lista de 129 OT comparada con el Excel del 02-10 (`00003_lista_ot.csv` al lado); Excel de entrada generado y entregado a Daniel.
- 2026-10-14 Claude Code: `Report 50025` apuntado a `RepararRecursoColaOT`, versión 26.10.14.1, compilado con CodeCop sin warnings nuevos; `.app` en la raíz. Estado `en pruebas`: falta publicar y ejecutar en PRE y producción.
- 2026-10-14 Claude Code: Excel de entrada copiado a `grx/utils/`; commiteada la versión 26.10.14.2 que Daniel subió al recompilar.
