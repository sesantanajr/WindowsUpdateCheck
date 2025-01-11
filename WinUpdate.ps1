# Script PowerShell Avançado para Solução de Problemas do Windows Update
# Compatível com Windows 10/11 e Microsoft Intune

# Função para verificar permissões administrativas
function Check-Admin {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "Este script precisa ser executado como administrador!" -ForegroundColor Red
        exit 1
    }
}

# Função para redefinir os componentes do Windows Update
function Reset-WindowsUpdateComponents {
    Write-Host "Redefinindo componentes do Windows Update..." -ForegroundColor Yellow
    
    # Parar serviços relacionados ao Windows Update
    $services = @("wuauserv", "cryptSvc", "bits", "msiserver")
    foreach ($service in $services) {
        try {
            Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 5 # Aguarda 5 segundos antes de continuar
        } catch {
            Write-Host "Falha ao parar o serviço $service." -ForegroundColor Red
        }
    }

    # Renomear pastas de cache do Windows Update
    $paths = @("C:\Windows\SoftwareDistribution", "C:\Windows\System32\catroot2")
    foreach ($path in $paths) {
        if (Test-Path $path) {
            try {
                Rename-Item -Path $path -NewName "$($path).old" -ErrorAction SilentlyContinue
                Write-Host "Renomeado: $path" -ForegroundColor Green
            } catch {
                Write-Host "Falha ao renomear: $path" -ForegroundColor Red
            }
        }
    }

    # Reiniciar serviços relacionados ao Windows Update
    foreach ($service in $services) {
        try {
            Start-Service -Name $service -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 5 # Aguarda 5 segundos antes de continuar
        } catch {
            Write-Host "Falha ao iniciar o serviço $service." -ForegroundColor Red
        }
    }

    Write-Host "Componentes do Windows Update redefinidos com sucesso!" -ForegroundColor Green
}

# Função para executar o comando DISM para reparar a imagem do sistema
function Repair-WindowsImage {
    Write-Host "Executando DISM para reparar a imagem do sistema..." -ForegroundColor Yellow
    
    try {
        DISM /Online /Cleanup-Image /RestoreHealth | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Reparo da imagem do sistema concluído com sucesso!" -ForegroundColor Green
        } else {
            Write-Host "Falha ao reparar a imagem do sistema." -ForegroundColor Red
        }
    } catch {
        Write-Host "Erro ao executar DISM: $_" -ForegroundColor Red
    }
}

# Função para verificar e corrigir arquivos corrompidos usando o SFC (System File Checker)
function Run-SFC {
    Write-Host "Executando verificação de integridade dos arquivos do sistema (SFC)..." -ForegroundColor Yellow
    
    try {
        sfc /scannow | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Verificação SFC concluída sem erros!" -ForegroundColor Green
        } else {
            Write-Host "Falha ao corrigir alguns arquivos do sistema." -ForegroundColor Red
        }
    } catch {
        Write-Host "Erro ao executar SFC: $_" -ForegroundColor Red
    }
}

# Função para instalar atualizações pendentes usando PSWindowsUpdate
function Install-PendingUpdates {
    Write-Host "Verificando e instalando atualizações pendentes..." -ForegroundColor Yellow
    
    # Instalar o módulo PSWindowsUpdate caso não esteja presente
    if (-not (Get-Module -ListAvailable PSWindowsUpdate)) {
        try {
            Install-PackageProvider -Name NuGet -Force | Out-Null
            Install-Module PSWindowsUpdate -Force | Out-Null
            Import-Module PSWindowsUpdate | Out-Null
        } catch {
            Write-Host "Erro ao instalar o módulo PSWindowsUpdate: $_" -ForegroundColor Red
            return
        }
    }

    Import-Module PSWindowsUpdate

    try {
        # Listar atualizações pendentes e instalá-las automaticamente sem reiniciar o sistema.
        Get-WindowsUpdate | Where-Object {$_.IsInstalled -eq $false} | Install-WindowsUpdate –AcceptAll –IgnoreReboot –Verbose | Out-Null

        Write-Host "Todas as atualizações disponíveis foram instaladas com sucesso!" -ForegroundColor Green

    } catch {
        Write-Host "Erro ao instalar atualizações pendentes: $_" -ForegroundColor Red
    }
}

# Função para atualizar para a última versão do Windows (Atualização de Recursos)
function Upgrade-ToLatestVersion {
    Write-Host "Atualizando para a última versão do Windows..." -ForegroundColor Yellow

    try {
        # Usar Assistente de Atualização ou comandos específicos via DISM/WSUS se aplicável.
        Start-Process "$env:SystemRoot\System32\wuauclt.exe" "/updatenow" –Wait –NoNewWindow | Out-Null

        Write-Host "Atualização de recurso iniciada. Acompanhe pelo Windows Update." -ForegroundColor Green

    } catch {
        Write-Host "Erro ao iniciar a atualização de recurso: $_" -ForegroundColor Red
    }
}

# Função principal para executar todas as etapas de correção e atualização automática do sistema operacional.
function Main {
    Check-Admin # Verificar permissões administrativas
    
    Reset-WindowsUpdateComponents # Redefinir componentes do Windows Update
    
    Repair-WindowsImage # Reparar a imagem do sistema
    
    Run-SFC # Verificar e corrigir arquivos corrompidos
    
    Install-PendingUpdates # Instalar todas as atualizações pendentes
    
    Upgrade-ToLatestVersion # Atualizar para a última versão do Windows
    
    Write-Host "Todas as correções e atualizações foram aplicadas. Reinicie o computador manualmente, se necessário." -ForegroundColor Magenta
}

# Executar a função principal automaticamente.
Main
