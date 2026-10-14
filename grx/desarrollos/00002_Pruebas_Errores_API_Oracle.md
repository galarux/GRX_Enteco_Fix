---
id: 00002
titulo: "Pruebas en PRE de la ficha 00004 de MigracionBC (errores del API de Oracle): escenarios automáticos con la configuración cambiada y restaurada"
repo: GRX_Enteco_Fix
rama: master
estado: propuesta
creado: 2026-10-08
modificado: 2026-10-08
decision: ENTECO DESARROLLO Errores API Oracle
commits: []
---

# Pruebas en PRE de la ficha 00004 de MigracionBC (errores del API de Oracle): escenarios automáticos con la configuración cambiada y restaurada

## Objetivo
Probar en PRE, de una sola pasada, los mensajes de error que la ficha 00004 de MigracionBC («Errores del API de Oracle: mostrar al usuario el message y el detail…») enseña cuando falla una llamada al API de Oracle, sin que Daniel tenga que cambiar y restaurar a mano las URLs de «Configuraciones comunes» ni preparar datos. El proceso lanza cada escenario, apunta el texto que devuelve BC frente al esperado y deja la configuración como estaba. Lo usa Daniel (Tecnología) una o dos veces antes de desplegar la 00004 en producción.

## Contexto
El porqué está en la nota «ENTECO DESARROLLO Errores API Oracle» de la bóveda. La ficha que se prueba es `grx/desarrollos/00004_Errores_API_Oracle_Message_Detail.md` del repo hermano `../MigracionBC` (rama `00003-correcciones-ott-api`, commit `3ab25be`), con sus pruebas de aceptación 1 a 7; aquí se automatizan las que no necesitan mirar la pantalla.

Lo que hay en la app `Enteco` (Goom Spain) y se usa sin tocarlo:
- `Codeunit 50004 "Enteco API Oracle"` (pública): `ObtenerChecksOrdenTrabajo(Empresa, NumOT, Anno): Text`, `GenerarSnapshotOT(Empresa, NumOT)` y `CheckEntecoObservacionesCliente(Empresa, Cliente)` lanzan `Error(GetLastErrorInfo())` cuando el API falla; `DescargarPdfOrdenTrabajo(Empresa, NumOT, Anno, Secciones, var TempBlob): Boolean` devuelve false y deja el texto en `GetLastPdfError()`. La `Codeunit 50008 "Enteco Oracle Http Client"` es `Internal` y no se puede llamar desde aquí.
- `Table 50044 "Enteco Configuraciones comunes"` (registro único, `Get()`): `"BaseURL API Oracle"` (Text[150]) y las rutas relativas a ella `"URL Check Impresion OT"`, `"URL Generar Snapshot OT"`, `"URL Impresion OT"` y `"URL Observaciones cliente"` (Text[200]). La URL final es `BaseURL` + `/` + ruta (`BuildUrl` de la 50008).
- `Table 50050 "Enteco Production Order"` (`Tipo`, `"No."`, `"Source Type"` = `PedidoInterno`, `"Source No."`) y `Table 50013 "Enteco Pedido Interno"`, campo 16 `"Diametro interior"` (Option `"0","70","76","95","150","152"`).
- `Company Information."Enteco Codigo Empresa Oracle"` (10 Pharma, 05 Manviel).
- API de test: `http://192.168.106.50/api_enteco` (swagger en `/docs`). Comprobado por Claude Code el 07-10-2026 contra él: `checks_pdf` de una OT inexistente responde HTTP 500 en texto plano «Internal Server Error»; `checks_pdf` sin un parámetro obligatorio da el 422 de FastAPI; una ruta sin `/api_enteco` devuelve la página 404 de nginx en HTML; una ruta inexistente del API devuelve el 404 de FastAPI `{"detail":"Not Found"}`.

Convenciones de esta extensión que se respetan (ver `CLAUDE.md`): sin objetos nuevos (todo en la `Codeunit 50089 "GRX Main"` y el `Report 50025 "GRX Fix"`), opción «Simular» activada por defecto, Excel de resultado al terminar, solo los usuarios de Tecnología que ya comprueba el report.

## Diseño
Sin objetos ni campos nuevos. Se tocan la `Codeunit 50089 "GRX Main"` y el `Report 50025 "GRX Fix"`.

