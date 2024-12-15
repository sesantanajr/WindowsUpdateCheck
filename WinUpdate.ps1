# ---------------------------------------------------------
# Script de Atualização do Windows via Intune
#
# Este script:
# - Garante TLS 1.2 para download seguro de módulos.
# - Instala ou atualiza o módulo PSWindowsUpdate.
# - Habilita o Microsoft Update para receber atualizações de outros produtos.
# - Configura para aceitar patches confiáveis e instalar drivers via WU.
# - Executa a busca e instalação de todas as atualizações disponíveis (sem forçar reboot).
# - É compatível com Windows 10 e 11 e executado via Microsoft Intune.
#
# Observação:
# - Rodar no contexto SYSTEM (padrão do Intune).
# - Caso atualizações exijam reboot, este não será forçado aqui.
# - Se desejar looping de atualizações até não haver mais nada, considerar executar o script periodicamente.
# ---------------------------------------------------------

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
    # Opcional: Verificar se é Windows 10 ou 11
    $OS = (Get-CimInstance Win32_OperatingSystem)
    if ($OS.Version -notlike "10.*") {
        Write-Host "Este script foi projetado para Windows 10 ou 11."
        exit 0
    }

    # Verifica se o módulo PSWindowsUpdate está instalado
    $ModuleName = "PSWindowsUpdate"
    $InstalledModule = Get-Module -ListAvailable -Name $ModuleName

    if (!$InstalledModule) {
        Write-Host "Módulo PSWindowsUpdate não encontrado. Instalando..."
        Install-Module -Name $ModuleName -Force -Scope AllUsers -ErrorAction Stop
    } else {
        # Opcional: Atualizar o módulo se existir versão mais recente
        Write-Host "Módulo PSWindowsUpdate encontrado. Tentando atualizar..."
        Update-Module -Name $ModuleName -ErrorAction SilentlyContinue
    }

    Import-Module $ModuleName -Force

    # Habilita o Microsoft Update (para obter updates de outros produtos Microsoft)
    Add-WUServiceManager -MicrosoftUpdate -ErrorAction SilentlyContinue

    # Ajustes de Registro para permitir drivers e aceitar patches confiáveis
    $WUKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    if (!(Test-Path $WUKey)) {
        New-Item -Path $WUKey -Force | Out-Null
    }

    # Aceitar patches confiáveis
    New-ItemProperty -Path $WUKey -Name "AcceptTrustedPatches" -Value 1 -PropertyType DWord -Force | Out-Null

    # Permitir instalação de drivers (0 = habilitado)
    New-ItemProperty -Path $WUKey -Name "ExcludeWUDriversInQualityUpdate" -Value 0 -PropertyType DWord -Force | Out-Null

    # Executa a atualização sem forçar reboot
    # -MicrosoftUpdate: Inclui pacotes do Microsoft Update
    # -AcceptAll: Aceita todos os termos
    # -Install: Instala as atualizações
    # Removemos -AutoReboot para não reiniciar automaticamente
    Write-Host "Buscando e instalando todas as atualizações disponíveis..."
    Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -Install -ErrorAction Stop

    Write-Host "Atualizações instaladas. Se necessário, um reboot manual ou via política Intune deverá ser realizado."
}
catch {
    Write-Error "Ocorreu um erro ao tentar atualizar o dispositivo: $($_.Exception.Message)"
    exit 1
}
