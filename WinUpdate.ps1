#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Script abrangente para Windows Update incluindo todas as categorias de atualizações
.DESCRIPTION
    - Repara serviços do Windows Update
    - Atualiza drivers
    - Atualiza produtos Microsoft
    - Instala atualizações opcionais
    - Atualiza features do Windows
    - Instala atualizações de segurança
#>

# Configuração de logs
$LogPath = "$env:TEMP\WindowsUpdate_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param($Message)
    $TimeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $LogMessage = "$TimeStamp : $Message"
    Add-Content -Path $LogPath -Value $LogMessage
    Write-Host $LogMessage
}

# Função para reparar Windows Update
function Repair-WindowsUpdate {
    Write-Log "Iniciando reparo do Windows Update..."
    
    # Parar serviços relacionados
    $services = @('wuauserv', 'bits', 'cryptsvc', 'msiserver')
    foreach ($service in $services) {
        Stop-Service -Name $service -Force
        Write-Log "Serviço $service parado"
    }

    # Limpar cache do Windows Update
    Remove-Item "$env:SystemRoot\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:SystemRoot\System32\catroot2\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "Cache do Windows Update limpo"

    # Reparar componentes do sistema
    Write-Log "Executando verificação do sistema..."
    Start-Process "DISM.exe" -ArgumentList "/Online /Cleanup-Image /RestoreHealth" -Wait -NoNewWindow
    Start-Process "sfc.exe" -ArgumentList "/scannow" -Wait -NoNewWindow
    
    # Reiniciar serviços
    foreach ($service in $services) {
        Start-Service -Name $service
        Write-Log "Serviço $service reiniciado"
    }

    Write-Log "Reparo do Windows Update concluído"
}

try {
    Write-Log "=== Iniciando processo completo de atualização do Windows ==="

    # 1. Reparar Windows Update
    Repair-WindowsUpdate

    # 2. Configurar ambiente
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    
    # 3. Instalar e configurar módulos necessários
    Write-Log "Configurando módulos..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Install-Module PSWindowsUpdate -Force -AllowClobber | Out-Null
    Import-Module PSWindowsUpdate -Force

    # 4. Configurar critérios de atualização
    $updateCriteria = @{
        AcceptAll = $true
        IgnoreReboot = $true
        NotCategory = "Definition Updates"  # Exclui atualizações de definição de antivírus
        Install = $true
    }

    # 5. Instalar atualizações por categoria
    Write-Log "Iniciando instalação de atualizações..."

    # Atualizações de Segurança
    Write-Log "Buscando atualizações de segurança..."
    Get-WindowsUpdate -Category "Security Updates" @updateCriteria

    # Atualizações Críticas
    Write-Log "Buscando atualizações críticas..."
    Get-WindowsUpdate -Category "Critical Updates" @updateCriteria

    # Atualizações de Feature
    Write-Log "Buscando atualizações de features..."
    Get-WindowsUpdate -Category "Feature Packs" @updateCriteria

    # Updates para Produtos Microsoft
    Write-Log "Buscando atualizações de produtos Microsoft..."
    Get-WindowsUpdate -Category "Microsoft" @updateCriteria

    # Drivers
    Write-Log "Buscando atualizações de drivers..."
    Get-WindowsUpdate -Category "Drivers" @updateCriteria

    # Atualizações Opcionais
    Write-Log "Buscando atualizações opcionais..."
    Get-WindowsUpdate -Category "Optional Updates" @updateCriteria

    # 6. Verificar status final
    $pendingReboot = Get-WURebootStatus -Silent
    if ($pendingReboot) {
        Write-Log "AVISO: Sistema requer reinicialização para completar as atualizações"
    }

    Write-Log "=== Processo de atualização concluído ==="
    Write-Log "Log completo disponível em: $LogPath"
}
catch {
    Write-Log "ERRO: $($_.Exception.Message)"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)"
    exit 1
}