### Report 50025 "GRX Fix"
1. Opción nueva en la página de petición: «OT para el escenario 2» (`Code[20]`, vacía por defecto), con tooltip «OT de pedido interno cuyo pedido se pone temporalmente con diámetro interior 0».
2. `OnPreReport` llama a `cuGrxFix.PruebasErroresApiOracle(Simular, OTEscenario2)` en lugar del proceso anterior (es la convención: se cambia la llamada y se publica).

### Codeunit 50089 "GRX Main": `procedure PruebasErroresApiOracle(Simular: Boolean; OTEscenario2: Code[20])`
3. **Solo en PRE.** Antes de nada, error claro y sin tocar nada si no se cumplen las dos cosas: la instancia es `BC25_DESARROLLO` (`Active Session` de la sesión actual, `"Server Instance Name"`) y `"BaseURL API Oracle"` contiene `192.168.106.50`. Así, aunque la Fix esté publicada en producción, el proceso no hace nada allí.
4. **Guarda la configuración.** Lee el registro de la 50044 y guarda en variables los cinco campos de URL. Al terminar cada escenario los vuelve a poner con `Modify(false)`, también si el escenario falla. No hace `Commit` para la configuración: las llamadas al API las hace BC en la misma transacción y ven el cambio; si algo revienta a mitad, la transacción se deshace y la configuración queda como estaba.
5. **Cada llamada dentro de un `[TryFunction]` local** (sin escrituras en base de datos dentro), y el texto obtenido es `GetLastErrorText()`. Si la llamada no falla, el texto obtenido es «(sin error)».
6. **Escenarios.** Empresa = `Company Information."Enteco Codigo Empresa Oracle"`; OT inventada = `2026999999`.

| Nº | Qué se cambia temporalmente | Llamada | Texto esperado |
| --- | --- | --- | --- |
| 1 | Nada | `ObtenerChecksOrdenTrabajo(Empresa, '2026999999', '2026')` | «El API de Oracle no ha respondido correctamente (HTTP 500 Internal Server Error).» |
| 2 | `"Diametro interior"` del pedido interno de `OTEscenario2` a `"0"` (ver punto 7) | `GenerarSnapshotOT(Empresa, OTEscenario2)` | Contiene «Causa:», ningún «<» y al menos un salto de línea (dos párrafos) |
| 3 | `"URL Check Impresion OT"` = `ficha_tecnica/pdf` | `ObtenerChecksOrdenTrabajo(Empresa, '2026999999', '2026')` | «producto: Field required» |
| 4 | `"BaseURL API Oracle"` = `http://192.168.106.51/api_enteco` | `ObtenerChecksOrdenTrabajo(Empresa, '2026999999', '2026')` | «No se ha podido conectar con el API de Oracle. Compruebe la red o la URL configurada.» |
| 5 | `"BaseURL API Oracle"` = `http://192.168.106.50/` | `ObtenerChecksOrdenTrabajo(Empresa, '2026999999', '2026')` | «El API de Oracle no ha respondido correctamente (HTTP 404 Not Found).» |
| 6 | `"URL Impresion OT"` = la actual + `_x` | `DescargarPdfOrdenTrabajo(Empresa, '2026999999', '2026', 'X', TempBlob)`; texto obtenido = `GetLastPdfError()` | Devuelve false y el texto es «Not Found» |
| 7 | `"BaseURL API Oracle"` = `http://192.168.106.51/api_enteco` | `CheckEntecoObservacionesCliente(Empresa, <primer cliente de la tabla Customer>)` | El mismo texto del escenario 4 |

