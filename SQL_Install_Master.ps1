# SQL_Install_Master.ps1 - Instalação Automática do SQL Server 2022 Express
# Versão que segue EXATAMENTE seu passo-a-passo manual

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
Write-Host "║         Seguindo seu passo-a-passo manual                   ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# ==============================================
# CONFIGURAÇÃO DOS DIRETÓRIOS
# ==============================================
$persistentDir = "C:\SQL_Installers"
$sqlExtractDir = "C:\SQL2022\ExpressAdv_PTB"  # EXATAMENTE a pasta que você mencionou

# Criar diretórios
if (-not (Test-Path $persistentDir)) { New-Item -ItemType Directory -Path $persistentDir -Force | Out-Null }
if (-not (Test-Path "C:\SQL2022")) { New-Item -ItemType Directory -Path "C:\SQL2022" -Force | Out-Null }

Write-Host "📁 Pasta de installers: $persistentDir" -ForegroundColor Gray
Write-Host "📁 Pasta de extração: $sqlExtractDir" -ForegroundColor Gray

# ==============================================
# 1. DOWNLOAD DO SQL SERVER (SE NECESSÁRIO)
# ==============================================
Write-Host "`n[1/5] Verificando/download do SQL Server 2022 Express..." -ForegroundColor Yellow

$sqlInstaller = "$persistentDir\SQL2022-Express.exe"
$sqlURL = "https://go.microsoft.com/fwlink/?linkid=2216019"

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

# ==============================================
# 2. EXECUTAR O WEB INSTALLER (CRIA A PASTA C:\SQL2022\ExpressAdv_PTB)
# ==============================================
Write-Host "`n[2/5] Executando web installer (criando pasta $sqlExtractDir)..." -ForegroundColor Yellow
Write-Host "  ⏳ Isso pode levar alguns minutos..." -ForegroundColor Gray

try {
    # Executa o web installer em modo silencioso para extrair os arquivos
    $process = Start-Process -FilePath $sqlInstaller `
        -ArgumentList "/ACTION=Download", "/MEDIAPATH=`"$sqlExtractDir`"", "/QUIET" `
        -Wait `
        -PassThru `
        -NoNewWindow

    if ($process.ExitCode -eq 0) {
        Write-Host "  ✅ Arquivos extraídos com sucesso em: $sqlExtractDir" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Falha na extração. Código: $($process.ExitCode)" -ForegroundColor Red
        
        # Tentativa alternativa com parâmetro de extração
        Write-Host "  ⏳ Tentando método alternativo de extração..." -ForegroundColor Yellow
        $process = Start-Process -FilePath $sqlInstaller `
            -ArgumentList "/x:`"$sqlExtractDir`"", "/Q" `
            -Wait `
            -PassThru `
            -NoNewWindow
            
        if ($process.ExitCode -eq 0) {
            Write-Host "  ✅ Arquivos extraídos com sucesso (método alternativo)!" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Falha também no método alternativo. Código: $($process.ExitCode)" -ForegroundColor Red
            exit 1
        }
    }
}
catch {
    Write-Host "  ❌ Erro na extração: $_" -ForegroundColor Red
    exit 1
}

# ==============================================
# 3. LOCALIZAR O SETUP.EXE
# ==============================================
Write-Host "`n[3/5] Localizando instalador principal (setup.exe)..." -ForegroundColor Yellow

$setupExe = Get-ChildItem -Path $sqlExtractDir -Recurse -Filter "setup.exe" | Select-Object -First 1 -ExpandProperty FullName

if (-not $setupExe) {
    Write-Host "  ❌ Instalador principal não encontrado em $sqlExtractDir!" -ForegroundColor Red
    Write-Host "     Verificando subpastas..." -ForegroundColor Yellow
    
    # Tentar encontrar em subpastas
    $setupExe = Get-ChildItem -Path "C:\SQL2022" -Recurse -Filter "setup.exe" | Select-Object -First 1 -ExpandProperty FullName
    
    if (-not $setupExe) {
        Write-Host "  ❌ Instalador principal não encontrado em nenhum local!" -ForegroundColor Red
        exit 1
    }
}

