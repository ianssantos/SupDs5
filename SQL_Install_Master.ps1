# SQL_Install_Master.ps1 - Instalação Automática do SQL Server 2022 Express
# Versão DEFINITIVA - SSMS primeiro, SQL Server depois

param(
    [string]$saPassword = "123456789",
    [string]$instanceName = "MSSQLSERVER",
    [string]$newUserName = "Maximus",
    [string]$newUserPassword = "123456789",
    [switch]$forceRedownload = $false
)

# ==============================================
# AUTO-ELEVAÇÃO
# ==============================================
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "🔐 Solicitando privilégios de administrador..." -ForegroundColor Yellow
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"" + $MyInvocation.MyCommand.Path + "`""
    Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs
    exit
}

Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     Instalador Automático - SQL Server 2022 Express         ║" -ForegroundColor Cyan
Write-Host "║         (SSMS primeiro, SQL Server depois)                  ║" -ForegroundColor Cyan
Write-Host "║                    Instância: $instanceName                 ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# ==============================================
# CONFIGURAÇÃO DOS DIRETÓRIOS
# ==============================================
$persistentDir = "C:\SQL_Installers"
$extractDir = "C:\SQLSetup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

# Criar diretórios
if (-not (Test-Path $persistentDir)) { New-Item -ItemType Directory -Path $persistentDir -Force | Out-Null }
New-Item -ItemType Directory -Path $extractDir -Force | Out-Null

Write-Host "📁 Pasta de installers: $persistentDir" -ForegroundColor Gray
Write-Host "📁 Pasta de extração: $extractDir" -ForegroundColor Gray

# ==============================================
# 1. DOWNLOAD DOS INSTALADORES
# ==============================================
Write-Host "`n[1/6] Verificando/download dos instaladores..." -ForegroundColor Yellow

$sqlInstaller = "$persistentDir\SQL2022-Express.exe"
$sqlURL = "https://go.microsoft.com/fwlink/?linkid=2216019"

$ssmsInstaller = "$persistentDir\SSMS-Setup.exe"
$ssmsURL = "https://aka.ms/ssmsfullsetup"

# Download SQL Server
if ((Test-Path $sqlInstaller) -and (-not $forceRedownload)) {
    $fileSize = (Get-Item $sqlInstaller).Length / 1MB
    Write-Host "  ✅ SQL Server installer já existe (tamanho: $([math]::Round($fileSize, 2)) MB)" -ForegroundColor Green
} else {
    Write-Host "  ⏳ Baixando SQL Server 2022 Express..." -NoNewline
    try {
        Invoke-WebRequest -Uri $sqlURL -OutFile $sqlInstaller -ErrorAction Stop
        Write-Host " OK" -ForegroundColor Green
    }
    catch {
        Write-Host " FALHA!" -ForegroundColor Red
        Write-Host "     Erro: $_" -ForegroundColor Red
        exit 1
    }
}

# Download SSMS
if ((Test-Path $ssmsInstaller) -and (-not $forceRedownload)) {
    $fileSize = (Get-Item $ssmsInstaller).Length / 1MB
    Write-Host "  ✅ SSMS installer já existe (tamanho: $([math]::Round($fileSize, 2)) MB)" -ForegroundColor Green
} else {
    Write-Host "  ⏳ Baixando SSMS..." -NoNewline
    try {
        Invoke-WebRequest -Uri $ssmsURL -OutFile $ssmsInstaller -ErrorAction Stop
        Write-Host " OK" -ForegroundColor Green
    }
    catch {
        Write-Host " FALHA!" -ForegroundColor Red
        Write-Host "     Erro: $_" -ForegroundColor Red
        exit 1
    }
}

# ==============================================
# 2. INSTALAR SSMS PRIMEIRO
# ==============================================
Write-Host "`n[2/6] Instalando SQL Server Management Studio (SSMS)..." -ForegroundColor Yellow
Write-Host "  ⏳ Isso pode levar vários minutos..." -ForegroundColor Gray

