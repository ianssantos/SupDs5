# SQL_Install_Master.ps1 - Instalação Automática do SQL Server 2022 Express

param(
    [string]$saPassword = "123456789",  # Senha do SA (modo misto)
    [string]$instanceName = "SQLEXPRESS",  # Nome da instância
    [string]$installPath = "C:\Program Files\Microsoft SQL Server"
)

Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     Instalador Automático - SQL Server 2022 Express         ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# Criar diretório temporário para arquivos de instalação
$tempDir = "$env:TEMP\SQL_Install_$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# 1. DOWNLOAD DOS INSTALADORES
Write-Host "`n[1/6] Baixando instaladores..." -ForegroundColor Yellow

# URLs oficiais da Microsoft
$sqlExpressURL = "https://go.microsoft.com/fwlink/?linkid=2216019"  # SQL 2022 Express
$ssmsURL = "https://aka.ms/ssmsfullsetup"  # SSMS

$sqlInstaller = "$tempDir\SQL2022-Express.exe"
$ssmsInstaller = "$tempDir\SSMS-Setup.exe"

Write-Host "  ⏳ Baixando SQL Server 2022 Express..." -NoNewline
Invoke-WebRequest -Uri $sqlExpressURL -OutFile $sqlInstaller
Write-Host " OK" -ForegroundColor Green

Write-Host "  ⏳ Baixando SSMS..." -NoNewline
Invoke-WebRequest -Uri $ssmsURL -OutFile $ssmsInstaller
Write-Host " OK" -ForegroundColor Green

# 2. CRIAÇÃO DO ARQUIVO DE CONFIGURAÇÃO
Write-Host "`n[2/6] Criando arquivo de configuração..." -ForegroundColor Yellow

$configFile = "$tempDir\ConfigurationFile.ini"
$configContent = @"
; SQL Server 2022 Express Configuration File
[OPTIONS]
ACTION="Install"
QUIET="True"
QUIETSIMPLE="False"
IACCEPTSQLSERVERLICENSETERMS="True"
SUPPRESSPRIVACYSTATEMENTNOTICE="True"

; Features
FEATURES="SQLENGINE,SSMS,ADV_SSMS"

; Instance Configuration
INSTANCENAME="$instanceName"
INSTANCEID="$instanceName"
INSTANCEDIR="$installPath"

; Service Accounts
SQLSVCACCOUNT="NT Service\MSSQL`$`$instanceName"
SQLSVCSTARTUPTYPE="Automatic"
AGTSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE"
AGTSVCSTARTUPTYPE="Automatic"

; Security Mode - Mixed Mode Authentication
SECURITYMODE="SQL"
SAPWD="$saPassword"
SQLSYSADMINACCOUNTS="$env:COMPUTERNAME\$env:USERNAME"

; TempDB Configuration
SQLTEMPDBDIR="$installPath\$instanceName\MSSQL\Data"
SQLTEMPDBLOGDIR="$installPath\$instanceName\MSSQL\Data"
SQLTEMPDBFILECOUNT="4"
SQLTEMPDBFILESIZE="8"
SQLTEMPDBFILEGROWTH="64"
SQLTEMPDBLOGFILESIZE="8"
SQLTEMPDBLOGFILEGROWTH="64"

; Other Settings
TCPENABLED="1"
NPENABLED="1"
BROWSERSVCSTARTUPTYPE="Automatic"
UpdateEnabled="False"
"@

$configContent | Out-File -FilePath $configFile -Encoding ASCII

# 3. INSTALAÇÃO DO SQL SERVER
Write-Host "`n[3/6] Instalando SQL Server 2022 Express (modo silencioso)..." -ForegroundColor Yellow
Write-Host "  Isso pode levar alguns minutos. Por favor, aguarde..." -ForegroundColor Gray

$sqlLog = "$tempDir\SQL_Install.log"
$arguments = @(
    "/CONFIGURATIONFILE=`"$configFile`""
    "/INDICATEPROGRESS=FALSE"
    "/QUIET"
)

$process = Start-Process -FilePath $sqlInstaller -ArgumentList $arguments -Wait -PassThru -NoNewWindow

if ($process.ExitCode -eq 0) {
    Write-Host "  ✅ SQL Server instalado com sucesso!" -ForegroundColor Green
} else {
    Write-Host "  ❌ Falha na instalação do SQL Server. Código: $($process.ExitCode)" -ForegroundColor Red
    Write-Host "     Verifique o log: $sqlLog"
}

# 4. INSTALAÇÃO DO SSMS
Write-Host "`n[4/6] Instalando SQL Server Management Studio (SSMS)..." -ForegroundColor Yellow
Write-Host "  Isso pode levar vários minutos..." -ForegroundColor Gray

$ssmsArguments = @(
    "/Install"
    "/Passive"
    "/Quiet"
    "/NoRestart"
)

$processSSMS = Start-Process -FilePath $ssmsInstaller -ArgumentList $ssmsArguments -Wait -PassThru -NoNewWindow

if ($processSSMS.ExitCode -in @(0, 3010)) {  # 3010 significa "reinicialização necessária"
    Write-Host "  ✅ SSMS instalado com sucesso!" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  SSMS pode não ter instalado corretamente. Código: $($processSSMS.ExitCode)" -ForegroundColor Yellow
}

# 5. PÓS-INSTALAÇÃO - VERIFICAÇÕES
Write-Host "`n[5/6] Realizando verificações pós-instalação..." -ForegroundColor Yellow

# Aguardar serviços iniciarem
Start-Sleep -Seconds 10

# Verificar se o serviço do SQL está rodando
$serviceName = "MSSQL`$$instanceName"
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if ($service -and $service.Status -eq 'Running') {
    Write-Host "  ✅ Serviço SQL Server está rodando!" -ForegroundColor Green
    
    # Testar conexão
    try {
        $connectionString = "Server=localhost\$instanceName;Database=master;User Id=sa;Password=$saPassword;"
        $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
        $connection.Open()
        $connection.Close()
        Write-Host "  ✅ Conexão com SQL Server (modo misto) OK!" -ForegroundColor Green
    }
    catch {
        Write-Host "  ⚠️  Não foi possível testar a conexão: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ⚠️  Serviço SQL Server não está rodando" -ForegroundColor Yellow
}

# 6. LIMPEZA E RESUMO
Write-Host "`n[6/6] Finalizando..." -ForegroundColor Yellow

# Resumo da instalação
Write-Host "`n" + "="*50 -ForegroundColor Cyan
Write-Host "RESUMO DA INSTALAÇÃO" -ForegroundColor White
Write-Host "="*50 -ForegroundColor Cyan
Write-Host "📌 Instância SQL:" -NoNewline; Write-Host " $env:COMPUTERNAME\$instanceName" -ForegroundColor White
Write-Host "🔑 Modo de Autenticação:" -NoNewline; Write-Host " Misto (SQL + Windows)" -ForegroundColor White
Write-Host "👤 Usuário SA:" -NoNewline; Write-Host " sa" -ForegroundColor White
Write-Host "🔐 Senha SA:" -NoNewline; Write-Host " $saPassword" -ForegroundColor Yellow
Write-Host "🛠️  SSMS:" -NoNewline; Write-Host " Instalado" -ForegroundColor Green
Write-Host "📁 Pasta de dados:" -NoNewline; Write-Host " $installPath\$instanceName" -ForegroundColor White
Write-Host "="*50 -ForegroundColor Cyan

Write-Host "`n✅ Processo concluído! Pressione qualquer tecla para sair..." -ForegroundColor Green
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")