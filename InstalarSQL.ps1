<#
.SINOPSE
    Script para instalação automatizada do SQL Server 2022 Express e SSMS.
    Deve ser executado como Administrador.
#>

# ==============================================
# CONFIGURAÇÕES INICIAIS (VOCÊ DEVE AJUSTAR)
# ==============================================

# COLE AQUI OS LINKS DIRETOS QUE VOCÊ COPIAR DO ONEDRIVE (BOTÃO "DOWNLOAD")
$UrlSSMS = "https://1drv.ms/u/c/6e55cffc8559d1cc/IQBsf6c0Qt4uSIcaENa9gZfaAZjEJUhYza1xJiCX5imTmW4?e=fDbz2H"   # <<< SSMS-Setup-PTB.exe
$UrlSQL = "https://1drv.ms/u/c/6e55cffc8559d1cc/IQACubaMgmuURoUTY4vzZ4F6AdHZcCV56hKoYpsClT8h_c0?e=Uhxtds"    # <<< SQL2022-SSEI-Expr.exe
$SaPassword = "123456789" 

# ==============================================
# NÃO ALTERE NADA ABAIXO DESTA LINHA
# ==============================================

Write-Host "=== INICIANDO INSTALAÇÃO AUTOMÁTICA DO SQL SERVER 2022 ===" -ForegroundColor Green

# Criar pasta temporária
$InstallPath = "C:\Temp\SQL_Install"
$ExtractFolder = "$InstallPath\SQL_Setup"
New-Item -ItemType Directory -Force -Path $InstallPath | Out-Null
New-Item -ItemType Directory -Force -Path $ExtractFolder | Out-Null

# Caminhos dos instaladores
$SSMSInstaller = "$InstallPath\SSMS-Setup-PTB.exe"
$SQLInstaller = "$InstallPath\SQL2022-SSEI-Expr.exe"
$SetupExe = "$ExtractFolder\setup.exe"

# ==============================================
# 1. DOWNLOAD DOS ARQUIVOS
# ==============================================
Write-Host "`n[1/4] Baixando instaladores..." -ForegroundColor Cyan

try {
    Write-Host "Baixando SSMS-Setup-PTB.exe..."
    Invoke-WebRequest -Uri $UrlSSMS -OutFile $SSMSInstaller -UseBasicParsing
    
    Write-Host "Baixando SQL2022-SSEI-Expr.exe..."
    Invoke-WebRequest -Uri $UrlSQL -OutFile $SQLInstaller -UseBasicParsing
    
    Write-Host "Download concluído com sucesso!" -ForegroundColor Green
}
catch {
    Write-Host "ERRO no download: $_" -ForegroundColor Red
    Write-Host "Verifique se os links diretos do OneDrive estão corretos."
    exit 1
}

# ==============================================
# 2. INSTALAÇÃO DO SSMS
# ==============================================
Write-Host "`n[2/4] Instalando SSMS (modo silencioso)..." -ForegroundColor Cyan

try {
    Start-Process -FilePath $SSMSInstaller -ArgumentList "--quiet --norestart" -Wait -NoNewWindow
    Write-Host "SSMS instalado com sucesso!" -ForegroundColor Green
}
catch {
    Write-Host "ERRO na instalação do SSMS: $_" -ForegroundColor Red
    # Continua mesmo assim, pois o SSMS não é crítico para o SQL Server
}

# ==============================================
# 3. EXTRAÇÃO DO SQL SERVER
# ==============================================
Write-Host "`n[3/4] Extraindo arquivos do SQL Server..." -ForegroundColor Cyan

try {
    Start-Process -FilePath $SQLInstaller -ArgumentList "/Q", "/x:`"$ExtractFolder`"" -Wait -NoNewWindow
    Write-Host "Arquivos extraídos com sucesso!" -ForegroundColor Green
}
catch {
    Write-Host "ERRO na extração: $_" -ForegroundColor Red
    exit 1
}

# ==============================================
# 4. INSTALAÇÃO DO SQL SERVER EXPRESS
# ==============================================
Write-Host "`n[4/4] Instalando SQL Server Express (aguarde, pode levar vários minutos)..." -ForegroundColor Cyan

# Monta os argumentos baseados na sua configuração manual
$arguments = @(
    "/ACTION=Install"
    "/IACCEPTSQLSERVERLICENSETERMS"
    "/Q"                          # Modo silencioso (use "/QS" se quiser ver o progresso)
    "/FEATURES=SQLENGINE,REPLICATION,FULLTEXT"  # Instala o motor, replicação e full-text
    "/INSTANCENAME=MSSQLSERVER"   # Instância PADRÃO
    "/SECURITYMODE=SQL"            # Habilita modo misto (Windows + SQL)
    "/SAPWD=`"$SaPassword`""       # Senha do SA
    "/SQLSYSADMINACCOUNTS=`"$env:USERDOMAIN\$env:USERNAME`""  # Usuário atual como admin
    "/TCPENABLED=1"                # Habilita TCP/IP
    "/NPENABLED=1"                 # Habilita Named Pipes
    "/BROWSERSVCSTARTUPTYPE=Automatic"  # SQL Browser automático
    "/AGTSVCSTARTUPTYPE=Automatic"      # SQL Agent automático
    "/SQLSVCSTARTUPTYPE=Automatic"      # Serviço do SQL automático
)

try {
    Start-Process -FilePath $SetupExe -ArgumentList $arguments -Wait -NoNewWindow
    Write-Host "SQL Server Express instalado com sucesso!" -ForegroundColor Green
}
catch {
    Write-Host "ERRO na instalação do SQL Server: $_" -ForegroundColor Red
    exit 1
}

# ==============================================
# LIMPEZA (OPCIONAL)
# ==============================================
Write-Host "`nDeseja apagar os arquivos temporários? (S/N)" -ForegroundColor Yellow
$limpar = Read-Host
if ($limpar -eq "S" -or $limpar -eq "s") {
    Remove-Item -Path $InstallPath -Recurse -Force
    Write-Host "Arquivos temporários removidos." -ForegroundColor Green
}

Write-Host "`n=== INSTALAÇÃO CONCLUÍDA COM SUCESSO! ===" -ForegroundColor Green
Write-Host "Senha do SA (anote): $SaPassword" -ForegroundColor Yellow