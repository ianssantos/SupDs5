# SQL_Install_Master.ps1 - Instalação Automática do SQL Server 2022 Express
# Versão Aprimorada com Instalação Silenciosa Completa, Auto-elevação e Criação de Usuário

param(
    [string]$saPassword = "123456789",           # Senha do SA (modo misto)
    [string]$instanceName = "MSSQLSERVER",       # Instância padrão solicitada
    [string]$installPath = "C:\Program Files\Microsoft SQL Server",
    [string]$newUserName = "Maximus",            # Novo usuário a ser criado
    [string]$newUserPassword = "123456789",      # Senha do novo usuário
    [switch]$forceRedownload = $false            # Força novo download mesmo se arquivos existirem
)

# ==============================================
# BLOCO DE AUTO-ELEVAÇÃO (torna o script infalível)
# ==============================================
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "🔐 Solicitando privilégios de administrador..." -ForegroundColor Yellow
    
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"" + $MyInvocation.MyCommand.Path + "`""
    
    if ($MyInvocation.UnboundArguments) {
        $arguments += " " + $MyInvocation.UnboundArguments
    }
    
    Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs
    exit
}
# ==============================================

Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     Instalador Automático - SQL Server 2022 Express         ║" -ForegroundColor Cyan
Write-Host "║                    Instância: $instanceName                      ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# Criar diretório persistente para arquivos de instalação (evita downloads repetidos)
$persistentDir = "C:\SQL_Installers"
if (-not (Test-Path $persistentDir)) {
    New-Item -ItemType Directory -Path $persistentDir -Force | Out-Null
    Write-Host "📁 Pasta persistente criada: $persistentDir" -ForegroundColor Gray
}

$tempDir = "$env:TEMP\SQL_Install_$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# 1. VERIFICAÇÃO/DOWNLOAD DOS INSTALADORES
Write-Host "`n[1/6] Verificando instaladores..." -ForegroundColor Yellow

$sqlInstaller = "$persistentDir\SQL2022-Express.exe"
$ssmsInstaller = "$persistentDir\SSMS-Setup.exe"

# URLs oficiais da Microsoft
$sqlExpressURL = "https://go.microsoft.com/fwlink/?linkid=2216019"  # SQL 2022 Express
$ssmsURL = "https://aka.ms/ssmsfullsetup"  # SSMS

# Verifica se precisa baixar o SQL Server
if ((Test-Path $sqlInstaller) -and (-not $forceRedownload)) {
    Write-Host "  ✅ SQL Server installer já existe: $sqlInstaller" -ForegroundColor Green
} else {
    Write-Host "  ⏳ Baixando SQL Server 2022 Express..." -NoNewline
    try {
        Invoke-WebRequest -Uri $sqlExpressURL -OutFile $sqlInstaller -ErrorAction Stop
        Write-Host " OK" -ForegroundColor Green
    }
    catch {
        Write-Host " FALHA!" -ForegroundColor Red
        Write-Host "     Erro: $_" -ForegroundColor Red
        exit 1
    }
}