7. **Escenario 2**, el último en ejecutarse. Solo si `OTEscenario2` no está vacía: `Enteco Production Order` con `Tipo = OT` y ese número, `"Source Type" = PedidoInterno`; si no existe o no es de pedido interno, el escenario sale «No ejecutado» con el motivo. Guarda el pedido y su diámetro interior en `IsolatedStorage` (ámbito empresa, clave propia del proceso), lo pone a `"0"` con `Modify(false)` y hace `Commit`, porque el API lee el pedido desde Oracle por las vistas de SQL Server y no vería un cambio sin confirmar. Lanza el snapshot, vuelve a poner el diámetro original con `Modify(false)`, hace `Commit` y borra la clave de `IsolatedStorage`. Al empezar cualquier ejecución (también en Simular, solo para avisarlo), si la clave existe es que una ejecución anterior se cortó entre los dos `Commit`: restaura ese diámetro primero y lo anota en el Excel. En el Excel van también el pedido, el diámetro original y si se restauró. Si el API responde algo que no es el error de diámetros (por ejemplo «no se encontró la orden de trabajo», porque el Oracle de test no tiene esa OT), el resultado es «No concluyente».
8. **Comparación.** Escenarios 1, 3, 4, 5, 6 y 7: «Coincide» si el texto obtenido es igual al esperado (tras `Trim`); escenario 3, si lo contiene. Escenario 2: la regla de la tabla. Si no, «No coincide».
9. **Simular** (por defecto): comprueba lo del punto 3, busca la OT y el pedido del escenario 2 y genera el Excel con cada escenario, lo que cambiaría y el texto esperado, sin modificar nada ni llamar al API.
10. **Excel de resultado** con los helpers que ya hay (`IniciarResultado`, `AnadirResultado`, `ExportarResultado`; si hace falta, otra cabecera): columnas Escenario, Qué se cambia, Llamada, Texto esperado, Texto obtenido, Resultado. Última fila: «Configuración restaurada» Sí/No, comparando los cinco campos con los guardados al empezar. Mensaje final con el número de escenarios que coinciden, no coinciden y no se ejecutaron.
11. Escenario 4 y 7: la conexión a un host que no existe tarda hasta que el sistema operativo la da por perdida (unos 20 s cada una; la 50008 no fija `Timeout`, así que como mucho los 100 s por defecto de `HttpClient`). Ventana de progreso con el escenario en curso.

Qué NO se toca: la app `Enteco` (ni sus codeunits, ni la 50044 más allá de los cambios temporales, ni el API); los procesos anteriores de la `Codeunit 50089`; la comprobación de usuarios del report.

## Casos
1. Ejecutado en producción o con la `BaseURL` del API de producción: error «Este proceso solo se puede ejecutar en PRE con el API de test» y no cambia nada.
2. Sin `OTEscenario2`: se ejecutan los escenarios 1 y 3 a 7; el 2 sale «No ejecutado: sin OT».
3. `OTEscenario2` no existe o no es de pedido interno: el 2 sale «No ejecutado» con el motivo.
4. Un escenario que no falla (por ejemplo, si un día el API devuelve 200 en el 1): «(sin error)» y «No coincide».
5. Error inesperado a mitad (no capturado): la transacción se deshace y la configuración queda como estaba. Si ya se había confirmado el diámetro 0 del escenario 2, la siguiente ejecución lo restaura desde `IsolatedStorage` antes de nada (punto 7).
6. Usuario que no es de Tecnología: el error de permiso que ya tiene el report.

## Pruebas de aceptación
En PRE (`BC25_DESARROLLO`), con la ficha 00004 de MigracionBC publicada y `BaseURL API Oracle` = `http://192.168.106.50/api_enteco`. Las lanza Daniel desde «GRX Fix DOR».
1. **Simular**, con una OT de pedido interno en «OT para el escenario 2»: Excel con los siete escenarios, lo que se cambiaría y el texto esperado. Comprobar a mano que «Configuraciones comunes» y el diámetro del pedido no han cambiado.
2. **Ejecutar** con la misma OT: escenarios 1, 3, 4, 5, 6 y 7 «Coincide»; el 2 «Coincide» o «No concluyente» (si el Oracle de test no tiene esa OT); última fila «Configuración restaurada: Sí». Comprobar a mano «Configuraciones comunes» y que el pedido tiene otra vez su diámetro.
3. **Protección:** poner a mano `BaseURL API Oracle` = `http://192.168.10.50/api_enteco` (producción) y lanzar en Simular: error del caso 1 sin tocar nada. Restaurar la URL.
4. Compilación con `tools/compile.ps1` y CodeCop, sin warnings nuevos.

Lo que este proceso no prueba y Daniel sigue mirando a mano (pruebas 1 y 7 de la ficha 00004): cómo pinta el diálogo de error los saltos de línea y el apartado de detalles (`ErrorInfo.DetailedMessage` no se puede leer al capturar el error), y la página «Error Messages» de las observaciones pendientes de cliente.

## Después
- Publicar solo en PRE; no hace falta llevar este proceso a producción (si se publica allí, el punto 3 lo deja inerte).
- Con los resultados, Daniel termina las pruebas de la ficha 00004 de MigracionBC y Claude Code la deja al día allí.
- Cuando la 00004 esté desplegada, el proceso queda inerte, como los demás de la extensión; la llamada del report se cambia en el siguiente proceso.

## Desviaciones del plan
(Claude Code)

## Resultado
(Claude Code)

## Historial
- 2026-10-08 Cowork: ficha creada.
