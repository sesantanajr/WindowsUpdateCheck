<# 
.SYNOPSIS
    Script para automatizar atualizacoes do Windows e configuracoes avancadas.

.DESCRIPTION
    - Define politica de execucao.
    - Instala PackageProvider (NuGet).
    - Atualiza PowerShellGet.
    - Instala modulo PSWindowsUpdate.
    - Para e inicia servicos wuauserv e bits.
    - Remove a pasta SoftwareDistribution.
    - Executa DISM para limpeza e restauracao de componentes.
    - Lista e instala atualizacoes do Windows de forma silenciosa.

.NOTES
    Autor: Tony (ChatGPT) para Sergio
    Versao: 2.0
#>

# Variaveis de configuracao para versao-alvo do Windows
$ReleaseVersion = "24H2"       # Pode ser "23H2", "24H2" etc.
$ProductVersion = "Windows 11" # Pode ser "Windows 10" ou "Windows 11"

# 1. Configurar a politica de execucao (nao substitui GPO, apenas local)
Set-ExecutionPolicy Bypass -Scope CurrentUser -Force

# 2. Instalar o PackageProvider (NuGet) silenciosamente
Write-Output "Instalando o PackageProvider NuGet..."
Install-PackageProvider -Name NuGet -Force -Confirm:$false
Write-Output "NuGet instalado/configurado com sucesso."

# 3. Funcao para verificar e atualizar o modulo PowerShellGet
function Update-PowerShellGet {
    Write-Output "Verificando o modulo PowerShellGet..."
    $currentVersion = (Get-Module -Name PowerShellGet -ListAvailable |
                       Sort-Object Version -Descending |
                       Select-Object -First 1).Version
    $requiredVersion = [Version]"2.2.5"  # Versao minima recomendada

    if ($currentVersion -lt $requiredVersion) {
        Write-Output "Atualizando PowerShellGet para a versao $requiredVersion..."
        Install-Module -Name PowerShellGet -Force -AllowClobber -Confirm:$false
        Write-Output "PowerShellGet atualizado com sucesso."
    } else {
        Write-Output "PowerShellGet ja esta na versao mais recente ($currentVersion)."
    }
}

# 4. Funcao para verificar e instalar o modulo PSWindowsUpdate
function Install-PSWindowsUpdate {
    Write-Output "Verificando o modulo PSWindowsUpdate..."
    if (!(Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Output "Instalando o modulo PSWindowsUpdate..."
        Install-Module -Name PSWindowsUpdate -Force -Confirm:$false
        Write-Output "PSWindowsUpdate instalado com sucesso."
    } else {
        Write-Output "O modulo PSWindowsUpdate ja esta instalado."
    }
}

# 5. Funcao para limpar e reiniciar servicos do Windows Update
function Reset-WindowsUpdate {
    Write-Output "Parando servicos wuauserv e bits..."
    Stop-Service -Name wuauserv -ErrorAction SilentlyContinue
    Stop-Service -Name bits -ErrorAction SilentlyContinue

    Write-Output "Removendo pasta SoftwareDistribution..."
    Remove-Item -Path "C:\Windows\SoftwareDistribution" -Recurse -Force -ErrorAction SilentlyContinue

    Write-Output "Reiniciando servicos wuauserv e bits..."
    Start-Service -Name wuauserv
    Start-Service -Name bits

    Write-Output "Executando DISM /Cleanup-Image /StartComponentCleanup /ResetBase..."
    DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase

    Write-Output "Executando DISM /Cleanup-Image /RestoreHealth..."
    DISM /Online /Cleanup-Image /RestoreHealth

    Write-Output "Reset do Windows Update concluido."
}

# 6. Configurar a versao-alvo do Windows (Exemplo: 24H2 - Windows 11)
Write-Output "Configurando versao-alvo do Windows..."
Set-WUSettings -TargetReleaseVersion -TargetReleaseVersionInfo $ReleaseVersion -ProductVersion $ProductVersion -Confirm:$false
Write-Output "Configuracao da versao-alvo concluida ($ReleaseVersion - $ProductVersion)."

# 7. Funcao para listar e instalar atualizacoes do Windows silenciosamente
function Install-WindowsUpdates {
    Write-Output "Carregando modulo PSWindowsUpdate..."
    Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue

    Write-Output "Procurando por atualizacoes disponiveis..."
    # Removerei o -ThrottleLimit, pois pode nao existir em certas versoes do PSWindowsUpdate
    $updates = Get-WindowsUpdate

    if ($updates) {
        Write-Output "Instalando todas as atualizacoes disponiveis de forma silenciosa..."
        Get-WindowsUpdate -AcceptAll -Install -IgnoreReboot -Confirm:$false
        Write-Output "Atualizacoes instaladas com sucesso. Reinicie manualmente se necessario."
    } else {
        Write-Output "Nenhuma atualizacao disponivel no momento."
    }
}

# 8. Execucao principal do Script
Write-Output "Iniciando o processo de atualizacao..."
Update-PowerShellGet
Install-PSWindowsUpdate

# 9. Reset do Windows Update antes da instalacao das atualizacoes
Reset-WindowsUpdate

# 10. Instalar as atualizacoes disponiveis
Install-WindowsUpdates
Write-Output "Processo concluido."
