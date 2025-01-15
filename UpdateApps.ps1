# Inicio do script
Write-Output "Iniciando o processo de atualizacao..."

# Funcao para verificar se um comando esta disponivel no sistema
function Is-CommandAvailable {
    param ([string]$Command)
    return Get-Command $Command -ErrorAction SilentlyContinue
}

# Funcao para garantir execucao como administrador
function EnsureAdminContext {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Output "Este script precisa ser executado como administrador."
        Exit 1
    }
}

# Funcao para instalar ou atualizar o Chocolatey
function InstallOrUpdateChocolatey {
    Write-Output "Verificando se o Chocolatey esta instalado..."
    if (!(Is-CommandAvailable "choco.exe")) {
        Write-Output "Chocolatey nao encontrado. Instalando Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Output "Chocolatey instalado com sucesso."
    } else {
        Write-Output "Chocolatey ja esta instalado. Verificando atualizacoes..."
        choco upgrade chocolatey -y --accept-license | Out-Null
        Write-Output "Chocolatey atualizado com sucesso."
    }
}

# Atualizar aplicativos da Microsoft Store usando DISM
function UpdateMicrosoftStoreApps {
    Write-Output "Atualizando pacotes da Microsoft Store..."
    try {
        if (Is-CommandAvailable "dism.exe") {
            $ProvisionedPackages = dism /Online /Get-ProvisionedAppxPackages | Select-String -Pattern "PackageName"
            foreach ($Package in $ProvisionedPackages) {
                $PackageName = $Package -replace "PackageName : ", ""
                Write-Output "Atualizando pacote: $PackageName"
                dism /Online /Remove-ProvisionedAppxPackage /PackageName:$PackageName | Out-Null
                dism /Online /Add-ProvisionedAppxPackage /PackagePath:$PackageName /SkipLicense | Out-Null
            }
            Write-Output "Atualizacao da Microsoft Store concluida."
        } else {
            Write-Output "O comando DISM nao esta disponivel. Verifique se ele esta habilitado no sistema."
        }
    } Catch {
        Write-Output "Erro ao atualizar pacotes da Microsoft Store: $_"
    }
}

# Atualizar aplicativos via Winget
function UpdateWingetApps {
    Write-Output "Atualizando pacotes via Winget..."
    try {
        if (Is-CommandAvailable "winget.exe") {
            # Listar pacotes disponiveis para atualizacao
            $Updates = winget list --source winget | Where-Object { $_ -match 'Upgrade Available' }
            if ($null -eq $Updates) {
                Write-Output "Nenhum pacote para atualizar via Winget."
            } else {
                winget upgrade --all --include-pinned --include-unknown --accept-source-agreements --accept-package-agreements

                # Tratamento especial para pacotes fixados como Chocolatey.Chocolatey
                if ($Updates -match 'Chocolatey.Chocolatey') {
                    Write-Output "Pacote fixado detectado: Chocolatey.Chocolatey. Atualize manualmente conforme necessario."
                }
            }
            Write-Output "Atualizacao via Winget concluida."
        } else {
            Write-Output "Winget nao esta instalado. Ignorando..."
        }
    } Catch {
        Write-Output "Erro ao atualizar pacotes via Winget: $_"
    }
}

# Atualizar aplicativos via Chocolatey
function UpdateChocolateyApps {
    InstallOrUpdateChocolatey

    Write-Output "Verificando pacotes desatualizados no Chocolatey..."
    try {
        # Listar pacotes desatualizados
        $OutdatedPackages = choco outdated | Select-String 'Outdated Packages'
        
        if ($null -eq $OutdatedPackages) {
            Write-Output "Nenhum pacote desatualizado encontrado no Chocolatey."
        } else {
            # Resolver dependencias antes de atualizar
            choco install all --force-dependencies -y | Out-Null
            
            # Atualizar pacotes desatualizados
            choco upgrade all -y --ignore-unfound --accept-license | Out-Null
            Write-Output "Atualizacao via Chocolatey concluida."
        }
    } Catch {
        Write-Output "Erro ao atualizar pacotes via Chocolatey: $_"
    }
}

# Garantir execucao como administrador
EnsureAdminContext

# Executar todas as funcoes em sequencia
UpdateMicrosoftStoreApps
UpdateWingetApps
UpdateChocolateyApps

Write-Output "Processo de atualizacao concluido com sucesso."
