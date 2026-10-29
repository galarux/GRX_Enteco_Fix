---
id: 00006
titulo: "Modelo 322: copiar el «Formato transferencia» MOD322 de Pharma (ya corregido, diseño de 2026) a Manviel, Extremadura y Gestión"
repo: GRX_Enteco_Fix
rama: master
estado: propuesta
creado: 2026-10-29
modificado: 2026-10-29
proyecto: ENTECO Contabilidad Mejoras
commits: []
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
(Claude Code) Qué se hizo distinto de lo previsto y por qué.

## Resultado
(Claude Code) Qué quedó hecho, objetos finales, cómo se probó.

## Historial
- 2026-10-29 Cowork: ficha creada.
