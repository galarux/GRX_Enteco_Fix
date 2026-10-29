---
id: 00006
titulo: "Modelo 322: copiar el «Formato transferencia» MOD322 de Pharma (ya corregido, diseño de 2026) a Manviel, Extremadura y Gestión"
repo: GRX_Enteco_Fix
rama: master
estado: en pruebas
creado: 2026-10-29
modificado: 2026-10-29
proyecto: ENTECO Contabilidad Mejoras
commits:
  - "2026-10-29 45dcdf2 [00006] CopiarFormatoMod322DesdePharma en la Codeunit 50089; Report 50025 lo llama; versión 26.10.29.2; fichas 00006 (nueva) y 00005 (Historial)"
---

# Modelo 322: copiar el «Formato transferencia» MOD322 de Pharma (ya corregido, diseño de 2026) a Manviel, Extremadura y Gestión

## Objetivo
Que Paula Arroyo saque de BC el 322 de septiembre de 2026 de Enteco Manviel, Enteco Extremadura y Enteco Gestión y la sede lo valide, como ya hace con Pharma desde el 29-10. Su «Formato transferencia» `MOD322` está en un diseño anterior al de 2026 y la sede lo rechaza. En vez de corregirlo línea a línea, se copia el de Pharma, que ya está bien, y se dejan los datos de identificación de cada empresa. Plazo: el 322 de septiembre se presenta hasta el 30-10-2026.

## Contexto
El porqué está en la tarea del 29-10-2026 del proyecto «ENTECO Contabilidad Mejoras» de la bóveda. Sigue a la ficha 00005 de este repo.

- **Pharma está bien.** La 00005 se ejecutó en producción en Enteco_Pharma el 29-10 y Paula confirma que el 322 de septiembre ya le funciona. Su formato `MOD322` es el del diseño de 2026 (`DR322e26v11.xlsx`): página 1 en 329-2128, página 2 en 2129-4428, páginas 3 y 4 que el `Report 50110` de MigracionBC solo deja en diciembre, cierre en 8034 (o tras la página 2).
- **Las otras tres empresas tienen otro formato.** La simulación de la 00005 dio «No coincide» en Manviel y Extremadura: no tienen líneas en las posiciones 733, 755, 828, 928, 945, 950, 2180 ni 2299, y la línea Nº 147 empieza en la 2172 con 1.645 posiciones. Los ficheros que generó Paula el 29-10 (`EM_`, `EE_`, `EG_MOD322 (21).txt`, 3.846 caracteres) lo confirman: página 1 de 1.500 (329-1828), página 2 de 2.000 (1829-3828), cierre en 3829. Es un diseño anterior, incompatible con el de 2026.
- **Gestión es la cuarta empresa** (no estaba en la 00005). Es la dominante del grupo de IVA y presenta también el 353 consolidado; el 353 no entra aquí.
- **Identificación de cada empresa en el fichero** (igual en los dos diseños, página 1):

| Empresa | NIF (342, 9) | Razón social (351, 60) | Dominante/Dependiente (447, 1) | NIF dominante (448, 9) |
| --- | --- | --- | --- | --- |
| Pharma (origen) | B28296812 | ENTECO PHARMA SL | P | B82770652 |
| Manviel | B28630796 | ENTECO MANVIEL S.L. | P | B82770652 |
| Extremadura | B10382638 | ENTECO EXTREMADURA S.L. | P | B82770652 |
| Gestión | B82770652 | ENTECO GESTIÓN S.L. (en el fichero sale `GESTIàN`: BC escribe la `Ó` con otra página de códigos) | D | B82770652 |

  El nº de grupo (`IVA0069/18`, posición 437) es el mismo para todas.
