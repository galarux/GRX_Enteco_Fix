---
id: 00007
titulo: "Modelo 353: poner el «Formato transferencia» MOD353 de Gestión en el diseño de 2026 (la sede rechaza el fichero con EMALREG «Tipo de registro desconocido»)"
repo: GRX_Enteco_Fix
rama: master
estado: en pruebas
modo: conversada
creado: 2026-11-04
modificado: 2026-11-26
proyecto: ENTECO Tareas sin proyecto
commits:
  - "2026-11-23 b7cb0f0 [00007] Formato MOD353 de Gestión al diseño DR353e26v12 de 2026 (CorregirFormatoMod353Gestion)"
  - "2026-11-26 11888d5 Versión 26.11.26.1: ficha 00007 (formato MOD353 de Gestión), a producción"
---

## Objetivo
Que Paula Arroyo saque de BC el 353 (consolidado del grupo de IVA, que presenta Enteco Gestión, la dominante) y la sede lo valide, como ya pasa con el 322 de las cuatro empresas. Hoy la sede rechaza el fichero de septiembre de 2026 entero. Causa probable: el «Formato transferencia» `MOD353` de Gestión está en un diseño anterior al de 2026. Hay que dejarlo en el diseño `DR353e26v12` sin tocar los importes ni la lógica de consolidación. Plazo real: la declaración de diciembre (el 353 de octubre, que se presenta en noviembre, ya debería salir bien).

## Contexto
El porqué está en la tarea del 04-11-2026 del proyecto «ENTECO Contabilidad Mejoras» de la bóveda. Sigue a las fichas 00005 y 00006 de este repo (322) y a la 00006 de MigracionBC.

- **Error de la sede** (captura de Paula, 04-11, hilo «Prueba envío txt BC modelo 353»), modelo 353 ejercicio 2026: `FRECH` «El fichero se rechazó. No se importó ningún registro» y, en la línea 2, `EMALREG` «Tipo de registro desconocido». La línea 2 es la página 01 (`<T35301000>`).
- **Fichero analizado**: `MOD353 (2).txt`, de Gestión (NIF B82770652, periodo 09/2026), guardado en `00 INBOX`. Tiene 1.846 caracteres en una sola línea; el correo declara 2.070 bytes para el adjunto: confirmar que es el mismo fichero (puede ser solo codificación).
- **Diseño oficial** (`DR353e26v12.xlsx`, en `MigracionBC/grx/utils/`): envoltorio `<T3530AAAAPP0000>` … `</T3530AAAAPP0000>` con `<AUX>` en 18-328 y contenido desde la 329. Página 01 de 1.700 posiciones (`<T35301000>` … `</T35301000>`, fin de registro en la 1689 de la página); página 02 de 400 (`<T35302000>`, con el IBAN y el SWIFT-BIC).
- **Lo que no cuadra con el fichero, medido sobre la página 01 (la 1 es la posición 329 del fichero):**
  1. Cabecera bien hasta la posición 120: `<T35301000>`, complementaria, tipo de declaración `I`, NIF, razón social (60), reservado (20), ejercicio 2026, periodo 09, nº de grupo `IVA0069/18`, régimen especial (119) `2`, IBAN (120) `2`.
  2. **Falta el campo de 1 posición de la 121** (An, «X o blanco»; el diseño le da una nota que no he podido leer). En el fichero, en la 121 ya está el NIF de la dominante, que debería empezar en la 122. Desde ahí todo queda desplazado una posición hacia la izquierda: el NIF de la dominante, su resultado, y cada uno de los 20 bloques de dependientes (47 posiciones cada uno, desde la 169).
  3. **La página 01 es más corta**: `</T35301000>` aparece en la posición 1489 de la página y no en la 1689; mide unas 1.500 posiciones en vez de 1.700. Coincide con el diseño antiguo de las otras empresas en el 322 (página 1 de 1.500), pero eso es una inferencia.
  4. **No hay página 02**: el fichero cierra con `</T35302026090000>` justo después de `</T35301000>`.