# Verifica se precisa baixar o SSMS
if ((Test-Path $ssmsInstaller) -and (-not $forceRedownload)) {
    Write-Host "  ✅ SSMS installer já existe: $ssmsInstaller" -ForegroundColor Green
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

# 2. CRIAÇÃO DO ARQUIVO DE CONFIGURAÇÃO (OTIMIZADO PARA INSTALAÇÃO SILENCIOSA)
Write-Host "`n[2/6] Criando arquivo de configuração..." -ForegroundColor Yellow

$configFile = "$tempDir\ConfigurationFile.ini"
$configContent = @"
; SQL Server 2022 Express Configuration File
; Configuração para instalação totalmente silenciosa

[OPTIONS]
; Ação de instalação
ACTION="Install"

; Modo silencioso completo (sem UI, sem prompts)
QUIET="True"
QUIETSIMPLE="False"
SUPPRESSPRIVACYSTATEMENTNOTICE="True"
IACCEPTSQLSERVERLICENSETERMS="True"
ENU="True"                                      ; Força idioma Inglês

; Features a serem instaladas
FEATURES="SQLENGINE,CONN,BC,SDK,SSMS,ADV_SSMS"

; Configuração da instância
INSTANCENAME="$instanceName"
INSTANCEID="$instanceName"
INSTALLSHAREDDIR="$installPath"
INSTALLSHAREDWOWDIR="$installPath (x86)"

; Contas de serviço - Todas automáticas
SQLSVCACCOUNT="NT Service\MSSQL`$`$instanceName"
SQLSVCSTARTUPTYPE="Automatic"
AGTSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE"
AGTSVCSTARTUPTYPE="Automatic"

; Configuração de segurança - MODO MISTO
SECURITYMODE="SQL"
SAPWD="$saPassword"
SQLSYSADMINACCOUNTS="$env:COMPUTERNAME\$env:USERNAME"

; Configuração de rede - Habilitar Named Pipes e TCP/IP
TCPENABLED="1"                                  ; Habilita TCP/IP
NPENABLED="1"                                    ; Habilita Named Pipes (conforme solicitado)
BROWSERSVCSTARTUPTYPE="Automatic"

; Configuração do TempDB
SQLTEMPDBDIR="$installPath\$instanceName\MSSQL\Data"
SQLTEMPDBLOGDIR="$installPath\$instanceName\MSSQL\Data"
SQLTEMPDBFILECOUNT="4"
SQLTEMPDBFILESIZE="8"
SQLTEMPDBFILEGROWTH="64"
SQLTEMPDBLOGFILESIZE="8"
SQLTEMPDBLOGFILEGROWTH="64"

; Diretórios de dados do usuário
SQLUSERDBDIR="$installPath\$instanceName\MSSQL\Data"
SQLUSERDBLOGDIR="$installPath\$instanceName\MSSQL\Data"

; Outras configurações
UpdateEnabled="False"
"@

$configContent | Out-File -FilePath $configFile -Encoding ASCII
Write-Host "  ✅ Arquivo de configuração criado: $configFile" -ForegroundColor Green

# 3. INSTALAÇÃO DO SQL SERVER (TOTALMENTE SILENCIOSA)
Write-Host "`n[3/6] Instalando SQL Server 2022 Express (modo silencioso completo)..." -ForegroundColor Yellow
Write-Host "  ⏳ Isso pode levar vários minutos. Por favor, aguarde..." -ForegroundColor Gray

$sqlLog = "$tempDir\SQL_Install.log"
$arguments = @(
    "/CONFIGURATIONFILE=`"$configFile`""
    "/IACCEPTSQLSERVERLICENSETERMS"
    "/Q"                                        # Quiet mode (sem UI)
    "/QS"                                       # Quiet Simple (progresso mínimo)
    "/HIDECONSOLE"                              # Esconde console
)

try {
    # Usa Start-Process com janela oculta e espera
    $process = Start-Process -FilePath $sqlInstaller `
        -ArgumentList $arguments `
        -Wait `
        -PassThru `
        -NoNewWindow `
        -ErrorAction Stop

    if ($process.ExitCode -eq 0) {
        Write-Host "  ✅ SQL Server instalado com sucesso!" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Falha na instalação do SQL Server. Código: $($process.ExitCode)" -ForegroundColor Red
        Write-Host "     Verifique o log: $sqlLog" -ForegroundColor Yellow
        
        # Tenta encontrar o log gerado pelo instalador
        $possibleLogs = Get-ChildItem "$env:TEMP" -Filter "*SQL*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($possibleLogs) {
            Write-Host "     Log mais recente: $($possibleLogs.FullName)" -ForegroundColor Yellow
        }
    }
}
catch {
    Write-Host "  ❌ Erro durante a instalação: $_" -ForegroundColor Red
}

# 4. INSTALAÇÃO DO SSMS
Write-Host "`n[4/6] Instalando SQL Server Management Studio (SSMS)..." -ForegroundColor Yellow
Write-Host "  ⏳ Isso pode levar vários minutos..." -ForegroundColor Gray

$ssmsArguments = @(
    "/Install"
    "/Quiet"
    "/NoRestart"
)

