# SQL_Install_Master.ps1 - Instalação Automática do SQL Server 2022 Express
# Versão CORRIGIDA - Usando método de instalação em 2 etapas

param(
    [string]$saPassword = "123456789",           # Senha do SA (modo misto)
    [string]$instanceName = "MSSQLSERVER",       # Instância padrão
    [string]$installPath = "C:\Program Files\Microsoft SQL Server",
    [string]$newUserName = "Maximus",            # Novo usuário
    [string]$newUserPassword = "123456789",      # Senha do novo usuário
    [switch]$forceRedownload = $false
)

# ==============================================
# BLOCO DE AUTO-ELEVAÇÃO
# ==============================================
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "🔐 Solicitando privilégios de administrador..." -ForegroundColor Yellow
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"" + $MyInvocation.MyCommand.Path + "`""
    if ($MyInvocation.UnboundArguments) { $arguments += " " + $MyInvocation.UnboundArguments }
    Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs
    exit
}

Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     Instalador Automático - SQL Server 2022 Express         ║" -ForegroundColor Cyan
Write-Host "║                    Instância: $instanceName                 ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# Criar diretórios
$persistentDir = "C:\SQL_Installers"
$setupDir = "C:\SQLSetup"
if (-not (Test-Path $persistentDir)) { New-Item -ItemType Directory -Path $persistentDir -Force | Out-Null }
if (-not (Test-Path $setupDir)) { New-Item -ItemType Directory -Path $setupDir -Force | Out-Null }

$tempDir = "$env:TEMP\SQL_Install_$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# 1. DOWNLOAD DO WEB INSTALLER
Write-Host "`n[1/6] Baixando web installer..." -ForegroundColor Yellow
$webInstaller = "$persistentDir\SQL2022-Express.exe"
$webInstallerURL = "https://go.microsoft.com/fwlink/?linkid=2216019"

if ((Test-Path $webInstaller) -and (-not $forceRedownload)) {
    Write-Host "  ✅ Web installer já existe: $webInstaller" -ForegroundColor Green
} else {
    Write-Host "  ⏳ Baixando SQL Server 2022 Express web installer..." -NoNewline
    try {
        Invoke-WebRequest -Uri $webInstallerURL -OutFile $webInstaller -ErrorAction Stop
        Write-Host " OK" -ForegroundColor Green
    }
    catch {
        Write-Host " FALHA!" -ForegroundColor Red
        Write-Host "     Erro: $_" -ForegroundColor Red
        exit 1
    }
}

# 2. DOWNLOAD DOS ARQUIVOS COMPLETOS (OFFLINE INSTALLATION)
Write-Host "`n[2/6] Baixando arquivos completos de instalação..." -ForegroundColor Yellow
Write-Host "  ⏳ Isso pode levar vários minutos (download de ~500MB)..." -ForegroundColor Gray

