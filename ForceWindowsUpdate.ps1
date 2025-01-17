# Configuracoes iniciais
$LogFilePath = "$env:ProgramData\WindowsUpdateLog.txt"
$TimeoutMinutes = 30
$ExpectedBuild = "26100.2894"

# Funcoes auxiliares
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

# Funcao para verificar a versao atual do sistema
function Check-BuildVersion {
    try {
        $CurrentBuild = (Get-ComputerInfo).OsBuildNumber
        if ($CurrentBuild -ge [int]($ExpectedBuild)) {
            Write-Log "Atualizacao concluida com sucesso! Build atual: $CurrentBuild" "SUCCESS"
            return $true
        } else {
            Write-Log ("A build esperada ({0}) nao foi instalada. Build atual: {1}" -f $ExpectedBuild, $CurrentBuild) "WARNING"
            return $false
        }
    } catch {
        Write-Log ("Erro ao verificar a versao do sistema: {0}" -f $_.Exception.Message) "ERROR"
        return $false
    }
}

# Funcao para reparar componentes do Windows Update usando DISM e reiniciar servicos criticos
function Repair-WindowsUpdateComponents {
    Write-Log "Reparando componentes do Windows Update..."
    try {
        dism /online /cleanup-image /scanhealth | Out-Null
        dism /online /cleanup-image /restorehealth | Out-Null

        foreach ($service in @("wuauserv", "cryptsvc", "bits")) {
            Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
            Start-Service -Name $service
        }

        Write-Log "Componentes reparados com sucesso." "SUCCESS"
    } catch {
        Write-Log ("Erro ao reparar componentes do Windows Update: {0}" -f $_.Exception.Message) "ERROR"
    }
}

# Funcao para monitorar progresso das atualizacoes pendentes via logs do Event Viewer
function Monitor-WindowsUpdateProgress {
    Write-Log "Monitorando progresso das atualizacoes..."
    $StartTime = Get-Date

    while ((Get-Date) -lt $StartTime.AddMinutes($TimeoutMinutes)) {
        try {
            # Verificar logs do Windows Update (Event Viewer)
            $UpdateStatus = Get-WinEvent -LogName 'Microsoft-Windows-WindowsUpdateClient/Operational' |
                            Where-Object { $_.Id -eq 19 } | Select-Object -First 1

            if ($UpdateStatus) {
                Write-Log ("Progresso detectado: {0}" -f $UpdateStatus.Message) "INFO"
                return $true
            }
            Start-Sleep -Seconds 30
        } catch {
            Write-Log ("Erro ao monitorar progresso das atualizacoes: {0}" -f $_.Exception.Message) "ERROR"
            return $false
        }
    }

    Write-Log "Tempo limite alcancado sem progresso nas atualizacoes." "WARNING"
    return $false
}

# Funcao para forcar instalacao de todas as atualizacoes pendentes, incluindo drivers e opcionalmente evitar reinicio automatico
function Force-WindowsUpdate {
    Write-Log "Forcando instalacao de todas as atualizacoes pendentes, incluindo drivers..."
    
    try {
        # Instalar todas as atualizacoes pendentes sem reiniciar automaticamente
        Install-WindowsUpdate -AcceptAll -MicrosoftUpdate -IgnoreReboot | Out-Null

        # Monitorar progresso apos iniciar o processo de atualizacao
        if (-not (Monitor-WindowsUpdateProgress)) {
            Write-Log "Nenhum progresso detectado no tempo limite definido." "WARNING"
            return $false
        }

        Write-Log "Todas as atualizacoes pendentes foram instaladas." "SUCCESS"
        return $true
    } catch {
        Write-Log ("Erro ao forcar atualizacoes via Windows Update: {0}" -f $_.Exception.Message) "ERROR"
        return $false
    }
}

# Funcao para evitar reinicializacoes automáticas durante o processo de atualização
function Prevent-AutomaticReboot {
    try {
        # Desabilitar reinicio automatico temporariamente no registro durante a execucao do script
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' `
                         -Name 'NoAutoRebootWithLoggedOnUsers' `
                         -Value 1 -Force
        
        Write-Log "Reinicio automatico desabilitado temporariamente." "INFO"
    } catch {
        Write-Log ("Erro ao desabilitar reinicio automatico: {0}" -f $_.Exception.Message) "ERROR"
    }
}

# Fluxo principal do script
Write-Log "Iniciando processo de atualizacao..."
Prevent-AutomaticReboot

if (-not (Check-BuildVersion)) {
    Repair-WindowsUpdateComponents

    if (-not (Force-WindowsUpdate)) {
        Write-Log "Falha ao instalar as atualizacoes mesmo apos reparos." "ERROR"
    }
} else {
    Write-Log "O dispositivo ja esta atualizado." "INFO"
}