- **El `Report 50110` usa los `Nº` de línea de Pharma**: `Get('MOD322', n)` sobre los Nº 4 y 5 (año y periodo de la cabecera), 20 y 21 (año y periodo de identificación), 107 y 109 (posiciones 463 y 462) y 254 (cierre). En el formato antiguo esos Nº no existen o son otras líneas (el cierre del fichero antiguo no es el 254). Por eso la copia **conserva el `Nº`** de cada línea de Pharma.
- Cómo engancha la declaración con el formato (por `Box`) y por qué una línea sin enganche conserva su último `Value`: ver Contexto de la ficha 00005 y «ENTECO Contabilidad» en la bóveda.
- Las declaraciones `MOD322` de Manviel y Extremadura tienen las filas 100000/110000 con casillas 152/150, como tenía Pharma (simulación de la 00005). Las de Gestión no se han visto.

## Diseño
Sin objetos, tablas ni campos nuevos (convención del repo).

1. `Codeunit 50089 "GRX Main"`, procedimiento nuevo `CopiarFormatoMod322DesdePharma(Simular: Boolean)`.
   1. **Empresas por NIF, no por nombre.** Recorre `Company` y lee `Company Information` con `ChangeCompany`. NIF normalizado: `"VAT Registration No."` en mayúsculas, sin espacios ni prefijo `ES`. Origen = la empresa con NIF `B28296812`. Destinos = las de NIF `B28630796`, `B10382638` y `B82770652`. Si no aparece exactamente una empresa por NIF, error (origen) o fila «Empresa no encontrada» y sigue (destino).
   2. **Comprobar el origen** (error si falla, no se toca nada): en el formato `MOD322` de Pharma hay línea en la 2180 con Box `63`, no hay línea en la 1948 y la 945 vale `02100`, es decir, la 00005 está aplicada.
   3. **Por cada destino, validar todo y después grabar, todo o nada.** Si algo da «No coincide», esa empresa no se toca y las demás siguen.
      1. Identificación: en el formato actual del destino tiene que haber exactamente una línea en cada una de las posiciones 342 (long. 9), 351 (60), 447 (1) y 448 (9), con `Value` no vacío, y la de la 342 tiene que ser el NIF de la empresa. Si no, «No coincide».
      2. Razón social: la de la 351 del destino, en mayúsculas y sin acentos ni diéresis (Á→A, É→E, Í→I, Ó→O, Ú→U, Ü→U; la Ñ se queda). Gestión pasa a `ENTECO GESTION S.L.`.
      3. Declaración (`VAT Statement Line`, `"Statement Name"` = `MOD322`): igual que D1 y D2 de la 00005, Box `152` → `20` y Box `150` → `18` («Ya estaba» si ya lo tiene). Además, toda `Box` no vacía de la declaración del destino tiene que existir en la declaración o en el formato de Pharma; si alguna no, «No coincide» con la lista (su importe no saldría en el fichero).
      4. Si no es Simular: borra todas las líneas `MOD322` del formato del destino (`DeleteAll(false)`) e inserta una copia de cada línea `MOD322` del formato de Pharma con **el mismo `Nº`** y todos sus campos (`TransferFields` + `Insert(false)`), con dos excepciones:
         - las líneas en las posiciones 342, 351, 447 y 448 llevan el `Value` del destino (paso 3.1, la 351 limpia del paso 3.2);
         - las líneas de tipo Numérico con `Box` no vacía van con `Value` vacío (el report las recalcula; así no viaja ningún importe de Pharma). Las numéricas sin `Box` (tipos fijos como `02100` en la 945 o `10000` en la 2467) se copian tal cual.
   4. Resultado con los helpers que ya existen (`IniciarResultado`, `AnadirResultado`, `ExportarResultado`):
      - por destino, una fila por cada línea del formato **antiguo** que se borra, con Nº, posición, longitud, tipo, subtipo, descripción, casilla y valor (es la copia de seguridad para volver atrás);
      - una fila por cada cambio de casilla de la declaración y por cada valor de identificación que se mantiene;
      - una fila «Revisar» (informativa, no bloquea) por cada línea **no numérica** de Pharma con `Value` no vacío cuya posición y longitud coinciden con una línea del formato antiguo del destino de `Value` distinto, fuera de las cuatro de identificación (por si hay algún otro dato propio de la empresa);
      - total por destino: líneas borradas, insertadas, «Revisar», «No coincide».