- **Importes del fichero**: aparecen los NIF B82770652 (dominante), B28296812 (Pharma), B28630796 (Manviel) y B10382638 (Extremadura), cada uno con su resultado. Con el desplazamiento de una posición no se puede leer con seguridad qué importe va con cada NIF ni el total; se compararán con el fichero nuevo (prueba 4), no con lo leído aquí.
- **El `Report 50110` (MigracionBC) está atado a los `Nº` de línea del formato `MOD353`**: la rutina `SetMod353TransferenceFormat` escribe el año y periodo en los Nº 4 y 5 (cabecera) y 24 y 25 (identificación), el cierre `</T3530AAAAPP0000>` en el Nº 150, y los importes en los Nº que indican los campos de Información de empresa de cada empresa: `Enteco Casilla Mod353` (casilla de cada empresa en el 353), `Enteco Casilla Total Mod353` (totales; para el Nº 136 y 138 suma además el saldo a compensar) y `Enteco Casilla Saldo Compensar`. **Esos «Nº» son números de línea, no posiciones.** Por eso un cambio de formato no puede renumerar las líneas sin cambiar también esa configuración.
- Enlace declaración ↔ fichero (casilla de la fila de `MOD353` → línea del formato con esa casilla): ver «ENTECO Contabilidad» en la bóveda y el Contexto de la ficha 00005. El 353 mezcla los dos mecanismos: casillas de la declaración y los Nº de Información de empresa.
- **Lo que no sabemos todavía** (hay que verlo antes de diseñar): cuántas líneas y con qué Nº, posición, longitud, tipo y casilla tiene hoy el formato `MOD353` de Gestión; qué Nº tienen configurados las cuatro empresas en Información de empresa; qué filas y casillas tiene la declaración `MOD353`; si Manviel, Extremadura y Pharma tienen también formato `MOD353` (solo lo presenta Gestión, pero el report suma las empresas por Información de empresa, no por su formato); y si la página 02 es obligatoria cuando el IBAN (120) vale `2`.

## Diseño
Sin objetos, tablas ni campos nuevos (convención del repo). **Se diseña de verdad cuando Daniel traiga el formato actual** (Parte 0); lo que sigue es el plan y la decisión abierta.

0. **Datos previos (Daniel, en producción `BC252`, empresa Gestión).** «Abrir en Excel» del «Formato transferencia» `MOD353` (todas las columnas); y del `Company Information` de Pharma, Manviel, Extremadura y Gestión: tipo de empresa 353, casilla 353, casilla total, casilla de saldo a compensar y cuenta de saldo a compensar. Y la declaración `MOD353` (filas y casillas) de Gestión. Se dejan en `00 INBOX`; Claude Code compara línea a línea con `DR353e26v12.xlsx`.
1. **Decisión abierta: parchear o reconstruir.**
   - **A (recomendada): parchear conservando los `Nº`.** Se insertan o ajustan las líneas que faltan (el campo de la 121, el resto de la página 01 hasta 1.700, la página 02) con `Nº` nuevos y libres (por encima del mayor existente), y se desplazan las posiciones de las líneas posteriores. Como el Report 50110 y la configuración de las empresas apuntan a `Nº`, no hay que tocar MigracionBC ni la configuración. El orden del fichero lo da la posición.
   - **B: reconstruir de cero** desde el diseño con una tabla en código. Más limpio, pero cambia los `Nº` y obliga a cambiar `Enteco Casilla *` de las cuatro empresas y los Nº fijos del report (4, 5, 24, 25, 136, 138, 150): MigracionBC y la configuración.
2. **Proceso** (con A): `Codeunit 50089 "GRX Main"`, procedimiento nuevo `CorregirFormatoMod353Gestion(Simular: Boolean)` y su llamada en `OnPreReport` del `Report 50025 "GRX Fix"` (como la 00006). Empresa localizada por NIF (`B82770652`), no por nombre. Valida todo antes de grabar, todo o nada: en Simular lista, por línea, lo que se inserta o se mueve; si algo no encaja con el diseño (una línea existente en una posición con otra longitud o tipo, o dos líneas solapadas), «No coincide» y no se toca nada. Excel de resultado con la copia de seguridad del formato antiguo, igual que en la 00006 (los helpers `IniciarResultado`, `AnadirResultado`, `ExportarResultado`).
3. **Valores fijos** de las líneas nuevas o corregidas, según el diseño: página 01 `<T35301000>`; régimen especial, IBAN y el campo de la 121 como indique su nota; `Value` vacío en las numéricas con casilla (las rellena el report); reservados en blanco.
4. **Página 02** (400 posiciones: indicador de complementaria, IBAN, SWIFT-BIC según el diseño, reservado, fin `</T35302000>`): se añade si la sede la exige. Hay que comprobar su obligatoriedad contra el diseño oficial y, si hay IBAN, contra la configuración de la domiciliación del grupo.
5. Si el `Report 50110` tiene que cambiar (por ejemplo, para emitir la página 02 o cortar el fichero según el periodo), ese cambio va en una ficha de MigracionBC (publisher Goom Spain, repo compartido), no aquí.
6. `app.json`: versión nueva; compilar con CodeCop sin warnings nuevos.

