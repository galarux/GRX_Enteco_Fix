$ErrorActionPreference = "Stop"

$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$appFolder   = Split-Path -Parent $scriptDir
$envsFile    = Join-Path $scriptDir "environments.json"
$credsFile   = Join-Path $scriptDir "credentials.json"

# --- Load config ---
$environments = Get-Content $envsFile | ConvertFrom-Json
$credentials  = if (Test-Path $credsFile) { Get-Content $credsFile | ConvertFrom-Json } else { $null }

# --- Menu ---
Write-Host ""
Write-Host "Select environments:" -ForegroundColor Yellow
Write-Host "  [0] All"
for ($i = 0; $i -lt $environments.Count; $i++) {
    $e = $environments[$i]
    $stageLabel = if ($e.stage) { " [$($e.stage.ToUpper())]" } else { "" }
    Write-Host "  [$($i+1)] $($e.name)$stageLabel  ($($e.type))"
}
Write-Host ""
$selection = Read-Host "Enter numbers separated by commas, or 0 for all [0]"
if ($selection.Trim() -eq "") { $selection = "0" }

if ($selection.Trim() -eq "0") {
    $selected = $environments
} else {
    $selected = $selection -split "," |
                ForEach-Object { $environments[[int]$_.Trim() - 1] }
}

# --- Validar stage ---
$missingStage = $selected | Where-Object { -not $_.stage }
if ($missingStage) {
    foreach ($e in $missingStage) {
        Write-Host "ERROR: El entorno '$($e.name)' no tiene 'stage' configurado (debe ser 'pre' o 'pro')." -ForegroundColor Red
    }
    exit 1
}

# --- Git checks ---
$branch = git rev-parse --abbrev-ref HEAD 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: This folder is not a git repository or git is not installed." -ForegroundColor Red
    exit 1
}

$status = git status --porcelain 2>&1
if ($status) {
    Write-Host "ERROR: There are pending local changes. Commit or stash them before publishing." -ForegroundColor Red
    git status --short
    exit 1
}

$hasProEnv = $selected | Where-Object { $_.stage -eq "pro" }
if ($hasProEnv) {
    if ($branch -ne "main" -and $branch -ne "master") {
        Write-Host "ERROR: Publishing to PRO requires being on the 'main' or 'master' branch. Current branch: $branch" -ForegroundColor Red
        exit 1
    }
    Write-Host "Checking remote sync..." -ForegroundColor DarkGray
    git fetch origin 2>&1 | Out-Null
    $localSha  = git rev-parse HEAD 2>&1
    $remoteSha = git rev-parse "origin/$branch" 2>&1
    if ($localSha -ne $remoteSha) {
        Write-Host "ERROR: Local branch is not in sync with origin/$branch. Push or pull before publishing." -ForegroundColor Red
        Write-Host "  Local:  $localSha" -ForegroundColor Yellow
        Write-Host "  Remote: $remoteSha" -ForegroundColor Yellow
        exit 1
    }
}

# --- Build (only for SaaS; OnPrem uses the .app built from VS Code) ---
$hasSaas   = $selected | Where-Object { $_.type -eq "SaaS" }
$allOnPrem = -not $hasSaas

if ($allOnPrem) {
    Write-Host "OnPrem only — skipping local build (using .app built from VS Code)." -ForegroundColor DarkGray
} else {
    Write-Host "Building..." -ForegroundColor DarkGray
    $alcExe = Get-ChildItem "$env:USERPROFILE\.vscode\extensions" -Filter "alc.exe" -Recurse -ErrorAction SilentlyContinue |
              Where-Object { $_.FullName -match "win32" } |
              Sort-Object LastWriteTime -Descending |
              Select-Object -First 1 -ExpandProperty FullName
    if (-not $alcExe) {
        Write-Host "ERROR: alc.exe not found. Is the AL extension installed in VS Code?" -ForegroundColor Red
        exit 1
    }
    $alcArgs = @("/project:$appFolder", "/packagecachepath:$appFolder\.alpackages")
    $netPackages = Join-Path $appFolder ".netpackages"
    if (Test-Path $netPackages) { $alcArgs += "/assemblyprobingpaths:$netPackages" }
    $buildOutput = & $alcExe @alcArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Build failed:" -ForegroundColor Red
        $buildOutput | ForEach-Object { Write-Host "  $_" }
        exit 1
    }
    Write-Host "Build OK" -ForegroundColor DarkGray
}

