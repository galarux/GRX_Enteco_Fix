# GRX_BC_Template

Plantilla base para proyectos AL de Business Central. Proporciona scripts de compilación, publicación (SaaS y OnPrem) y configuración de entorno de desarrollo.

## Requisitos previos

- **PowerShell 7+** (`pwsh`) — el setup y las tareas de VS Code lo invocan directamente; `powershell.exe` no basta.
- **Git** instalado y el proyecto dentro de un repositorio git — `publish.ps1` hace comprobaciones de rama y sincronización.
- **Extensión AL de VS Code** (`ms-dynamics-smb.al-*`) — se usa su `alc.exe` para compilar.
- **Módulo `bccontainerhelper`** — si no está instalado, `publish.ps1` lo instala en `CurrentUser` desde PSGallery.
- Para OnPrem: acceso WinRM al servidor (ver [sección OnPrem](#publicar-a-onprem)).

## Estructura

```
GRX_BC_Template/
├── publish/
│   ├── publish.ps1               # Script de publicación a Business Central
│   ├── credentials.local.json    # Ejemplo de credenciales (no commitear credentials.json)
│   └── environments.local.json   # Ejemplo de entornos de despliegue
├── scripts/
│   └── compile.ps1               # Compilación rápida local sin BC
├── setup-dev.bat                 # Lanzador del setup
└── setup-dev.ps1                 # Script de configuración del entorno
```

## Setup de un nuevo proyecto

1. Copia `setup-dev.bat` y `setup-dev.ps1` a la raíz del proyecto.
2. Ejecuta `setup-dev.bat`.
3. **Primera ejecución:** se crea `setup-dev.ini` con el valor por defecto `TEMPLATE_PATH=..\GRX_BC_Template` y el script sale. Si tu template está en otra ruta, edita el `.ini` antes de volver a ejecutar.
4. Vuelve a ejecutar `setup-dev.bat` para completar el setup.

Ejecutar `setup-dev.bat` en un proyecto ya configurado lo actualiza: sobreescribe las tareas del `tasks.json`, los archivos `.json` y `.ps1` de `publish/` y `scripts/` con la última versión del template, y se autoactualiza a sí mismo.

### Qué hace setup-dev

- Copia la carpeta `publish/` desde el template (incluye `publish.ps1`, `credentials.local.json`, `environments.local.json`).
- Copia la carpeta `scripts/` desde el template (incluye `compile.ps1`).
- Copia `GRX_BC_TEMPLATE_README.md` al proyecto destino.
- Sobreescribe en `.vscode/tasks.json` del proyecto:
  - **AL: Compile (fast local)** — compila con `alc.exe` sin desplegar.
  - **Publish to Business Central** — ejecuta `publish/publish.ps1`.
- Añade al `.gitignore` del proyecto (si no están ya):
  - `setup-dev.bat`
  - `setup-dev.ps1`
  - `publish/credentials.json`
- Se autoactualiza: copia la última versión de `setup-dev.bat` y `setup-dev.ps1` desde el template.

> **Importante:** los archivos `.json` y `.ps1` se **sobrescriben siempre sin preguntar**. Para el resto de archivos, si ya existen en el destino, el script pregunta si sobreescribir, saltar, o aplicar la opción a todos. Si tenías modificaciones locales en `publish.ps1` o similares, se perderán al reejecutar el setup.

> `credentials.json` y `environments.json` **no** están en el template (solo los `.local.json`), así que el setup no los toca.

## Configurar credenciales y entornos

Tras el setup, crea `publish/credentials.json` y `publish/environments.json` a partir de los ejemplos `.local.json`.

### SaaS

**`publish/credentials.json`** (SaaS) — opcional. Si no se define, se usa login interactivo con device code.
```json
{
  "mi_entorno_saas": {
    "clientId": "...",
    "clientSecret": "..."
  }
}
```
El clientId y clientSecret corresponden a una [[AZURE#Registro Aplicaciones|app de Azure]] que debemos registrar y [[BC Autorizar App Azure|autorizar en BC]] con los permisos:
- D365 AUTOMATION
- EXTEN. MGT. - ADMIN
- LOCAL


**`publish/environments.json`** (SaaS)
```json
[
  {
    "name": "Mi Entorno PRE",
    "type": "SaaS",
    "stage": "pre",
    "tenantId": "...",
    "environment": "Sandbox",
    "credentialKey": "mi_entorno_saas"
  },
  {
    "name": "Mi Entorno PRO",
    "type": "SaaS",
    "stage": "pro",
    "tenantId": "...",
    "environment": "Production",
    "credentialKey": "mi_entorno_saas"
  }
]
```

### OnPrem

**`publish/credentials.json`** (OnPrem) — credenciales Windows/BC del servidor.
```json
{
  "mi_entorno_onprem": {
    "username": "DOMINIO\\usuario",
    "password": "..."
  }
}
```

**`publish/environments.json`** (OnPrem)
```json
[
  {
    "name": "Cliente OnPrem",
    "type": "OnPrem",
    "stage": "pro",
    "server": "NOMBRE_SERVIDOR",
    "instance": "BC230",
    "appName": "Nombre exacto de la app (como en app.json)",
    "credentialKey": "mi_entorno_onprem",
    "navAdminToolPath": "C:\\Program Files\\Microsoft Dynamics 365 Business Central\\230\\Service\\NavAdminTool.ps1"
  }
]
```

- `server`: host del Business Central Server al que conectarse por WinRM.
- `instance`: nombre de la Service Instance de BC.
- `appName`: debe coincidir con el `name` del `app.json`.
- `navAdminToolPath` **(opcional)**: si se omite, el script busca automáticamente `NavAdminTool.ps1` dentro de `C:\Program Files\Microsoft Dynamics 365 Business Central` en el servidor y elige la versión más alta.

### Campos comunes

- `stage`: `"pre"` o `"pro"`. Los entornos con `stage: "pro"` requieren estar en rama `main`/`master` y sincronizado con `origin` antes de publicar.
- `credentialKey`: clave que referencia a `credentials.json`.

> `credentials.json` está en `.gitignore`. Nunca lo commitees.

## Publicar

Ejecuta la tarea **Publish to Business Central** desde VS Code (`Ctrl+Shift+P` → `Run Task`) o directamente:

```powershell
pwsh -ExecutionPolicy Bypass -File publish/publish.ps1
```

El script:
1. Muestra un menú para seleccionar entornos (con etiqueta `[PRE]` o `[PRO]`). La opción `0` o pulsar Enter selecciona **todos**.
2. Verifica que no hay cambios pendientes de commitear (siempre).
3. Si algún entorno seleccionado tiene `stage: "pro"`: verifica que estás en `main`/`master` y sincronizado con `origin`.
4. **Solo si hay al menos un entorno SaaS:** compila con `alc.exe`. Si todos los seleccionados son OnPrem, se salta el build y se usa el `.app` ya generado desde VS Code.
5. Localiza el `.app` en la raíz del proyecto (excluyendo los que contengan `test`). Si hay varias versiones, mantiene la más reciente y archiva las demás en `.old_app/`.
6. Avisa si la versión del `.app` no coincide con la de `app.json` y pide confirmación.
7. Pregunta si forzar sincronización de esquema (`Force` vs `Add` por defecto). Usa `Force` solo si se eliminaron/renombraron campos.
8. Publica usando `bccontainerhelper` (SaaS) o una sesión WinRM + `NavAdminTool` (OnPrem). Instala `bccontainerhelper` si no está disponible.

### Publicar a OnPrem

Para OnPrem es importante saber:

- **El build con `alc.exe` NO se ejecuta.** Se reutiliza el `.app` que generes desde VS Code (Ctrl+Shift+B o la propia extensión AL). Compila en VS Code antes de publicar.
- **WinRM / TrustedHosts:** la primera vez que publiques a un servidor, el script intenta añadirlo a `TrustedHosts` del cliente. Esto requiere **elevación de administrador** y lanza un prompt UAC. Si falla, ejecuta manualmente como admin:
  ```powershell
  Set-Item WSMan:\localhost\Client\TrustedHosts -Value 'NOMBRE_SERVIDOR' -Concatenate -Force
  ```
- **Instalación vs upgrade:** si la app ya existía en el servidor, se ejecuta `Start-NAVAppDataUpgrade`. Si es la primera vez, se instala con `Install-NAVApp` en el tenant `default`.
- El `.app` se copia a `C:\Windows\Temp` en el servidor y se borra al terminar.

## Compilación rápida local

La tarea **AL: Compile (fast local)** compila sin necesidad de conexión a Business Central. Útil para verificar errores de sintaxis durante el desarrollo.

> **Nota:** actualmente `scripts/compile.ps1` genera la salida en `output\GalaruxGantt-compiled.app` (nombre hardcodeado). Si cambias de proyecto, edita ese path.