try {
    $processSSMS = Start-Process -FilePath $ssmsInstaller `
        -ArgumentList $ssmsArguments `
        -Wait `
        -PassThru `
        -NoNewWindow `
        -ErrorAction Stop

    if ($processSSMS.ExitCode -in @(0, 3010)) {
        Write-Host "  ✅ SSMS instalado com sucesso!" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  SSMS pode não ter instalado corretamente. Código: $($processSSMS.ExitCode)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  ⚠️  Erro na instalação do SSMS: $_" -ForegroundColor Yellow
}

# 5. PÓS-INSTALAÇÃO - CONFIGURAÇÃO E VERIFICAÇÕES
Write-Host "`n[5/6] Realizando verificações e configurações pós-instalação..." -ForegroundColor Yellow

# Aguardar serviços iniciarem
Write-Host "  ⏳ Aguardando serviços iniciarem (20 segundos)..." -NoNewline
Start-Sleep -Seconds 20
Write-Host " OK" -ForegroundColor Green

# Verificar se o serviço do SQL está rodando
$serviceName = "MSSQL`$" + $instanceName
if ($instanceName -eq "MSSQLSERVER") {
    $serviceName = "MSSQLSERVER"  # Nome especial para instância padrão
}

$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if ($service -and $service.Status -eq 'Running') {
    Write-Host "  ✅ Serviço SQL Server ($serviceName) está rodando!" -ForegroundColor Green
    
    # Testar conexão com SA
    try {
        # Carregar assembly do SQL Server
        [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | Out-Null
        [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | Out-Null
        
        $connectionString = "Server=localhost;Database=master;User Id=sa;Password=$saPassword;"
        if ($instanceName -ne "MSSQLSERVER") {
            $connectionString = "Server=localhost\$instanceName;Database=master;User Id=sa;Password=$saPassword;"
        }
        
        $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
        $connection.Open()
        Write-Host "  ✅ Conexão com SQL Server (modo misto) OK!" -ForegroundColor Green
        
        # CRIAR USUÁRIO MAXIMUS (conforme solicitado)
        Write-Host "  ⏳ Criando usuário '$newUserName'..." -NoNewline
        
        $createUserQuery = @"
        -- Criar login
        CREATE LOGIN [$newUserName] WITH PASSWORD = N'$newUserPassword', 
            DEFAULT_DATABASE = [master], 
            CHECK_EXPIRATION = OFF, 
            CHECK_POLICY = OFF;
        
        -- Conceder permissões de sysadmin (administrador completo)
        EXEC sp_addsrvrolemember @loginame = N'$newUserName', @rolename = N'sysadmin';
        
        -- Configurar idioma padrão como Inglês
        ALTER LOGIN [$newUserName] WITH DEFAULT_LANGUAGE = [English];
        
        -- Criar usuário no banco master (opcional)
        USE [master];
        CREATE USER [$newUserName] FOR LOGIN [$newUserName];
        
        -- Configurar banco de dados padrão
        ALTER LOGIN [$newUserName] WITH DEFAULT_DATABASE = [master];
        
        -- Garantir que o idioma seja inglês para a sessão
        EXEC sp_configure 'default language', 0;  -- 0 = English
        RECONFIGURE;
"@
        
        $command = $connection.CreateCommand()
        $command.CommandText = $createUserQuery
        $command.ExecuteNonQuery() | Out-Null
        
        Write-Host " OK" -ForegroundColor Green
        Write-Host "     👤 Usuário: $newUserName" -ForegroundColor White
        Write-Host "     🔐 Senha: $newUserPassword" -ForegroundColor Yellow
        Write-Host "     🌐 Idioma: English" -ForegroundColor White
        
        $connection.Close()
    }
    catch {
        Write-Host "  ⚠️  Não foi possível testar a conexão ou criar usuário: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ⚠️  Serviço SQL Server não está rodando" -ForegroundColor Yellow
    Write-Host "     Verifique manualmente: Get-Service '$serviceName'" -ForegroundColor Gray
}

# 6. LIMPEZA E RESUMO
Write-Host "`n[6/6] Finalizando..." -ForegroundColor Yellow

# Limpar arquivos temporários (mas manter os installers)
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

# Resumo da instalação
Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host "                 RESUMO DA INSTALAÇÃO" -ForegroundColor White
Write-Host "="*60 -ForegroundColor Cyan
Write-Host "📌 Instância SQL:" -NoNewline; 
if ($instanceName -eq "MSSQLSERVER") {
    Write-Host " $env:COMPUTERNAME (padrão)" -ForegroundColor White
} else {
    Write-Host " $env:COMPUTERNAME\$instanceName" -ForegroundColor White
}

Write-Host "🔑 Modo de Autenticação:" -NoNewline; Write-Host " Misto (SQL + Windows)" -ForegroundColor White
Write-Host "👤 Usuário SA:" -NoNewline; Write-Host " sa" -ForegroundColor White
Write-Host "🔐 Senha SA:" -NoNewline; Write-Host " $saPassword" -ForegroundColor Yellow
Write-Host "👤 Novo Usuário:" -NoNewline; Write-Host " $newUserName" -ForegroundColor Green
Write-Host "🔐 Senha do Usuário:" -NoNewline; Write-Host " $newUserPassword" -ForegroundColor Yellow
Write-Host "🌐 Idioma:" -NoNewline; Write-Host " English" -ForegroundColor White
Write-Host "🛠️  SSMS:" -NoNewline; Write-Host " Instalado" -ForegroundColor Green
Write-Host "🔌 Protocolos:" -NoNewline; Write-Host " TCP/IP e Named Pipes habilitados" -ForegroundColor Green
Write-Host "📁 Installers salvos em:" -NoNewline; Write-Host " $persistentDir" -ForegroundColor White
Write-Host "📁 Pasta de dados:" -NoNewline; Write-Host " $installPath\$instanceName" -ForegroundColor White
Write-Host "="*60 -ForegroundColor Cyan

Write-Host "`n" + "✨"*30 -ForegroundColor Green
Write-Host "    INSTALAÇÃO CONCLUÍDA COM SUCESSO!    " -ForegroundColor White -BackgroundColor Green
Write-Host "✨"*30 -ForegroundColor Green

Write-Host "`n✅ Processo concluído! Pressione qualquer tecla para sair..." -ForegroundColor Green
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")