2. `Report 50025 "GRX Fix"`, `OnPreReport`: la llamada pasa de `CorregirConfiguracionMod322(Simular)` a `CopiarFormatoMod322DesdePharma(Simular)`.
3. `app.json`: versión `26.10.29.2`. Compilar con CodeCop sin warnings nuevos.

Qué NO se toca:
- El formato ni la declaración de Pharma.
- La declaración `MOD322` del destino salvo las dos casillas del 21 % (sus filas dependen de los grupos contables de cada empresa: no se copian).
- `MOD353`, MigracionBC y el `Report 50110`.

## Casos
1. Manviel y Extremadura con el formato antiguo: Simular lista las líneas que se borran, los cuatro valores de identificación, D1/D2 «Cambiado» y las líneas que se insertarían; nada cambia.
2. Gestión (dominante): igual, con `D` en la 447 y la razón social sin acento.
3. Destino ya copiado (segunda ejecución): se vuelve a copiar igual; los valores de identificación salen iguales y D1/D2 «Ya estaba». No es un error.
4. Destino al que le falta una línea de identificación, o con NIF en la 342 distinto del de la empresa: «No coincide», esa empresa sin tocar.
5. Pharma sin la 00005 aplicada: error y nada cambia en ninguna empresa.
6. Declaración del destino con una casilla que Pharma no tiene: «No coincide» con la lista de casillas.

## Pruebas de aceptación
1. Compila con CodeCop sin warnings nuevos; publicar en producción (`BC252`) no pide sincronizar esquema.
2. Producción, Simular: Excel con Manviel, Extremadura y Gestión, ninguna en «No coincide». Revisar con Daniel las filas «Revisar» antes de ejecutar.
3. Producción, sin Simular. En cada destino, el formato `MOD322` tiene el mismo número de líneas que el de Pharma, con los mismos Nº, y las posiciones 342/351/447/448 con los valores de la tabla de Contexto.
4. Paula genera el 322 de septiembre de 2026 de las tres empresas: cada fichero empieza por `<T32202026090000>`, la página 1 va de la 329 a la 2128, termina en `</T32202000></T32202026090000>` y no lleva `<T32203000>`. Los importes deben coincidir con los del fichero antiguo de la misma empresa (`EM_`, `EE_`, `EG_MOD322 (21).txt`): total devengado, total a deducir, resultado [63] y [70] (en Extremadura y Gestión, negativos). Daniel deja los tres ficheros en `00 INBOX` y Cowork los compara antes de que Paula los suba.
5. Paula los valida en la sede: «No existen errores».

## Después
- **Plazo:** 30-10-2026. Si no llega, plan B: Paula exporta con «Abrir en Excel» el formato `MOD322` antiguo de cada empresa (da la casilla de cada posición) y Cowork monta los ficheros a mano.
- Las filas del 4 % y el 10 % y los valores de diciembre siguen pendientes, como en la 00005; ahora aplican a las cuatro empresas por igual.
- **Modelo 353** (Gestión, consolidado): Paula no dice que falle; si falla, pedir fichero y error.
- Mientras haya cuatro copias del formato, cualquier corrección futura del `MOD322` se hace en Pharma y se vuelve a lanzar este proceso.
- No cambia nada que vea el usuario salvo que el fichero sale bien: no hay que tocar el manual.

