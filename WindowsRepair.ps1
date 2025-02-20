# ============================================
# Script: Manutenção Completa do Windows Update
# Descrição: Para, limpa caches, executa DISM e SFC, e re-registra componentes.
# Data: 19/02/2025
# Uso: Executar com privilégios de administrador; compatível com Intune.
# ============================================

# Inicia o log (opcional, pode ser redirecionado via Intune)
Start-Transcript -Path "$env:temp\ManutencaoWU_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# --- 1. Verifica se o script está rodando como Administrador ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Sérgio, é preciso executar esse script como Administrador. Abortando..."
    Stop-Transcript
    exit 1
}

Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Iniciando manutenção do Windows Update..." -ForegroundColor Cyan

# --- 2. Parar os serviços essenciais do Windows Update ---
$servicesWU = @("wuauserv", "bits", "cryptSvc", "msiserver")
foreach ($svc in $servicesWU) {
    try {
        Write-Host "Parando o serviço $svc..." -ForegroundColor Yellow
        Stop-Service -Name $svc -Force -ErrorAction Stop
    }
    catch {
        Write-Warning "Não foi possível parar o serviço $svc. Continuando..."
    }
}

# --- 3. Remover pastas de cache do Windows Update ---
# Removendo conteúdo das pastas do SoftwareDistribution e catroot2
$pathsToClean = @(
    "C:\Windows\SoftwareDistribution\Download\*",
    "C:\Windows\SoftwareDistribution\DataStore\*",
    "C:\Windows\System32\catroot2\*"
)

foreach ($path in $pathsToClean) {
    try {
        Write-Host "Limpando cache: $path" -ForegroundColor Yellow
        Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
    }
    catch {
        Write-Warning "Falha ao limpar $path. Pode não existir ou estar em uso."
    }
}

# --- 4. Executar DISM para limpeza dos componentes ---
Write-Host "Executando DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase..." -ForegroundColor Yellow
try {
    DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase
}
catch {
    Write-Warning "Erro ao executar o DISM para limpeza de componentes."
}

# --- 5. Reiniciar os serviços essenciais do Windows Update ---
foreach ($svc in $servicesWU) {
    try {
        Write-Host "Iniciando o serviço $svc..." -ForegroundColor Yellow
        Start-Service -Name $svc -ErrorAction Stop
    }
    catch {
        Write-Warning "Não foi possível iniciar o serviço $svc."
    }
}

# --- 6. Executar checagens e reparos com DISM ---
# Primeira checagem: CheckHealth
Write-Host "Executando DISM /Online /Cleanup-Image /CheckHealth..." -ForegroundColor Yellow
DISM /Online /Cleanup-Image /CheckHealth

# Segunda checagem: ScanHealth
Write-Host "Executando DISM /Online /Cleanup-Image /ScanHealth..." -ForegroundColor Yellow
DISM /Online /Cleanup-Image /ScanHealth

# Reparo completo: RestoreHealth
Write-Host "Executando DISM /Online /Cleanup-Image /RestoreHealth para reparo completo..." -ForegroundColor Yellow
DISM /Online /Cleanup-Image /RestoreHealth

# --- 7. Executar verificação completa com SFC ---
Write-Host "Executando SFC /scannow para verificação dos arquivos do sistema..." -ForegroundColor Yellow
sfc /scannow

# --- 8. Ajuste extra: Re-registro dos componentes do Windows Update ---
Write-Host "Re-registrando componentes essenciais do Windows Update..." -ForegroundColor Yellow
$updateDLLs = @("wuapi.dll", "wuaueng.dll", "wuaueng1.dll", "wucltui.dll", "wups.dll", "wups2.dll", "wuweb.dll")
foreach ($dll in $updateDLLs) {
    $dllPath = "$env:SystemRoot\System32\$dll"
    if (Test-Path $dllPath) {
        try {
            Write-Host "Registrando $dll..."
            regsvr32.exe /s $dllPath
        }
        catch {
            Write-Warning "Falha ao registrar $dll."
        }
    }
    else {
        Write-Warning "$dll não encontrado em $dllPath."
    }
}

Write-Host "Manutenção do Windows Update concluída com sucesso!" -ForegroundColor Green

# Finaliza o log
Stop-Transcript