try {
    $processSSMS = Start-Process -FilePath $ssmsInstaller `
        -ArgumentList "/Install", "/Quiet", "/NoRestart" `
        -Wait `
        -PassThru `
        -NoNewWindow

    if ($processSSMS.ExitCode -in @(0, 3010)) {
        Write-Host "  ✅ SSMS instalado com sucesso!" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  SSMS pode não ter instalado corretamente. Código: $($processSSMS.ExitCode)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  ⚠️  Erro na instalação do SSMS: $_" -ForegroundColor Yellow
}

# ==============================================
# 3. EXTRAIR ARQUIVOS DO SQL SERVER
# ==============================================
Write-Host "`n[3/6] Extraindo arquivos de instalação do SQL Server..." -ForegroundColor Yellow
Write-Host "  ⏳ Isso pode levar alguns minutos..." -ForegroundColor Gray

try {
    # Comando correto para extração: /x:caminho /q
    $process = Start-Process -FilePath $sqlInstaller `
        -ArgumentList "/x:`"$extractDir`" /q" `
        -Wait `
        -PassThru `
        -NoNewWindow

    if ($process.ExitCode -eq 0) {
        Write-Host "  ✅ Arquivos extraídos com sucesso!" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Falha na extração. Código: $($process.ExitCode)" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "  ❌ Erro na extração: $_" -ForegroundColor Red
    exit 1
}

# ==============================================
# 4. LOCALIZAR O SETUP.EXE
# ==============================================
Write-Host "`n[4/6] Localizando instalador principal..." -ForegroundColor Yellow

$setupExe = Get-ChildItem -Path $extractDir -Recurse -Filter "setup.exe" | Select-Object -First 1 -ExpandProperty FullName

if (-not $setupExe) {
    Write-Host "  ❌ Instalador principal não encontrado!" -ForegroundColor Red
    exit 1
}

Write-Host "  ✅ Instalador encontrado: $setupExe" -ForegroundColor Green

# ==============================================
# 5. INSTALAR SQL SERVER (COM O SETUP.EXE REAL)
# ==============================================
Write-Host "`n[5/6] Instalando SQL Server 2022 Express..." -ForegroundColor Yellow
Write-Host "  ⏳ Isso pode levar 10-15 minutos. Por favor, aguarde..." -ForegroundColor Gray

# Criar arquivo de configuração para o setup.exe REAL
$configFile = "$extractDir\ConfigurationFile.ini"
$configContent = @"
; SQL Server 2022 Express Configuration File
[OPTIONS]

; Ação
ACTION="Install"

; Produto
IACCEPTSQLSERVERLICENSETERMS="True"
ENU="True"

; Features - Inclui TODOS os componentes
FEATURES=SQLENGINE,REPLICATION,FULLTEXT,CONN,BC,SDK,SSMS,ADV_SSMS

; Instância
INSTANCENAME="$instanceName"
INSTANCEID="$instanceName"

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

; Configuração de rede - HABILITAR NAMED PIPES E TCP/IP
TCPENABLED="1"
NPENABLED="1"

; Diretórios
INSTALLSHAREDDIR="C:\Program Files\Microsoft SQL Server"
INSTALLSHAREDWOWDIR="C:\Program Files (x86)\Microsoft SQL Server"

; TempDB
SQLTEMPDBDIR="C:\Program Files\Microsoft SQL Server\MSSQL16.$instanceName\MSSQL\Data"
SQLTEMPDBLOGDIR="C:\Program Files\Microsoft SQL Server\MSSQL16.$instanceName\MSSQL\Data"
SQLTEMPDBFILECOUNT="4"
SQLTEMPDBFILESIZE="8"
SQLTEMPDBFILEGROWTH="64"
SQLTEMPDBLOGFILESIZE="8"
SQLTEMPDBLOGFILEGROWTH="64"

; Desabilitar atualizações
UpdateEnabled="False"
"@

$configContent | Out-File -FilePath $configFile -Encoding ASCII
Write-Host "  ✅ Arquivo de configuração criado" -ForegroundColor Green

# Executar instalação com o setup.exe REAL
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
        -NoNewWindow `
        -RedirectStandardOutput "$extractDir\install_stdout.log" `
        -RedirectStandardError "$extractDir\install_stderr.log"

    if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
        Write-Host "  ✅ SQL Server instalado com SUCESSO!" -ForegroundColor Green
        Write-Host "  ✅ SQL Server Configuration Manager instalado!" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Falha na instalação. Código: $($process.ExitCode)" -ForegroundColor Red
        Write-Host "     Verifique os logs em: $extractDir" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  ❌ Erro: $_" -ForegroundColor Red
}

# ==============================================
# PÓS-INSTALAÇÃO - CRIAR USUÁRIO
# ==============================================
Write-Host "`n[6/6] Criando usuário $newUserName..." -ForegroundColor Yellow
Write-Host "  ⏳ Aguardando SQL Server iniciar (30 segundos)..." -NoNewline
Start-Sleep -Seconds 30
Write-Host " OK" -ForegroundColor Green

# Tentar criar usuário com múltiplas tentativas
$maxAttempts = 5
$attempt = 1
$userCreated = $false

while ($attempt -le $maxAttempts -and -not $userCreated) {
    try {
        Add-Type -AssemblyName System.Data.SqlClient -ErrorAction SilentlyContinue
        $connectionString = "Server=localhost;Database=master;User Id=sa;Password=$saPassword;TrustServerCertificate=true;Connection Timeout=10;"
        $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
        $connection.Open()
        
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
        Write-Host "  ✅ Usuário $newUserName criado com sucesso!" -ForegroundColor Green
        $userCreated = $true
        $connection.Close()
    }
    catch {
        Write-Host "  ⏳ Tentativa $attempt de $maxAttempts falhou. Aguardando..." -ForegroundColor Gray
        $attempt++
        Start-Sleep -Seconds 10
    }
}

if (-not $userCreated) {
    Write-Host "  ⚠️  Não foi possível criar o usuário após $maxAttempts tentativas." -ForegroundColor Yellow
    Write-Host "     Você pode criar manualmente depois com:" -ForegroundColor Yellow
    Write-Host "     CREATE LOGIN [$newUserName] WITH PASSWORD = N'$newUserPassword';" -ForegroundColor Gray
}

# ==============================================
# RESUMO FINAL
# ==============================================
Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host "                 RESUMO DA INSTALAÇÃO" -ForegroundColor White
Write-Host "="*60 -ForegroundColor Cyan
Write-Host "📌 ORDEM DE INSTALAÇÃO:" -ForegroundColor White
Write-Host "   1. SSMS: " -NoNewline
if ($processSSMS.ExitCode -in @(0, 3010)) { Write-Host "✅ INSTALADO" -ForegroundColor Green } else { Write-Host "❌ FALHA" -ForegroundColor Red }
Write-Host "   2. SQL Server: " -NoNewline
if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) { Write-Host "✅ INSTALADO" -ForegroundColor Green } else { Write-Host "❌ FALHA" -ForegroundColor Red }