# Usa o web installer para baixar a mídia completa [citation:4]
$downloadArgs = @(
    "/Action=Download"
    "/MediaPath=`"$setupDir`""
    "/MediaType=Advanced"
    "/Quiet"
    "/Language=en-US"
)

try {
    $process = Start-Process -FilePath $webInstaller `
        -ArgumentList $downloadArgs `
        -Wait `
        -PassThru `
        -NoNewWindow

    if ($process.ExitCode -eq 0) {
        Write-Host "  ✅ Arquivos de instalação baixados com sucesso!" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Falha no download. Código: $($process.ExitCode)" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "  ❌ Erro: $_" -ForegroundColor Red
    exit 1
}

# 3. LOCALIZAR O INSTALADOR REAL (SETUP.EXE)
Write-Host "`n[3/6] Localizando instalador real..." -ForegroundColor Yellow
$setupExe = Get-ChildItem -Path $setupDir -Recurse -Filter "setup.exe" | Select-Object -First 1 -ExpandProperty FullName

if (-not $setupExe) {
    Write-Host "  ❌ Instalador real não encontrado!" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ Instalador encontrado: $setupExe" -ForegroundColor Green

# 4. CRIAÇÃO DO ARQUIVO DE CONFIGURAÇÃO
Write-Host "`n[4/6] Criando arquivo de configuração..." -ForegroundColor Yellow

$configFile = "$tempDir\ConfigurationFile.ini"
$configContent = @"
; SQL Server 2022 Express Configuration File
[OPTIONS]

; Ação de instalação
ACTION="Install"

; Modo silencioso
QUIET="True"
IACCEPTSQLSERVERLICENSETERMS="True"
ENU="True"

; Features a serem instaladas
FEATURES="SQLENGINE,CONN,BC,SDK,SSMS,ADV_SSMS"

; Configuração da instância
INSTANCENAME="$instanceName"
INSTANCEID="$instanceName"
INSTALLSHAREDDIR="$installPath"
INSTALLSHAREDWOWDIR="$installPath (x86)"

; Contas de serviço
SQLSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE"
SQLSVCSTARTUPTYPE="Automatic"
AGTSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE"
AGTSVCSTARTUPTYPE="Automatic"
BROWSERSVCSTARTUPTYPE="Automatic"

; Segurança - Modo Misto
SECURITYMODE="SQL"
SAPWD="$saPassword"
SQLSYSADMINACCOUNTS="$env:COMPUTERNAME\$env:USERNAME"

; Configuração de rede
TCPENABLED="1"
NPENABLED="1"

; Configuração do TempDB
SQLTEMPDBDIR="$installPath\$instanceName\MSSQL\Data"
SQLTEMPDBLOGDIR="$installPath\$instanceName\MSSQL\Data"
SQLTEMPDBFILECOUNT="4"
SQLTEMPDBFILESIZE="8"
SQLTEMPDBFILEGROWTH="64"
SQLTEMPDBLOGFILESIZE="8"
SQLTEMPDBLOGFILEGROWTH="64"

; Diretórios de dados
SQLUSERDBDIR="$installPath\$instanceName\MSSQL\Data"
SQLUSERDBLOGDIR="$installPath\$instanceName\MSSQL\Data"

; Desabilitar atualizações automáticas
UpdateEnabled="False"
"@

$configContent | Out-File -FilePath $configFile -Encoding ASCII
Write-Host "  ✅ Arquivo de configuração criado" -ForegroundColor Green

# 5. INSTALAÇÃO DO SQL SERVER USANDO O SETUP.EXE REAL
Write-Host "`n[5/6] Instalando SQL Server 2022 Express..." -ForegroundColor Yellow
Write-Host "  ⏳ Isso pode levar 10-15 minutos. Por favor, aguarde..." -ForegroundColor Gray

$installArgs = @(
    "/CONFIGURATIONFILE=`"$configFile`""
    "/IACCEPTSQLSERVERLICENSETERMS"
    "/QUIET"
    "/INDICATEPROGRESS=FALSE"
)

try {
    $process = Start-Process -FilePath $setupExe `
        -ArgumentList $installArgs `
        -Wait `
        -PassThru `
        -NoNewWindow

    if ($process.ExitCode -eq 0) {
        Write-Host "  ✅ SQL Server instalado com sucesso!" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Falha na instalação. Código: $($process.ExitCode)" -ForegroundColor Red
        Write-Host "     Verifique logs em: $env:TEMP\*SQL*.log" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  ❌ Erro: $_" -ForegroundColor Red
}

# 6. INSTALAÇÃO DO SSMS
Write-Host "`n[6/6] Instalando SQL Server Management Studio (SSMS)..." -ForegroundColor Yellow
$ssmsInstaller = "$persistentDir\SSMS-Setup.exe"
$ssmsURL = "https://aka.ms/ssmsfullsetup"

if ((Test-Path $ssmsInstaller) -and (-not $forceRedownload)) {
    Write-Host "  ✅ SSMS installer já existe" -ForegroundColor Green
} else {
    Write-Host "  ⏳ Baixando SSMS..." -NoNewline
    try {
        Invoke-WebRequest -Uri $ssmsURL -OutFile $ssmsInstaller -ErrorAction Stop
        Write-Host " OK" -ForegroundColor Green
    }
    catch {
        Write-Host " FALHA!" -ForegroundColor Red
    }
}

if (Test-Path $ssmsInstaller) {
    Write-Host "  ⏳ Instalando SSMS (pode levar vários minutos)..." -ForegroundColor Gray
    $ssmsArgs = @("/Install", "/Quiet", "/NoRestart")
    $processSSMS = Start-Process -FilePath $ssmsInstaller -ArgumentList $ssmsArgs -Wait -PassThru -NoNewWindow
    
    if ($processSSMS.ExitCode -in @(0, 3010)) {
        Write-Host "  ✅ SSMS instalado com sucesso!" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  SSMS pode não ter instalado corretamente. Código: $($processSSMS.ExitCode)" -ForegroundColor Yellow
    }
}

# 7. PÓS-INSTALAÇÃO - VERIFICAÇÕES E CRIAÇÃO DE USUÁRIO
Write-Host "`n[7/6] Verificando instalação e criando usuário..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

$serviceName = "MSSQLSERVER"
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if ($service -and $service.Status -eq 'Running') {
    Write-Host "  ✅ Serviço SQL Server está rodando!" -ForegroundColor Green
    
    # Testar conexão
    try {
        Add-Type -AssemblyName System.Data.SqlClient -ErrorAction SilentlyContinue
        $connectionString = "Server=localhost;Database=master;User Id=sa;Password=$saPassword;TrustServerCertificate=true;"
        $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
        $connection.Open()
        Write-Host "  ✅ Conexão com SQL Server OK!" -ForegroundColor Green
        
        # Criar usuário Maximus
        Write-Host "  ⏳ Criando usuário '$newUserName'..." -NoNewline
        $createUserQuery = @"
        CREATE LOGIN [$newUserName] WITH PASSWORD = N'$newUserPassword', 
            DEFAULT_DATABASE = [master], 
            CHECK_EXPIRATION = OFF, 
            CHECK_POLICY = OFF;
        EXEC sp_addsrvrolemember @loginame = N'$newUserName', @rolename = N'sysadmin';
        ALTER LOGIN [$newUserName] WITH DEFAULT_LANGUAGE = [English];
"@
        $command = $connection.CreateCommand()
        $command.CommandText = $createUserQuery
        $command.ExecuteNonQuery() | Out-Null
        Write-Host " OK" -ForegroundColor Green
        $connection.Close()
    }
    catch {
        Write-Host "  ⚠️  Erro: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ⚠️  Serviço SQL Server não está rodando" -ForegroundColor Yellow
}

# RESUMO FINAL
Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host "                 RESUMO DA INSTALAÇÃO" -ForegroundColor White
Write-Host "="*60 -ForegroundColor Cyan
Write-Host "📌 Instância SQL: $env:COMPUTERNAME (padrão)"
Write-Host "🔑 Modo: Misto (SQL + Windows)"
Write-Host "👤 SA: sa / $saPassword"
Write-Host "👤 Maximus: $newUserName / $newUserPassword"
Write-Host "🌐 Idioma: English"
Write-Host "🔌 Protocolos: TCP/IP e Named Pipes habilitados"
Write-Host "📁 Installers: $persistentDir"
Write-Host "="*60 -ForegroundColor Cyan

Write-Host "`n✅ Processo concluído! Pressione qualquer tecla para sair..." -ForegroundColor Green
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")