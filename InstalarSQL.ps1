<#
.SINOPSE
    Script para instalação automatizada do SQL Server 2022 Express e SSMS.
    Deve ser executado como Administrador.
#>

# ==============================================
# CONFIGURAÇÕES INICIAIS (VOCÊ DEVE AJUSTAR)
# ==============================================

# COLE AQUI OS LINKS DIRETOS QUE VOCÊ COPIAR DO ONEDRIVE (BOTÃO "DOWNLOAD")
$UrlSSMS = "https://my.microsoftpersonalcontent.com/personal/6e55cffc8559d1cc/_layouts/15/download.aspx?UniqueId=34a77f6c-de42-482e-871a-10d6bd8197da&Translate=false&tempauth=v1e.eyJzaXRlaWQiOiJmYTRjOWM5NC1mN2IwLTQzZmEtOGM4My1kYmM4NTY2ZDc5NjciLCJhdWQiOiIwMDAwMDAwMy0wMDAwLTBmZjEtY2UwMC0wMDAwMDAwMDAwMDAvbXkubWljcm9zb2Z0cGVyc29uYWxjb250ZW50LmNvbUA5MTg4MDQwZC02YzY3LTRjNWItYjExMi0zNmEzMDRiNjZkYWQiLCJleHAiOiIxNzcyMTUyMDc4In0.-MEO7_JKw66tpTs_2-pj_-QZnq6OzR9sCRwcceDhpMnJmSHH4ZAWfuJTJnKgk3WzQpnRMPUOu-EesSFMLvenwdtHKVKZfkv3EoKvgB2dfwVWwoI5RkCCvt_oiPbGCXDG7xQaDD_NVhaASJvlE7bdVC9Sg7FFR7j0whTVbgsjYKWXH2V21GttnVo4B_Lh5FaXC-mBt2z6fi5MBUsZY5HugPFGBO6-0aiO3CgbSiOekzIzM4jpSpa0aYZhdQzdNPpV1sAVLKSH4Tux6nsBr4q9XPAd83NildtM4zzJV2T_AOJb5NqLMTcyq-6T6LNoGvQ-T4guZihZisQY3FyZYcJPwti2AVfhujlzTHtP6LFFXXpr6WNLVs0VmOH-6KKfWF3KltM7C5cBjioB35wNjJfqqga_zZ85X6sdtNlF7eO8rm_eL5Cg8_fgTP_v_xqsvOvk3Q39c3QNTJDMTuwMFejHZmnHqzvZzuttUacT-h-FAVvvmYH-PYn8970pnD5JmgxJ7Y0meKM03-humrnHQhngvg.S7p6XpYXMl5rQlUoed_mWHCXPRz0Uou5yW0EPUE9x_M&ApiVersion=2.0"   # <<< SSMS-Setup-PTB.exe

$UrlSQL = "https://my.microsoftpersonalcontent.com/personal/6e55cffc8559d1cc/_layouts/15/download.aspx?UniqueId=8cb6b902-6b82-4694-8513-638bf367817a&Translate=false&tempauth=v1e.eyJzaXRlaWQiOiJmYTRjOWM5NC1mN2IwLTQzZmEtOGM4My1kYmM4NTY2ZDc5NjciLCJhdWQiOiIwMDAwMDAwMy0wMDAwLTBmZjEtY2UwMC0wMDAwMDAwMDAwMDAvbXkubWljcm9zb2Z0cGVyc29uYWxjb250ZW50LmNvbUA5MTg4MDQwZC02YzY3LTRjNWItYjExMi0zNmEzMDRiNjZkYWQiLCJleHAiOiIxNzcyMTUyMTkwIn0.KO1VWo0W-dT0322tWBgCmCu16Nni7jxTbcoefUa0V8ddbA3bmXYTPO1Tv0WGb57zQcE892Qvbq3zcn7Swg9SoTBfvE_YB4LteAe9BbdVQt0e-9X8voIOB5WiextLv7PC7V7ZSaG6GtuFx_CsA-kFph6rDk2bTfvkzyJvOz3HExeEJ5Tk5b3hP1QSD8YW6ajvkosyPWiVSCllyQa7W4cOS2PBMOX4sFJoJ8zdGV6mCPXi2oKOEvr17mbJ4scVrP0KsCVOy__INTHPmHpl5GvmM1EpMH6C9m4NINe8tUjO_-SzVIucaLg2xBSN9r0JojQPUMUB3luPf_PTApRA-BYswNP5KytXVdHLtX6xQsuueXwOGorI5jGVrhG6u64HHSH27ptJ0iqzCzPeAwqErtv5sgXarFEibophmcXg0LPYWTNXOkZZp_TFEFhug__ZpZPUONahWehlA2anuztIDpmx_HMlWS5BgoxwENAOtq-TPuUgHYpfMBhcUh3r77eET4qZ4IsiwqcrEAOt5_kz11-Tlg.rVg5NxCnLjTlTrA4BKpi50dHE7hTbaBlRDYep8awlW8&ApiVersion=2.0"    # <<< SQL2022-SSEI-Expr.exe
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