Qué NO se toca:
- Los importes ni la lógica de consolidación del 353 (`GetMod353Amount`, `GetAmountToCompensate353`, `Report 50111`).
- El formato ni la declaración `MOD322` de ninguna empresa.
- La declaración `MOD353` salvo que el análisis de la Parte 0 muestre casillas sin enganche.
- MigracionBC y el `Report 50110` salvo que la Parte 0 demuestre que hace falta (entonces, otra ficha).

## Casos
1. Gestión con el formato antiguo: Simular lista las líneas que se insertan o se mueven y la copia del formato actual; nada cambia.
2. Gestión ya corregida (segunda ejecución): no cambia nada, el Excel sale con «Ya estaba».
3. Una línea del formato actual no encaja con el diseño (longitud, tipo o solape): «No coincide», empresa sin tocar.
4. Empresa de NIF B82770652 no encontrada o repetida: error, nada cambia.
5. Periodo 01 (sin compensación de periodos anteriores) y periodo 02 o posterior (con campos de compensación): el fichero de cada uno es válido en la sede.
6. Autoliquidación complementaria: la `C` de la 12 y el justificante de la 1246 no se rompen con el cambio.

## Pruebas de aceptación
1. Compila con CodeCop sin warnings nuevos; publicar en producción (`BC252`) no pide sincronizar esquema.
2. Producción, Simular: Excel de Gestión sin «No coincide»; Daniel revisa con Claude Code las líneas que se insertan y se mueven antes de ejecutar.
3. Producción, sin Simular. El formato `MOD353` de Gestión: línea en la 121, `</T35301000>` en la posición 1689, página 02 si procede, y los `Nº` 4, 5, 24, 25, 136, 138 y 150 y los de Información de empresa intactos.
4. Paula genera el 353 de septiembre de 2026 (mismo periodo y mismos datos que el fichero actual): empieza por `<T35302026090000>`, la página 01 mide 1.700, el NIF de la dominante está en la 122 y cada bloque de dependientes empieza en la 169 + 47·k. Los importes por empresa y el total de la 1109 son coherentes con la declaración `MOD353` de BC (Daniel y Paula los cotejan con la pantalla). Daniel deja el fichero en `00 INBOX` y Claude Code lo compara antes de que Paula lo suba.
5. Paula lo valida en la sede, sin presentar: «No existen errores».

## Después
- **Antes de la declaración de diciembre**, con el 353 de diciembre: comprobar que no hay campos de último periodo (el diseño 2026 no los tiene) y repasar con Paula la exoneración del 390 y la prorrata, que son del 322.
- **Contestar a Paula en el hilo** con la fecha prevista (Daniel le dijo el 14-10 que daría fecha): ya tiene el fichero y el error; no hay que pedirle nada más salvo el visto bueno para probar.
- Daniel debe confirmar si el adjunto de 2.070 bytes es el mismo que el de 1.846 del INBOX.
- Si Pharma, Manviel o Extremadura tuvieran también formato `MOD353` antiguo, no hace falta corregirlo mientras solo presente Gestión; anotarlo.
- No cambia nada que vea el usuario salvo que el fichero sale bien: no hay que tocar el manual.

## Desviaciones del plan
Parte 0 leída por Claude Code directamente en BC252 con Chrome (sin Excel): formato `MOD353` de Gestión, Información de empresa de las cuatro empresas. No se ha leído la declaración `MOD353`: la columna Casilla del formato está vacía en todas las líneas, así que el 353 se engancha solo por Nº de línea (como decía la ficha) y no hace falta tocar la declaración.