## Desviaciones del plan
- **Numéricas con casilla (paso 3.4).** El Diseño las deja todas con `Value` vacío y pone el `02100` de la 945 como ejemplo de numérica «sin Box», pero en Pharma la 945 tiene Box `19` (tabla de la 00005) y no hay fila de declaración con Box 19: vaciada, el report no la rellena y saldría `00000` en el tipo del 21 %. Se vacía el `Value` solo si la casilla está en la declaración `MOD322` de Pharma o en la del destino (con D1/D2 hecho), que son las que recalcula el `Report 50110`; así sigue sin viajar ningún importe de Pharma. Las numéricas con casilla que no está en ninguna declaración se copian tal cual y, si su valor no es todo ceros, salen en el Excel como «Revisar: casilla sin fila en la declaración, se copia el valor de Pharma» (la 945 con `02100` sale ahí; hay que mirar que no haya ningún importe).
- **Origen**: además de 2180/1948/945, se comprueba que Pharma tiene exactamente una línea en la 342, 351, 447 y 448 con la longitud de la tabla; si no, error y no se toca nada.
- **Excel**: la línea borrada sale con la clave `empresa · posición P (Nº n) descripción`, en Campo `Long., tipo, subtipo, casilla` y su `Value` solo en Valor anterior (Resultado «Borrada»), para que quepa entero; la insertada, igual con el valor en Valor nuevo (Resultado «Insertada»). Los valores de identificación salen «Se mantiene» (anterior y nuevo; en la 351, el limpio). Si en una empresa hay algún «No coincide», no se listan las líneas que se borrarían ni las que se insertarían, solo lo que no coincide, las casillas de la declaración («Sin cambiar») y las «Revisar». Cada empresa acaba con una fila «Total».
- **«Revisar» de texto**: compara cada línea no numérica de Pharma con valor con la línea del destino que **empieza** en la misma posición (la que encuentra el proceso por posición) y tiene la misma longitud.
- `AnadirResultado` corta a 250 caracteres la clave y los valores (límite de la celda del Excel Buffer).
- Como en las fichas anteriores, compilado llamando a `alc.exe` con CodeCop (`tools/compile.ps1` no lo carga); el paquete está en la raíz como `Galarux_GRX_Enteco_Fix_26.10.29.2.app` (ignorado por git).

## Resultado
- `Codeunit 50089 "GRX Main"`: procedimiento nuevo `CopiarFormatoMod322DesdePharma(Simular)` y sus locales.
  - Empresas por NIF (`EmpresasConNif`: recorre `Company` y lee `"VAT Registration No."` de `Company Information` con `ChangeCompany`, normalizado en mayúsculas, sin espacios ni `ES`). Origen `B28296812`: si no hay exactamente una, error. Destinos `B28630796`, `B10382638`, `B82770652`: si no hay exactamente una, fila «Empresa no encontrada» con las empresas que tienen ese NIF y sigue.
  - `ComprobarOrigenMod322`: 2180 con Box 63, sin línea en la 1948, 945 = `02100` y las cuatro líneas de identificación; si algo falla, error antes de tocar nada. Guarda las casillas de la declaración de Pharma y las de declaración + formato.
  - Por destino, dos pasadas (`ValidarDestinoMod322`), como la 00005: identificación (342 = NIF de la empresa, 351 en mayúsculas sin acentos, 447, 448), casillas de la declaración del destino que no están en Pharma y D1/D2 (152 → 20, 150 → 18, con `CambiarCasillaDeclaracion` de la 00005). Si no hay ningún «No coincide» y no es Simular: `DeleteAll(false)` del formato `MOD322` del destino e `Insert(false)` de cada línea de Pharma con `TransferFields` (mismo Nº), con los valores de identificación del destino y el `Value` de las numéricas con casilla de declaración vacío.
  - Excel `GRX Fix Copia MOD322 <empresa> <modo>` y `Message` con el origen y, por destino, borradas / insertadas / revisar / no coincide.
