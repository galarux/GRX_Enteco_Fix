---
id: 00005
titulo: "Modelo 322: corregir la configuración MOD322 (declaración de IVA y «Formato transferencia») al diseño de 2026 en Pharma, Manviel y Extremadura"
repo: GRX_Enteco_Fix
rama: master
estado: propuesta
creado: 2026-10-29
modificado: 2026-10-29
proyecto: ENTECO Contabilidad Mejoras
commits: []
---

# Modelo 322: corregir la configuración MOD322 (declaración de IVA y «Formato transferencia») al diseño de 2026 en Pharma, Manviel y Extremadura

## Objetivo
Que Paula Arroyo (Departamento Financiero) saque el fichero del modelo 322 directamente de BC y la sede de la AEAT lo valide sin tocarlo a mano. El código ya está bien (ficha 00006 de MigracionBC, en producción); lo que falla es la configuración de datos `MOD322` de cada empresa, que sigue con casillas del diseño anterior. Un proceso del `Report 50025 "GRX Fix"` aplica los mismos cambios en las tres empresas de una vez, primero simulando, para no equivocarse a mano empresa por empresa.

## Contexto
El porqué está en la tarea del 29-10-2026 del proyecto «ENTECO Contabilidad Mejoras» de la bóveda; cómo funcionan los modelos 322/353 en BC, en «ENTECO Contabilidad», sección «Modelos de IVA del grupo de entidades (322 y 353)». La ficha 00006 de MigracionBC (`grx/desarrollos/00006_Modelo_322_Paginas_Ultimo_Periodo.md`) describe en su Diseño, «Parte 2», estos mismos cambios de configuración; aquí se automatizan.

Hecho del 28-10-2026: Paula genera el 322 de septiembre de 2026 de Enteco_Pharma (`MOD322 (19).txt`) y la sede lo rechaza. Comparado posición a posición con el fichero de junio que la sede validó el 15-10 (`MOD322_2026_06_prueba3.txt`, en `grx/utils/` de MigracionBC): la estructura ya está bien (sin páginas 3 y 4, cierre `</T32202026090000>`), pero:

| Posición | Casilla | Sale | Debería |
| --- | --- | --- | --- |
| 733 / 755 | [150] / [152] | 1.780.239,18 / 373.850,28 (base y cuota del 21 %) | 0 |
| 828 | [13] tipo | 21,00 | 0 |
| 928 / 945 / 950 | [18] / [19] / [20] | 0 / 0 / 0 | 1.780.239,18 / 21,00 / 373.850,28 |
| 2180 | [65] | 198.011,28 | 310.836,70 (= [63]) |
| 2299 | [70] | 198.011,28 | 310.836,70 (= [63]) |
| 1948 | zona reservada de la página 1 | 310.836,70 | blancos |

Con esas cuatro correcciones a mano, el fichero de septiembre (`00 INBOX/MOD322_2026_09_Pharma_corregido.txt` del OneDrive de Daniel, 4.446 caracteres) solo difiere del validado de junio en el periodo y los importes del mes; [38] 549.439,77 − [62] 238.603,07 = [63] 310.836,70.

Cómo funciona el enlace (`Report 50110` de MigracionBC, copia del estándar español):
- Cada fila de la declaración de IVA (`VAT Statement Line`, nombre `MOD322`) con `Box` (Casilla) relleno vuelca su importe en las líneas del «Formato transferencia» (`AEAT Transference Format`, tabla 10704, `"VAT Statement Name"` = `MOD322`) que tienen esa misma `Box`.
- Al terminar, el report guarda el `Value` calculado en la tabla real (por `Box`). Una línea numérica cuya `Box` no coincide con ninguna fila **conserva el `Value` de la última vez que coincidió**: por eso [65] y [70] repiten 198.011,28 desde junio. Si el `Value` está vacío, sale a ceros.
- El fichero se rellena con blancos donde no hay línea.

Configuración vista en Pharma el 29-10-2026 (capturas de Daniel):

Declaración `MOD322`, filas con casilla del 21 %:
- `Nº línea` 100000 «Resto de operaciones en régimen general Cuota- 21%», Filas a totalizar `1000..1006`, Box `152`.
- `Nº línea` 110000 «… Base imponible- 21%», `B1000..B1006`, Box `150`.
- La fila 780000 «Resultado del Régimen General» (`1000..2080`) tiene Box `63`. No hay filas con Box 13, 18, 19, 20, 65 ni 70.

Formato transferencia `MOD322` (Nº / Posición / Longitud / Tipo / Box / Value):