Write-Host "`n📌 Configurações:" -ForegroundColor White
Write-Host "   • Instância: $env:COMPUTERNAME (padrão)" -ForegroundColor White
Write-Host "   • SA: sa / $saPassword" -ForegroundColor Yellow
Write-Host "   • Maximus: $newUserName / $newUserPassword" -ForegroundColor Yellow
Write-Host "   • Protocolos: TCP/IP e Named Pipes HABILITADOS" -ForegroundColor Green

Write-Host "`n📌 Onde encontrar:" -ForegroundColor White
Write-Host "   • SQL Server Configuration Manager:" -ForegroundColor White
Write-Host "     - Menu Iniciar > 'SQL Server 2022 Configuration Manager'" -ForegroundColor Gray
Write-Host "     - Ou execute: SQLServerManager16.msc" -ForegroundColor Gray
Write-Host "   • SSMS: Menu Iniciar > 'Microsoft SQL Server Management Studio 20'" -ForegroundColor Gray

Write-Host "`n📁 Arquivos:" -ForegroundColor White
Write-Host "   • Installers salvos em: $persistentDir" -ForegroundColor Gray
Write-Host "   • Arquivos extraídos em: $extractDir" -ForegroundColor Gray
Write-Host "="*60 -ForegroundColor Cyan

Write-Host "`n✅ Processo concluído! Pressione qualquer tecla para sair..." -ForegroundColor Green
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Perguntar se quer limpar arquivos temporários
Write-Host "`nRemover arquivos de extração? (S/N)" -ForegroundColor Yellow
$key = $Host.UI.RawUI.ReadKey("IncludeKeyDown").Character
if ($key -eq 'S' -or $key -eq 's') {
    Remove-Item -Path $extractDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  ✅ Arquivos removidos!" -ForegroundColor Green
}