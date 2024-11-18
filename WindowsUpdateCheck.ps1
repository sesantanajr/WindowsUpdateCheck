# Configuracoes iniciais
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'

# Escolha o sistema operacional: 'Windows10' ou 'Windows11'
# Defina o valor abaixo antes de executar o script
$targetOS = "Windows10" # Ou "Windows11"

# Versoes alvo para cada sistema operacional
if ($targetOS -eq "Windows10") {
    $minVersion = "19044.5131"
    $maxVersion = "19045.5131"
    $taskName = "Windows10CheckUpdate"
} elseif ($targetOS -eq "Windows11") {
    $minVersion = "26100.1000"
    $maxVersion = "26100.2314"
    $taskName = "Windows11CheckUpdate"
} else {
    Write-Output "Erro: Sistema operacional alvo nao definido corretamente. Use 'Windows10' ou 'Windows11'."
    exit 1
}

# Diretorio e paths
$baseDirectory = Join-Path $env:ProgramData "WindowsUpdateScript"
$scriptPath = Join-Path $baseDirectory "$taskName.ps1"
$logFile = Join-Path $baseDirectory "$taskName.log"

# Funcao para logging seguro
function Write-LogSafe {
    param ([string]$Message)
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "$timestamp - $Message"
        
        if (-not (Test-Path $logFile)) {
            New-Item -ItemType File -Path $logFile -Force | Out-Null
        }
        
        [System.IO.File]::AppendAllText($logFile, "$logEntry`n")
        Write-Output $logEntry
    }
    catch {
        Write-Output "Erro ao escrever log: $Message"
    }
}

# Funcao para verificar a versao do Windows e sistema operacional correto
function Test-WindowsOS {
    try {
        # Obtem informacoes detalhadas da build do Windows
        $windowsInfo = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
        $currentBuild = $windowsInfo.CurrentBuild
        $updateBuild = $windowsInfo.UBR
        $fullBuildNumber = "$currentBuild.$updateBuild"
        
        Write-LogSafe "Versao atual do Windows: $fullBuildNumber"

        # Checa se a build comeca com '1' (Windows 10) ou '2' (Windows 11)
        if ($targetOS -eq "Windows10" -and $currentBuild -like "1*") {
            Write-LogSafe "Validado: Este e um sistema Windows 10."
        } elseif ($targetOS -eq "Windows11" -and $currentBuild -like "2*") {
            Write-LogSafe "Validado: Este e um sistema Windows 11."
        } else {
            Write-LogSafe "Erro: Sistema operacional nao corresponde ao alvo definido ($targetOS)."
            exit 1
        }

        # Converte as strings de versao para objetos [version] para comparacao adequada
        $currentVersion = [version]$fullBuildNumber
        $minVersionObj = [version]$minVersion
        $maxVersionObj = [version]$maxVersion

        # Verifica se a versao atual esta dentro do intervalo especificado
        if ($currentVersion -ge $minVersionObj -and $currentVersion -le $maxVersionObj) {
            Write-LogSafe "Sistema esta em conformidade com a versao requerida."
            return $false # Nao precisa atualizar
        } else {
            Write-LogSafe "Sistema precisa ser atualizado. Versao atual: $fullBuildNumber"
            return $true # Precisa atualizar
        }
    }
    catch {
        Write-LogSafe "Erro ao verificar sistema operacional e versao: $($_.Exception.Message)"
        exit 1
    }
}

# Funcao para inicializar o ambiente
function Initialize-Environment {
    try {
        Write-LogSafe "Inicializando ambiente..."
        if (-not (Test-Path -Path $baseDirectory)) {
            New-Item -Path $baseDirectory -ItemType Directory -Force | Out-Null
            Write-LogSafe "Diretorio base criado: $baseDirectory"
        }

        # Copia o script para o diretorio base
        $scriptPathSource = $MyInvocation.MyCommand.Path
        if (-not $scriptPathSource) {
            $scriptPathSource = (Get-Command -Name $PSCommandPath).Source
            Write-LogSafe "Usando caminho alternativo para o script: $scriptPathSource"
        }

        if ($scriptPathSource -and (Test-Path $scriptPathSource)) {
            Copy-Item -Path $scriptPathSource -Destination $scriptPath -Force
            Write-LogSafe "Script copiado para o destino: $scriptPath"
        } else {
            Write-LogSafe "Erro: Caminho do script nao encontrado."
            exit 1
        }

        Write-LogSafe "Ambiente inicializado com sucesso."
    }
    catch {
        Write-LogSafe "Erro ao inicializar ambiente: $($_.Exception.Message)"
        exit 1
    }
}

# Funcao para agendar tarefa
function Register-UpdateTask {
    try {
        $taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
        $taskTrigger = New-ScheduledTaskTrigger -Daily -At "03:00" -DaysInterval 30
        $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden
        $taskPrincipal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest

        # Remove tarefa existente
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

        # Registra nova tarefa
        Register-ScheduledTask -TaskName $taskName `
            -Action $taskAction `
            -Trigger $taskTrigger `
            -Settings $taskSettings `
            -Principal $taskPrincipal `
            -Description "Verifica e aplica atualizacoes do Windows mensalmente" | Out-Null

        Write-LogSafe "Tarefa agendada com sucesso."
    }
    catch {
        Write-LogSafe "Erro ao agendar tarefa: $($_.Exception.Message)"
        exit 1
    }
}

# Execucao principal
try {
    Initialize-Environment
    
    # Verifica sistema operacional e versao
    if (Test-WindowsOS) {
        Write-LogSafe "Iniciando processo de atualizacao devido a versao do Windows."
        # Aqui voce pode incluir funcoes para atualizar ou limpar caches, etc.
        Register-UpdateTask
    } else {
        Write-LogSafe "Sistema ja esta na versao correta. Nenhuma acao necessaria."
        Register-UpdateTask
    }
}
catch {
    Write-LogSafe "Erro fatal durante execucao: $($_.Exception.Message)"
    exit 1
}