| Nº | Posición | Long. | Box | Value | Descripción |
| --- | --- | --- | --- | --- | --- |
| 46 | 733 | 17 | 150 | 00000000178023918 | [150] |
| 114 | 750 | 5 | 151 | 00000 | Tipo % [151] |
| 48 | 755 | 17 | 152 | 00000000037385028 | Cuota [152] |
| 47 | 828 | 5 | 13 | 02100 | Tipo % [13] |
| 55 | 928 | 17 | 18 | 0…0 | [18] |
| 59 | 945 | 5 | 19 | 00000 | Tipo % [19] |
| 58 | 950 | 17 | 20 | 0…0 | Cuota [20] |
| 125 | 2158 | 17 | 63 | 00000000031083670 | [63] |
| 127 | 2180 | 17 | 65 | 00000000019801128 | [65] |
| 131 | 1948 | 17 | 63 | 00000000031083670 | [68] del diseño anterior |
| 256 | 2248 | 17 | 63 | 00000000031083670 | [68] |
| 133 | 2299 | 17 | 70 | 00000000019801128 | [70] |

Todas numéricas, «Parte entera y decimal». Además, según la 00006, la marca de complementaria está en la posición 2067 y «Sin actividad» en la 2081 (posiciones del diseño anterior, en zona reservada de la página 1); en el diseño de 2026 (`DR322e26v11.xlsx`) son la 2452 y la 2466 de la página 2. Hoy van vacías.

Los números de línea (`Nº`) pueden ser distintos en Manviel y Extremadura: por eso el proceso localiza cada línea por su `Posición` (formato) o por su `Box` (declaración), nunca por `Nº`.

## Diseño
Sin objetos, tablas ni campos nuevos (convención del repo).

1. `Codeunit 50089 "GRX Main"`, procedimiento nuevo `CorregirConfiguracionMod322(Simular: Boolean)`.
   1. Recorre las empresas `Enteco_Pharma`, `Enteco_Manviel` y `Enteco_Extremadura` con `ChangeCompany` en `VAT Statement Line` y `AEAT Transference Format`. Si una empresa no existe (`Company.Get`), una fila «Empresa no existe» y sigue con la siguiente.
   2. **Por empresa, primero valida todo y luego graba, todo o nada.** Para cada cambio de la lista de abajo clasifica la línea como «A cambiar» (está en el estado de origen), «Ya estaba» (está en el estado destino) o «No coincide» (cualquier otra cosa: no existe, hay varias, o tiene otra casilla, longitud o valor). Si en una empresa hay un solo «No coincide», no graba nada en esa empresa y lo dice en el Excel con los valores actuales. Si no, y no es Simular, aplica los «A cambiar» con `Modify(false)` / `Delete(false)`.
   3. Cambios en la **declaración** (`VAT Statement Line`, `"Statement Name"` = `MOD322`, cualquier plantilla; localizar por `Box`, debe haber exactamente una):
      - D1: la fila con Box `152` → Box `20`. Destino: una fila con Box `20` y ninguna con `152`.
      - D2: la fila con Box `150` → Box `18`. Destino: una fila con Box `18` y ninguna con `150`.
   4. Cambios en el **formato** (`AEAT Transference Format`, `"VAT Statement Name"` = `MOD322`; localizar por `Position`, debe haber exactamente una línea; comprobar `Length` y `Type` = Numérico salvo F10/F11):
      - F1: posición 733 (long. 17, Box `150`) → Box vacía y Value vacío.
      - F2: posición 755 (long. 17, Box `152`) → Box vacía y Value vacío.
      - F3: posición 828 (long. 5) → Value `00000`, tenga el valor que tenga («Ya estaba» si ya es `00000`). La Box no se toca.
      - F4: posición 945 (long. 5) → Value `02100`, tenga el valor que tenga («Ya estaba» si ya es `02100`). La Box no se toca.
      - F5: posición 928 (long. 17): solo comprobar Box `18`. F6: posición 950 (long. 17): solo comprobar Box `20`. Si no, «No coincide».
      - F7: posición 2180 (long. 17, Box `65`) → Box `63` y Value vacío.
      - F8: posición 2299 (long. 17, Box `70`) → Box `63` y Value vacío.
      - F9: posición 1948 (long. 17) → borrar la línea. Destino: no hay línea en la 1948.
      - F10: posición 2067 (long. 1) → `Position` 2452. F11: posición 2081 (long. 1) → `Position` 2466. Antes de moverlas, comprobar que ninguna otra línea de `MOD322` ocupa la posición destino (`Position <= destino < Position + Length`); si alguna la ocupa, «No coincide».
   5. Resultado con los helpers que ya existen (`IniciarResultado`, `AnadirResultado`, `ExportarResultado`): una fila por cambio y empresa. Tabla (`VAT Statement Line` / `AEAT Transference Format`), Clave (`empresa · posición NNNN (Nº n)` o `empresa · Nº línea n`, con la descripción de la línea), Campo, Valor anterior, Valor nuevo, Resultado. Al final, `Message` con, por empresa, cambiados / ya estaba / no coincide.