# --- Find .app file (archive older versions) ---
$appFiles = Get-ChildItem -Path $appFolder -Filter "*.app" -File |
            Where-Object { $_.Name -notmatch "test" }

if ($appFiles.Count -eq 0) {
    if ($allOnPrem) {
        Write-Host "ERROR: No .app file found in $appFolder. Build the project from VS Code first." -ForegroundColor Red
    } else {
        Write-Host "ERROR: Build succeeded but no .app file found in $appFolder." -ForegroundColor Red
    }
    exit 1
}
if ($appFiles.Count -gt 1) {
    $appFiles = $appFiles | Sort-Object {
        $v = [regex]::Match($_.Name, '(\d+\.\d+\.\d+\.\d+)').Groups[1].Value
        [System.Version]$v
    } -Descending
    $oldDir = Join-Path $appFolder ".old_app"
    if (-not (Test-Path $oldDir)) { New-Item -ItemType Directory -Path $oldDir | Out-Null }
    $appFiles | Select-Object -Skip 1 | ForEach-Object {
        Move-Item -Path $_.FullName -Destination (Join-Path $oldDir $_.Name) -Force
        Write-Host "  Archived: $($_.Name)" -ForegroundColor DarkGray
    }
    $appFiles = @(Get-ChildItem -Path $appFolder -Filter "*.app" -File | Where-Object { $_.Name -notmatch "test" })
}
$appFile = $appFiles[0].FullName
Write-Host ""
Write-Host "App: $($appFiles[0].Name)" -ForegroundColor Cyan

# --- Check version matches app.json ---
$appJsonPath = Join-Path $appFolder "app.json"
if (Test-Path $appJsonPath) {
    $appJsonVersion = ((Get-Content $appJsonPath | ConvertFrom-Json).version).Trim()
    $appFileVersion = [regex]::Match($appFiles[0].Name, '(\d+\.\d+\.\d+\.\d+)').Groups[1].Value
    if ($appJsonVersion -ne $appFileVersion) {
        Write-Host ""
        Write-Host "  WARNING: Version mismatch!" -ForegroundColor Yellow
        Write-Host "  app.json : $appJsonVersion" -ForegroundColor Yellow
        Write-Host "  .app file: $appFileVersion" -ForegroundColor Yellow
        Write-Host ""
        $confirm = Read-Host "  The .app does not match app.json. Publish anyway? (y/N)"
        if ($confirm.Trim() -ne 'y' -and $confirm.Trim() -ne 'Y') {
            Write-Host "Cancelled." -ForegroundColor Red
            exit 1
        }
    }
}

$publishStart = Get-Date

$forceSync = Read-Host "Force schema sync? Needed if fields were removed (y/N) [N]"
$schemaSyncMode = if ($forceSync.Trim() -eq 'y' -or $forceSync.Trim() -eq 'Y') { "Force" } else { "Add" }

# --- Install bccontainerhelper if needed ---
if (-not (Get-Module -ListAvailable -Name bccontainerhelper)) {
    Write-Host "Installing bccontainerhelper..." -ForegroundColor Yellow
    Install-Module bccontainerhelper -Force -AllowClobber -Scope CurrentUser
}
Write-Host "Loading bccontainerhelper..." -ForegroundColor DarkGray
Import-Module bccontainerhelper -Force -WarningAction SilentlyContinue *>&1 | Out-Null