- **El formato de Gestión no está en el diseño de 2026 en bastante más que el campo de la 121.** Es el diseño antiguo de 149 líneas (Nº 1 a 150, sin Nº 14; ejercicio 2024, cierre `</T35302024050000>` en la 1829). Diferencias con `DR353e26v12`: el campo de la 121 de la página 01 («Grupo sometido a normativa foral») ya existe como Nº 144, pero al final (1581); el IBAN y el SWIFT (Nº 142 y 143) están en la página 01 y en 2026 van en la página 02; el bloque de liquidación está en otro orden; falta el «pago a cuenta de gasolinas» [04]; el reservado final mide 188 y no 416; no hay página 02.
- **Decisión A (parchear conservando los Nº)**, como recomendaba la ficha. Casilla de cada empresa en Información de empresa: Gestión 30 (Dominante), Pharma 35, Manviel 40, Extremadura 45 (todas Hija salvo Gestión); total `134|136|138`; saldo a compensar de Gestión `135|145`, cuenta 47000003. Todos esos Nº se conservan, así que ni MigracionBC ni la configuración cambian. Nº 4, 5, 24, 25, 136, 138 y 150 del report siguen en su Nº.
- Mapa Nº → posición nueva (página 01 de 1.700 = 329..2028; página 02 de 400 = 2029..2428; cierre Nº 150 en 2429): Nº 29..133 (entidades) +1; 134→1437; 135→1454; 145→1471; 146→1488; 136→1505; 137→1522; nueva Nº 158 (gasolinas, num. 17)→1539; 138→1556; 139→1573; 140→1574; 141→1587; 147 (reservado, ahora 416)→1588; 148→2004; 149→2017; 144 (foral)→449; página 02: Nº 151 `<T` (2029), 152 `353`, 153 página `2`, 154 `000>`, 155 indicador, 142 IBAN→2041, 143 SWIFT→2075, 156 reservado 331 (2086), 157 `</T35302000>` (2417).
- La comprobación `PlanFormatoMod353` verifica que, con el plan, el fichero queda contiguo de la posición 1 a la 2446 (comprobado también fuera de BC).

## Resultado
Código hecho y compilado sin warnings: `CorregirFormatoMod353Gestion(Simular)` en la `Codeunit 50089 "GRX Main"` y su llamada en el `Report 50025 "GRX Fix"`; `app.json` a 26.11.23.1. Empresa por NIF B82770652; dos pasadas (valida, luego anota en el Excel y graba), todo o nada, cada línea «Cambiado / Ya estaba / Insertada / No coincide» con posición y longitud anterior y nueva (el Excel sirve de copia del formato antiguo). Sin probar: falta publicar y simular en producción.

Pendiente para la prueba: tras ejecutar, generar el 353 y comprobar con Paula que los importes salen en los Nº de siempre (en particular 135/145) y que los valores de las líneas nuevas (Nº 158 gasolinas) salen a ceros; si el report 50110 no rellena el IBAN/SWIFT ya movidos, revisar (otra ficha de MigracionBC).

## Historial
- 2026-11-04 Claude Code: ficha creada, tras analizar `MOD353 (2).txt` contra `DR353e26v12.xlsx` y el `Report 50110` de MigracionBC. Pendiente de los datos de la Parte 0 (export del formato `MOD353` de Gestión y de Información de empresa) para cerrar el diseño; decisión abierta A (parchear) o B (reconstruir).
- 2026-11-17 Claude Code: proyecto pasa a «ENTECO Tareas sin proyecto» (antes «ENTECO Contabilidad Mejoras»): una sola nota de tareas sin proyecto por entidad, decidido por Daniel.
- 2026-11-23 Claude Code: Parte 0 leída en BC252; decisión A; `CorregirFormatoMod353Gestion` hecho y compilado, versión 26.11.23.1. Estado `en pruebas`, falta publicar y simular.
- 2026-11-26 Claude Code: PR #1 fusionada en master; publicada la 26.11.26.1 en producción (BC252) con la skill accion-publicar-extension-bc, por el canal dev, después de Enteco 26.11.26.1 (antes 26.10.29.2); tag v26.11.26.1. Sigue `en pruebas`: faltan las pruebas 2 a 5 (Simular en producción, ejecutar, fichero de Paula y validación en la sede).