2. `Report 50025 "GRX Fix"`, `OnPreReport`: la llamada pasa de `MarcarOkComercialEnFabrica(Simular)` a `CorregirConfiguracionMod322(Simular)`. La 00004 está finalizada.
3. `app.json`: versión `26.10.29.1`. Compilar con CodeCop sin warnings nuevos.

Qué NO se toca:
- MigracionBC, el `Report 50110` y la configuración `MOD353`.
- Las filas del 4 % y el 10 % (Box 12/14 y 153/155) ni las posiciones 750, 811, 833, 889, 906, 911: ver Después.
- Los valores de diciembre (posiciones 461 a 463): los pone el `Report 50110`.
- Ninguna otra línea de la declaración ni del formato.

## Casos
1. Pharma con la configuración de arriba: 11 cambios «A cambiar» (D1, D2, F1-F4, F7-F11) y 2 comprobaciones correctas (F5, F6).
2. Segunda ejecución en cualquier empresa: todo «Ya estaba», 0 cambios.
3. Empresa con una línea distinta (otra casilla, otro valor en la 828, una línea que ya ocupa la 2452…): esa empresa entera «No coincide» y sin cambios; las demás siguen.
4. Empresa que no existe en la base de datos: fila «Empresa no existe».
5. Empresa donde Daniel ya corrigió algo a mano: lo corregido sale «Ya estaba» y el resto se aplica.

## Pruebas de aceptación
1. Compila con CodeCop sin warnings nuevos; publicar en producción (`BC252`) con usuarios conectados no pide sincronizar esquema.
2. Producción, Simular: Excel con las tres empresas. En Pharma, los 11 cambios y las 2 comprobaciones del caso 1 con los valores de la tabla de Contexto. Ninguna empresa en «No coincide»; si alguna sale, se para y se revisa con Daniel antes de ejecutar.
3. Producción, sin Simular: abrir en Pharma la declaración `MOD322` (filas 100000 y 110000 con Box 20 y 18) y el Formato transferencia filtrado por las posiciones de la tabla (sin línea en la 1948; 733 y 755 sin casilla; 2180 y 2299 con casilla 63; líneas en la 2452 y 2466; ninguna en la 2067 ni en la 2081).
4. Enteco_Pharma, «Enteco Generar Txt» del 322 de septiembre de 2026: el fichero es **idéntico** a `00 INBOX/MOD322_2026_09_Pharma_corregido.txt` (4.446 caracteres). Paula lo valida en la sede: «No existen errores».
5. Paula genera el 322 de septiembre de Manviel y Extremadura y la sede los valida sin errores.
6. Repetir el proceso: todo «Ya estaba».

## Después
- **Plazo:** el 322 de septiembre se presenta hasta el 30-10-2026. Si el proceso no llega a tiempo, Paula presenta el de Pharma con el fichero corregido a mano de `00 INBOX`.
- **4 % y 10 %** (pendiente de validar el primer mes con ventas a esos tipos): el diseño del 322 ordena el régimen general por tipo, [150] 0 %, [165] 2 %, [12]-[14] 4 %, [153] 5 %, [15]-[17] 10 %, [18]-[20] 21 % (deducido del orden; el diseño no lo dice de forma explícita). Hoy el 10 % va a las casillas 12/14 y el 4 % a la 153/155. Lo correcto sería 10 % → 15/17 y 4 % → 12/14, con los tipos 01000 en la 906 y 00400 en la 828 solo cuando haya base. Ampliación de esta ficha o ficha nueva cuando aparezca el caso.
- **Diciembre**: valores de las posiciones 461 a 463 por empresa, pendiente en la ficha 00006 de MigracionBC.
- **Modelo 353**: sigue sin fichero ni error; pedírselo a Paula.
- El `Report 50025` queda apuntando a `CorregirConfiguracionMod322`.
- No cambia nada que vea el usuario salvo que el fichero sale bien: no hay que tocar el manual.

## Desviaciones del plan
(Claude Code) Qué se hizo distinto de lo previsto y por qué.

## Resultado
(Claude Code) Qué quedó hecho, objetos finales, cómo se probó.

## Historial
- 2026-10-29 Cowork: ficha creada.