Write-Host "  ✅ Instalador encontrado: $setupExe" -ForegroundColor Green

# ==============================================
# 4. CRIAR ARQUIVO DE CONFIGURAÇÃO PARA O SETUP.EXE
# ==============================================
Write-Host "`n[4/5] Criando arquivo de configuração seguindo seu passo-a-passo..." -ForegroundColor Yellow

$configFile = "$sqlExtractDir\ConfigurationFile.ini"

# Mapeamento do passo-a-passo para parâmetros:
# - Desmarca extensão AZURE → Não incluir AZUREEXTENSION nas features
# - Selecionar Tudo → FEATURES com todos os componentes
# - Instância PADRÃO → INSTANCENAME=MSSQLSERVER
# - Todos como automático → SVCSTARTUPTYPE=Automatic
# - Modo Misto → SECURITYMODE=SQL e SAPWD

$configContent = @"
; SQL Server 2022 Express Configuration File
; Criado automaticamente seguindo o passo-a-passo do usuário

[OPTIONS]

; Ação de instalação
ACTION="Install"

; Termos de licença (Aceita os termos)
IACCEPTSQLSERVERLICENSETERMS="True"
ENU="False"  ; Manter idioma PT-BR

; Features - SELECIONAR TUDO (exceto Azure Extension)
FEATURES=SQLENGINE,REPLICATION,FULLTEXT,CONN,BC,SDK,SSMS,ADV_SSMS

; Instância PADRÃO
INSTANCENAME="MSSQLSERVER"
INSTANCEID="MSSQLSERVER"

; Contas de serviço - MARCA TODOS COMO AUTOMÁTICO
SQLSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE"
SQLSVCSTARTUPTYPE="Automatic"
AGTSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE"
AGTSVCSTARTUPTYPE="Automatic"
BROWSERSVCSTARTUPTYPE="Automatic"

; Segurança - MODO MISTO com senha
SECURITYMODE="SQL"
SAPWD="$saPassword"
SQLSYSADMINACCOUNTS="$env:COMPUTERNAME\$env:USERNAME"

; Configuração de rede - HABILITAR TCP/IP E NAMED PIPES
TCPENABLED="1"
NPENABLED="1"

; Diretórios de instalação
INSTALLSHAREDDIR="C:\Program Files\Microsoft SQL Server"
INSTALLSHAREDWOWDIR="C:\Program Files (x86)\Microsoft SQL Server"

; Configuração do TempDB
SQLTEMPDBDIR="C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Data"
SQLTEMPDBLOGDIR="C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Data"
SQLTEMPDBFILECOUNT="4"
SQLTEMPDBFILESIZE="8"
SQLTEMPDBFILEGROWTH="64"
SQLTEMPDBLOGFILESIZE="8"
SQLTEMPDBLOGFILEGROWTH="64"

; Desabilitar atualizações automáticas
UpdateEnabled="False"
"@

$configContent | Out-File -FilePath $configFile -Encoding ASCII
Write-Host "  ✅ Arquivo de configuração criado em: $configFile" -ForegroundColor Green

