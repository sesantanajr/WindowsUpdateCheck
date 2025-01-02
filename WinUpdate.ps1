#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
  Script abrangente para reparo e atualizacao do Windows,
  compativel com Windows 10 e 11 (Home, Pro, Business, Enterprise).

.DESCRIPTION
  1. Repara servicos do Windows Update (checando e habilitando).
  2. Limpa cache e componentes corrompidos.
  3. Instala modulos necessarios (NuGet, PSWindowsUpdate).
  4. Aplica atualizacoes de seguranca, criticas, drivers, opcionais etc.
  5. Gera logs detalhados, sem forcar reboot.

.NOTES
  Autor: Sergio
#>

# -- Configuracao de logs --------------------------------------

$TimeStamp = (Get-Date -Format 'yyyyMMdd_HHmmss')
$LogPath   = "$env:TEMP\WindowsUpdate_$TimeStamp.log"

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    $logEntry = "[{0:yyyy-MM-dd HH:mm:ss}] {1}" -f (Get-Date), $Message
    Add-Content -Path $LogPath -Value $logEntry
    Write-Host $logEntry
}

# -- Funcao para verificar e ativar servicos essenciais --------

function Enable-RequiredServices {
    Write-Log "Verificando e ativando servicos criticos de Windows Update..."

    # Lista de servicos que podem impactar o Windows Update
    $serviceList = @(
        'wuauserv',  # Windows Update
        'bits',      # Background Intelligent Transfer Service
        'cryptsvc',  # Cryptographic Services
        'msiserver'  # Windows Installer
    )

    foreach ($svc in $serviceList) {
        try {
            $service = Get-Service -Name $svc -ErrorAction Stop
            
            if ($service.StartType -eq 'Disabled') {
                Write-Log ("Servico {0} esta 'Disabled'. Definindo para 'Manual'..." -f $svc)
                Set-Service -Name $svc -StartupType Manual -ErrorAction Stop
            }

            if ($service.Status -ne 'Running') {
                Write-Log ("Iniciando servico {0}..." -f $svc)
                Start-Service -Name $svc -ErrorAction Stop
            }
            Write-Log ("Servico {0} OK" -f $svc)
        }
        catch {
            Write-Log ("ERRO ao configurar servico {0}: {1}" -f $svc, $_.Exception.Message)
        }
    }
}

# -- Funcao para reparo do Windows Update ----------------------

function Repair-WindowsUpdate {
    Write-Log "===== Iniciando reparo do Windows Update ====="

    # Passo 1: Verificar e habilitar servicos
    Enable-RequiredServices

    # Passo 2: Parar servicos de atualizacao
    $services = @('wuauserv', 'bits', 'cryptsvc', 'msiserver')
    foreach ($service in $services) {
        try {
            $currentStatus = (Get-Service -Name $service -ErrorAction SilentlyContinue).Status
            if ($currentStatus -eq 'Running') {
                Stop-Service -Name $service -Force -ErrorAction Stop
                Write-Log ("Servico {0} parado." -f $service)
            }
        }
        catch {
            Write-Log ("ERRO ao parar {0}: {1}" -f $service, $_.Exception.Message)
        }
    }

    # Passo 3: Limpar cache do Windows Update
    Write-Log "Limpando cache do Windows Update..."
    try {
        Remove-Item "$env:SystemRoot\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:SystemRoot\System32\catroot2\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "Cache do Windows Update limpo."
    }
    catch {
        Write-Log ("ERRO ao limpar cache do Windows Update: {0}" -f $_.Exception.Message)
    }

    # Passo 4: Reparar componentes do sistema
    Write-Log "Executando DISM e SFC..."
    try {
        Start-Process "DISM.exe" -ArgumentList "/Online /Cleanup-Image /RestoreHealth" -Wait -NoNewWindow -ErrorAction Stop
        Start-Process "sfc.exe" -ArgumentList "/scannow" -Wait -NoNewWindow -ErrorAction Stop
        Write-Log "DISM e SFC concluidos."
    }
    catch {
        Write-Log ("ERRO ao executar DISM/SFC: {0}" -f $_.Exception.Message)
    }

    # Passo 5: Reiniciar servicos
    foreach ($service in $services) {
        try {
            Start-Service -Name $service -ErrorAction Stop
            Write-Log ("Servico {0} reiniciado." -f $service)
        }
        catch {
            Write-Log ("ERRO ao reiniciar {0}: {1}" -f $service, $_.Exception.Message)
        }
    }

    Write-Log "===== Reparo do Windows Update concluido ====="
}

# -- Funcao para instalar atualizacoes via PSWindowsUpdate -----

function Install-WindowsUpdates {
    Write-Log "===== Iniciando instalacao de atualizacoes ====="

    # Ajustar protocolo TLS
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Ajustar politica de execucao (escopo de processo)
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    Write-Log "Politica de execucao definida para Bypass (escopo de processo)."

    # Instalar pacotes e modulos necessarios
    Write-Log "Instalando modulos e providers (NuGet, PSWindowsUpdate)..."
    try {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction Stop | Out-Null
        Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted -ErrorAction Stop
        Install-Module PSWindowsUpdate -Force -AllowClobber -ErrorAction Stop | Out-Null
        Import-Module PSWindowsUpdate -Force -ErrorAction Stop
        Write-Log "Modulo PSWindowsUpdate instalado/importado com sucesso."
    }
    catch {
        Write-Log ("ERRO ao instalar PSWindowsUpdate ou NuGet: {0}" -f $_.Exception.Message)
        return
    }

    # Criterios de atualizacao
    $updateCriteria = @{
        AcceptAll   = $true
        IgnoreReboot= $true
        NotCategory = "Definition Updates"
        Install     = $true
    }

    # Lista de categorias de atualizacao
    $categories = @(
        "Security Updates",
        "Critical Updates",
        "Feature Packs",
        "Microsoft",
        "Drivers",
        "Optional Updates"
    )

    foreach ($cat in $categories) {
        Write-Log ("Buscando atualizacoes da categoria: {0}" -f $cat)
        try {
            Get-WindowsUpdate -Category $cat @updateCriteria -ErrorAction Stop
        }
        catch {
            Write-Log ("ERRO ao buscar/instalar updates na categoria {0}: {1}" -f $cat, $_.Exception.Message)
        }
    }

    Write-Log "===== Instalacao de atualizacoes concluida ====="

    # Verificar se ha reboot pendente (sem forcar)
    try {
        $rebootStatus = Get-WURebootStatus -Silent
        if ($rebootStatus) {
            Write-Log "AVISO: Ha uma reinicializacao pendente para concluir as atualizacoes. O usuario decide quando reiniciar."
        }
    }
    catch {
        Write-Log ("ERRO ao verificar status de reboot: {0}" -f $_.Exception.Message)
    }
}

# -- Bloco principal (try/catch geral) --------------------------

try {
    Write-Log "=== Iniciando processo completo de atualizacao do Windows ==="

    # 1. Reparar Windows Update
    Repair-WindowsUpdate

    # 2. Instalar atualizacoes (sem forcar reboot)
    Install-WindowsUpdates

    Write-Log "=== Processo de atualizacao finalizado com sucesso ==="
    Write-Log ("Log completo disponivel em: {0}" -f $LogPath)
}
catch {
    Write-Log ("ERRO GERAL: {0}" -f $_.Exception.Message)
    if ($_.Exception.InnerException) {
        Write-Log ("InnerException: {0}" -f $_.Exception.InnerException.Message)
    }
    Write-Log ("Stack Trace: {0}" -f $_.ScriptStackTrace)
    Exit 1
}