# --- Publish ---
foreach ($env in $selected) {
    Write-Host ""
    Write-Host ">>> Publishing to $($env.name)..." -ForegroundColor Green

    if ($env.type -eq "SaaS") {
        $credKey = $env.credentialKey
        Write-Host "  Authenticating..." -ForegroundColor DarkGray
        $savedPref = $InformationPreference
        $InformationPreference = 'SilentlyContinue'
        if ($credKey -and $credentials -and $credentials.$credKey) {
            $authContext = New-BcAuthContext `
                -tenantId $env.tenantId `
                -clientId $credentials.$credKey.clientId `
                -clientSecret $credentials.$credKey.clientSecret
        } else {
            $InformationPreference = $savedPref
            $authContext = New-BcAuthContext -tenantId $env.tenantId -includeDeviceLogin
        }
        $InformationPreference = $savedPref

        Write-Host "  Uploading..." -ForegroundColor DarkGray
        $publishLog = [System.Collections.Generic.List[object]]::new()
        try {
            Publish-PerTenantExtensionApps `
                -bcAuthContext $authContext `
                -environment $env.environment `
                -appFiles @($appFile) `
                -schemaSyncMode $schemaSyncMode *>&1 | ForEach-Object { $publishLog.Add($_) }
        } catch {
            Write-Host ""
            Write-Host "  ERROR publishing to $($env.name):" -ForegroundColor Red
            Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
            if ($publishLog.Count -gt 0) {
                Write-Host ""
                Write-Host "  --- Detail ---" -ForegroundColor Yellow
                $publishLog | ForEach-Object { Write-Host "  $_" }
            }
            exit 1
        }
    }
    elseif ($env.type -eq "OnPrem") {
        $credKey = $env.credentialKey
        if (-not $credentials -or -not $credentials.$credKey) {
            Write-Host "ERROR: Credential key '$credKey' not found in credentials.json" -ForegroundColor Red
            continue
        }
        $securePass = ConvertTo-SecureString $credentials.$credKey.password -AsPlainText -Force
        $cred       = New-Object PSCredential($credentials.$credKey.username, $securePass)

        # Check WinRM TrustedHosts (required when not domain-joined)
        $trusted = (Get-Item WSMan:\localhost\Client\TrustedHosts -ErrorAction SilentlyContinue).Value
        $serverHost = $env.server
        if ($trusted -notmatch [regex]::Escape($serverHost) -and $trusted -ne "*") {
            Write-Host "  '$serverHost' not in TrustedHosts. Adding (requires admin elevation)..." -ForegroundColor Yellow
            $addCmd = "Set-Item WSMan:\localhost\Client\TrustedHosts -Value '$serverHost' -Concatenate -Force"
            $proc = Start-Process pwsh -Verb RunAs -ArgumentList "-NoProfile -Command $addCmd" -Wait -PassThru
            if ($proc.ExitCode -ne 0) {
                Write-Host "  ERROR: Could not add TrustedHosts. Run this manually as Administrator:" -ForegroundColor Red
                Write-Host "    $addCmd" -ForegroundColor Cyan
                exit 1
            }
            Write-Host "  TrustedHosts updated." -ForegroundColor Green
        }

        $session    = New-PSSession -ComputerName $env.server -Credential $cred

        try {
            $remotePath = "C:\Windows\Temp\$($appFiles[0].Name)"
            Copy-Item -Path $appFile -Destination $remotePath -ToSession $session

            $navToolPath  = $env.navAdminToolPath
            $appVersion   = [regex]::Match($appFiles[0].Name, '(\d+\.\d+\.\d+\.\d+)').Groups[1].Value
            Invoke-Command -Session $session -ScriptBlock {
                param($appPath, $instance, $appName, $appVersion, $syncMode, $navToolPath)

                if ($navToolPath) {
                    $navTool = $navToolPath
                } else {
                    $navTool = Get-ChildItem "C:\Program Files\Microsoft Dynamics 365 Business Central" `
                        -Filter "NavAdminTool.ps1" -Recurse -ErrorAction SilentlyContinue |
                        Sort-Object { [version]([regex]::Match($_.FullName, '\\(\d+)\\').Groups[1].Value + ".0.0.0") } -Descending |
                        Select-Object -First 1 -ExpandProperty FullName
                }
                if (-not $navTool) { throw "NavAdminTool.ps1 not found on remote server." }
                . $navTool *>&1 | Out-Null

                $existing = Get-NAVAppInfo -ServerInstance $instance -Name $appName -Version $appVersion -ErrorAction SilentlyContinue

                Publish-NAVApp -ServerInstance $instance -Path $appPath -SkipVerification
                Sync-NAVApp    -ServerInstance $instance -Name $appName -Version $appVersion -Mode $syncMode

                if ($existing) {
                    Start-NAVAppDataUpgrade -ServerInstance $instance -Name $appName -Version $appVersion
                } else {
                    Install-NAVApp -ServerInstance $instance -Name $appName -Version $appVersion -Tenant "default"
                }

                Remove-Item $appPath -Force
            } -ArgumentList $remotePath, $env.instance, $env.appName, $appVersion, $schemaSyncMode, $navToolPath
        }
        finally {
            Remove-PSSession $session
        }
    }

    Write-Host "    Done: $($env.name)" -ForegroundColor Green
}

$elapsed = (Get-Date) - $publishStart
Write-Host ""
Write-Host "All selected environments published in $([math]::Round($elapsed.TotalSeconds))s." -ForegroundColor Cyan