# ==============================================
# 5. EXECUTAR O SETUP.EXE COM O ARQUIVO DE CONFIGURAÇÃO
# ==============================================
Write-Host "`n[5/5] Executando instalação do SQL Server com setup.exe..." -ForegroundColor Yellow
Write-Host "  ⏳ Isso pode levar 10-15 minutos. Por favor, aguarde..." -ForegroundColor Gray
Write-Host "  📋 Seguindo seu passo-a-passo:" -ForegroundColor White
Write-Host "     • Nova instalação anônima do SQL" -ForegroundColor Gray
Write-Host "     • Termos de licença aceitos" -ForegroundColor Gray
Write-Host "     • Extensão Azure desmarcada" -ForegroundColor Gray
Write-Host "     • Selecionar Tudo" -ForegroundColor Gray
Write-Host "     • Instância PADRÃO" -ForegroundColor Gray
Write-Host "     • Todos os serviços como automático" -ForegroundColor Gray
Write-Host "     • Modo MISTO com senha: $saPassword" -ForegroundColor Gray

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
        -RedirectStandardOutput "$sqlExtractDir\install_stdout.log" `
        -RedirectStandardError "$sqlExtractDir\install_stderr.log"

    if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
        Write-Host "  ✅ SQL Server instalado com SUCESSO!" -ForegroundColor Green
        Write-Host "  ✅ SQL Server Configuration Manager instalado!" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Falha na instalação. Código: $($process.ExitCode)" -ForegroundColor Red
        Write-Host "     Verifique os logs em: $sqlExtractDir" -ForegroundColor Yellow
        
        # Mostrar últimas linhas do log de erro
        if (Test-Path "$sqlExtractDir\install_stderr.log") {
            Write-Host "`n     Últimas linhas do log de erro:" -ForegroundColor Yellow
            Get-Content "$sqlExtractDir\install_stderr.log" -Tail 10 | ForEach-Object { Write-Host "     $_" -ForegroundColor Red }
        }
    }
}
catch {
    Write-Host "  ❌ Erro: $_" -ForegroundColor Red
}

# ==============================================
# 6. CRIAR USUÁRIO MAXIMUS
# ==============================================
if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
    Write-Host "`n[6/5] Criando usuário $newUserName..." -ForegroundColor Yellow
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
    }
}

# ==============================================
# RESUMO FINAL
# ==============================================
Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host "                 RESUMO DA INSTALAÇÃO" -ForegroundColor White
Write-Host "="*60 -ForegroundColor Cyan
Write-Host "📌 PASSO-A-PASSO SEGUIDO:" -ForegroundColor White
Write-Host "   ✓ SQL2022-SSEI-Expr.exe executado" -ForegroundColor Green
Write-Host "   ✓ Pasta criada: $sqlExtractDir" -ForegroundColor Green
Write-Host "   ✓ setup.exe localizado" -ForegroundColor Green
Write-Host "   ✓ Instalação com configuração personalizada" -ForegroundColor Green

Write-Host "`n📌 RESULTADO:" -ForegroundColor White
if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
    Write-Host "   • SQL Server: ✅ INSTALADO" -ForegroundColor Green
    Write-Host "   • Configuration Manager: ✅ INSTALADO" -ForegroundColor Green
} else {
    Write-Host "   • SQL Server: ❌ FALHOU (código $($process.ExitCode))" -ForegroundColor Red
}

Write-Host "`n📌 CONFIGURAÇÕES:" -ForegroundColor White
Write-Host "   • Instância: $env:COMPUTERNAME (padrão)" -ForegroundColor White
Write-Host "   • SA: sa / $saPassword" -ForegroundColor Yellow
Write-Host "   • Maximus: $newUserName / $newUserPassword" -ForegroundColor Yellow
Write-Host "   • Protocolos: TCP/IP e Named Pipes HABILITADOS" -ForegroundColor Green

Write-Host "`n📌 ONDE ENCONTRAR:" -ForegroundColor White
Write-Host "   • Configuration Manager: Menu Iniciar > 'SQL Server 2022 Configuration Manager'" -ForegroundColor Gray
Write-Host "   • Ou execute: SQLServerManager16.msc" -ForegroundColor Gray
Write-Host "   • Arquivos extraídos em: $sqlExtractDir" -ForegroundColor Gray
Write-Host "="*60 -ForegroundColor Cyan

Write-Host "`n✅ Processo concluído! Pressione qualquer tecla para sair..." -ForegroundColor Green
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")