# Configurar a política de execução para permitir scripts assinados
Set-ExecutionPolicy RemoteSigned -Force

# Função para verificar e atualizar o módulo PowerShellGet
function Update-PowerShellGet {
    Write-Output "Verificando o módulo PowerShellGet..."
    $currentVersion = (Get-Module -Name PowerShellGet -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version
    $requiredVersion = [Version]"2.2.5"  # Versão mínima recomendada

    if ($currentVersion -lt $requiredVersion) {
        Write-Output "Atualizando PowerShellGet para a versão $requiredVersion..."
        Install-Module -Name PowerShellGet -Force -AllowClobber
        Write-Output "PowerShellGet atualizado com sucesso."
    } else {
        Write-Output "PowerShellGet já está na versão mais recente ($currentVersion)."
    }
}

# Função para verificar e instalar o módulo PSWindowsUpdate
function Install-PSWindowsUpdate {
    Write-Output "Verificando o módulo PSWindowsUpdate..."
    if (!(Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Output "Instalando o módulo PSWindowsUpdate..."
        Install-Module -Name PSWindowsUpdate -Force
        Write-Output "PSWindowsUpdate instalado com sucesso."
    } else {
        Write-Output "O módulo PSWindowsUpdate já está instalado."
    }
}

# Função para listar e instalar atualizações do Windows
function Install-WindowsUpdates {
    Import-Module PSWindowsUpdate

    Write-Output "Procurando por atualizações disponíveis..."
    $updates = Get-WindowsUpdate

    if ($updates) {
        Write-Output "Instalando todas as atualizações disponíveis..."
        Get-WindowsUpdate -AcceptAll -Install -IgnoreReboot
        Write-Output "Atualizações instaladas com sucesso. Reinicie manualmente se necessário."
    } else {
        Write-Output "Nenhuma atualização disponível no momento."
    }
}

# Execução do Script
Write-Output "Iniciando o processo de atualização..."
Update-PowerShellGet
Install-PSWindowsUpdate
Install-WindowsUpdates
Write-Output "Processo concluído."
