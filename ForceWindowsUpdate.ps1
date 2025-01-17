# Script PowerShell para Atualização Forçada do Windows
# Compatível com PowerShell 5
# Estratégia: Pesquisa Dinâmica, DISM, Windows Update e Atualizações de Recursos

# Configurações iniciais
$WindowsVersion = "Windows 11"
$TargetVersion = "24H2"
$ExpectedBuild = "26100.2894"
$LogFilePath = "$env:TEMP\WindowsUpdateLog.txt"

# Função para registrar logs
function Write-Log {
    param (
        [string]$Message,
        [string]$Type = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Type] $Message"
    Write-Host $LogMessage
    Add-Content -Path $LogFilePath -Value $LogMessage
}

# Função para exibir configurações iniciais
function Display-UpdateParameters {
    Write-Log "Configuracoes Iniciais:"
    Write-Log "Windows: $WindowsVersion"
    Write-Log "Versao Alvo: $TargetVersion"
    Write-Log "Build Esperada: $ExpectedBuild"
}

# Função para verificar a build atual
function Check-BuildVersion {
    $CurrentBuild = (Get-ComputerInfo).OsBuildNumber

    if ($CurrentBuild -ge [int]($ExpectedBuild)) {
        Write-Log "Atualizacao concluida com sucesso! Build atual: $CurrentBuild" "SUCCESS"
        return $true
    } else {
        Write-Log ("A build esperada ({0}) nao foi instalada. Build atual: {1}" -f $ExpectedBuild, $CurrentBuild) "WARNING"
        return $false
    }
}

# Função para reparar componentes do Windows Update usando DISM
function Repair-WindowsUpdateComponents {
    Write-Log "Reparando componentes do Windows Update com DISM..."

    try {
        # Verificar integridade do sistema
        dism /online /cleanup-image /scanhealth | Out-Null
        dism /online /cleanup-image /restorehealth | Out-Null

        # Reiniciar serviços do Windows Update
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        Stop-Service -Name cryptsvc -Force -ErrorAction SilentlyContinue
        Start-Service -Name wuauserv
        Start-Service -Name cryptsvc

        Write-Log "Componentes reparados com sucesso." "SUCCESS"
    } catch {
        Write-Log ("Erro ao reparar componentes do Windows Update: {0}" -f $_.Exception.Message) "ERROR"
        exit 1
    }
}

# Função para forçar instalação de atualizações pendentes via Windows Update
function Force-WindowsUpdate {
    Write-Log "Forçando instalação de atualizações pendentes via Windows Update..."

    try {
        Install-WindowsUpdate -AcceptAll -AutoReboot | Out-Null
        Write-Log "Todas as atualizações pendentes foram instaladas." "SUCCESS"
    } catch {
        Write-Log ("Erro ao forçar atualizações via Windows Update: {0}" -f $_.Exception.Message) "WARNING"
    }
}

# Função para instalar uma atualização de recurso (Feature Update)
function Install-FeatureUpdate {
    Write-Log "Instalando atualização de recurso (Feature Update)..."

    try {
        # Usar DISM para instalar a atualização de recurso diretamente (se disponível)
        dism /online /add-package /packagepath:"C:\Path\To\FeatureUpdate.cab" | Out-Null

        # Alternativa: usar Media Creation Tool ou Windows Update Assistant (modo silencioso)
        # Start-Process -FilePath "$env:TEMP\MediaCreationTool.exe" -ArgumentList "/auto upgrade /quiet" -Wait

        Write-Log "Atualização de recurso instalada com sucesso." "SUCCESS"
    } catch {
        Write-Log ("Erro ao instalar atualização de recurso: {0}" -f $_.Exception.Message) "ERROR"
        exit 1
    }
}

# Fluxo principal do script
Write-Log "Iniciando processo de atualização forçada..."
Display-UpdateParameters

if (-not (Check-BuildVersion)) {
    Repair-WindowsUpdateComponents

    # Forçar atualizações pendentes via Windows Update
    Force-WindowsUpdate

    # Verificar novamente após tentar atualizar via Windows Update
    if (-not (Check-BuildVersion)) {
        Install-FeatureUpdate

        # Verificar novamente após instalar a atualização de recurso
        if (-not (Check-BuildVersion)) {
            Write-Log "A build esperada nao foi instalada mesmo apos todas as tentativas." "ERROR"
            exit 1
        }
    }
}

Write-Log "Processo concluido com sucesso!" "SUCCESS"
