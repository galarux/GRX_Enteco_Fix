# GRX_Enteco_Fix — procesos puntuales de Enteco en Business Central

## Qué es esto

- Extensión de procesos de un solo uso para Enteco (BC 25 OnPrem): procesos que corrigen o importan datos concretos y quedan inertes cuando terminan. Publisher `Galarux`, app `GRX_Enteco_Fix`, GitHub `galarux/GRX_Enteco_Fix`, rama `master`.
- Depende de la app `Enteco` (Goom Spain, repo hermano `../MigracionBC`), cuyas tablas lee y modifica. Los datos de Oracle (DDL, fuentes de Forms) están en el repo `../../Enteco_Contexto`.
- **Nunca lleva tablas, extensiones de tabla ni campos nuevos**: así se publica y se actualiza con los usuarios trabajando, sin sincronizar esquema. Es la convención de las extensiones Fix de Galarux (bóveda: «GALARUX MIS EXTENSIONES BC», sección «Extensiones Fix»).
- **No se crean objetos nuevos**: es OnPrem y la licencia tiene la numeración limitada. Todo va en dos objetos: la `Codeunit 50089 "GRX Main"` (`src/GRX_Main.Codeunit.al`), con un procedimiento público por proceso, y el `Report 50025 "GRX Fix"` (`src/GRX_Fix.Report.al`), que es básico: comprueba el usuario, ofrece Simular y en `OnPreReport` llama al procedimiento del proceso en curso. Los procedimientos que ya no llama nadie se quedan en la codeunit y se borran de vez en cuando, siempre que ya estén en git. El report 50133 «GRX Fix Import Planif» es anterior a esta regla (migración de pedidos internos).
- Empresas: Enteco_Pharma (código Oracle `10`) y Enteco_Manviel (`05`). PRE `BC25_DESARROLLO`, producción `BC252`.
- Se compila con `tools/compile.ps1`. Sin traducciones.
- `grx/desarrollos/` guarda las fichas de desarrollo (las escribe Cowork; plantilla en `_plantilla.md`) y lo que acompaña a cada ficha (p. ej. la consulta a Oracle de la 00001). `grx/utils/` es la carpeta de paso para Excel y ficheros que deja Daniel, ignorada por git.

## Cómo se trabaja aquí

- Antes de tocar código, lee entera la ficha de `grx/desarrollos/` que te indiquen y este fichero. Lo que no esté en la ficha se pregunta a Daniel. El porqué está en su nota `decision` de la bóveda (`<OneDrive>/CD_DOR/CONTENIDO/🏢TRABAJO/CLIENTES/ENTECO/020 DESARROLLOS/`).
- Cada proceso es un procedimiento de la codeunit que recibe `Simular` (opción del report 50025, activada por defecto) y descarga un Excel de resultado al terminar. La comprobación de usuario (solo Tecnología) está en el report 50025. Nada de tablas de log. Para lanzar otro proceso se cambia la llamada del report y se vuelve a publicar.
- Escribe directamente y sin disparar triggers (`Modify(false)`), para no resincronizar con Oracle, salvo que la ficha diga otra cosa.
- Compila con CodeCop y sin warnings nuevos.
- Commits con la etiqueta `[NNNNN]` de la ficha. No commitees `.app`, `.old_app/`, `.vscode/launch.json` ni `grx/utils/`.
- Al terminar cada sesión deja la ficha al día: línea en `## Historial` (`AAAA-MM-DD Claude Code: …`), `modificado`, `estado` (`propuesta` → `en desarrollo` → `en pruebas` → `desplegado` → `finalizado`, o `cancelado`; no hay otros. Tú lo llevas hasta `desplegado`: `en pruebas` cuando el código está hecho y compilado pero falta probarlo; `finalizado`/`cancelado` los pone Daniel) y `commits` (`git log --grep="\[NNNNN\]" --date=short --format="%ad %h %s"`). Tus secciones son Desviaciones del plan, Resultado e Historial; el resto es de Cowork.
- No muevas fichas, no cambies números ni crees fichas nuevas. Sin wikilinks ni secretos en las fichas.