- `Report 50025 "GRX Fix"`, `OnPreReport`: llama a `cuGrxFix.CopiarFormatoMod322DesdePharma(Simular)`. `CorregirConfiguracionMod322` sigue en la codeunit.
- `app.json`: versión 26.10.29.2 (dependencia de `Enteco` sin tocar, 26.9.2.1).
- Compilado con `alc` 17.0 y CodeCop: 0 errores y los mismos 6 warnings que la 26.10.29.1 (AA0215 nombres de fichero, AA0139 en `Fix_Imprimase`, AA0137 en `BorraCortePersonalizado`), ninguno nuevo. Sin tablas ni campos: no pide sincronizar esquema.
- No se ha ejecutado contra ninguna base de datos.
- **Simulación en producción del 29-10** (Excel `GRX Fix Copia MOD322 Enteco_Pharma Simulación.xlsx`), revisada línea a línea:
  - Las tres empresas con 0 «No coincide»: 254 líneas borradas (formato antiguo, con páginas 3 y 4 hasta la 7447) y 247 insertadas (las de Pharma). Identificación como en la tabla de Contexto; Gestión pasa a `ENTECO GESTION S.L.` con `D`. D1/D2 «Cambiado» en las tres.
  - Todas las casillas con importe en el formato antiguo tienen línea en el nuevo con la misma casilla (150 y 152 a través de 18 y 20); en Extremadura y Gestión la [63] es negativa.
  - «Revisar» de la **460 es un falso aviso**: «Revisar» compara por posición y entre los dos diseños las líneas de identificación se han movido (la 460 antigua es la prorrata especial, Nº 28; la de Pharma es el criterio de caja, Nº 27). Comparadas por `Nº`, Nº 25 a 28 tienen el mismo valor en las cuatro empresas.
  - «Revisar» de la 7, 11, 431 y 435 (ejercicio y periodo, Nº 4, 5, 20 y 21): los pone el `Report 50110` al generar. 945 `02100` y 2467 `10000`: son los mismos valores fijos que tenía el formato antiguo (707 y 2082).
  - **Lo que «Revisar» no ve** (por `Nº`, no por posición): Gestión tenía el epígrafe IAE principal (Nº 152) `8497` y la copia le pone el `474` de Pharma; Extremadura y Gestión tenían Nº 109 (exonerado del 390) `1` y la copia pone `2`; Manviel tenía Nº 107 (volumen de operaciones) `2` y la copia pone `1`. Son datos de la página 3 y de diciembre, que el `Report 50110` solo emite en el último periodo: no afectan al 322 de septiembre. Entran en los valores de diciembre pendientes de Después; el Nº 152 de Gestión se puede corregir a mano tras ejecutar.
- Pendiente (Daniel): publicar en producción, Simular y revisar el Excel (ninguna empresa en «No coincide»; filas «Revisar», sobre todo las de casilla sin fila en la declaración), ejecutar y seguir las pruebas de aceptación 3 a 5. Antes de ejecutar, guardar el Excel de la simulación: es la copia de seguridad del formato antiguo. Plazo del 322 de septiembre: 30-10-2026.

## Historial
- 2026-10-29 Cowork: ficha creada.
- 2026-10-29 Claude Code: `CopiarFormatoMod322DesdePharma` en la `Codeunit 50089`, `Report 50025` apuntado a él, versión 26.10.29.2, compilado con CodeCop sin warnings nuevos; `.app` en la raíz. Desviación: las numéricas con casilla que no está en ninguna declaración (la 945 de tipo 21 %, Box 19) se copian con su valor en vez de vaciarse. Estado `en pruebas`: falta publicar, simular y ejecutar en producción.
- 2026-10-29 Claude Code: revisado el Excel de la simulación en producción: 0 «No coincide» en las tres empresas, todas las casillas con importe tienen destino; el «Revisar» de la 460 es un falso aviso (las líneas se movieron entre diseños). Por `Nº` cambian datos de diciembre (Nº 107, 109 y el epígrafe IAE Nº 152 de Gestión, `8497` → `474`), que no salen en septiembre. Se puede ejecutar.
