<#
.SYNOPSIS
    Script completo para corrigir problemas de Windows Update,
    instalar/habilitar NetFx3 e NetFx4, remover chaves de pausa,
    limpar/renomear SoftwareDistribution/catroot2,
    rodar DISM/SFC, e instalar atualizacoes (Software/Driver).

.DESCRIPTION
    1) Mata processos (tiworker, TrustedInstaller) que possam segurar as pastas.
    2) Tenta renomear SoftwareDistribution e catroot2 (5 tentativas).
    3) Habilita .NET 3.5 e .NET 4.x se estiver desabilitado.
    4) Executa Troubleshooter, DISM e SFC (opcional).
    5) Remove chaves de pausa do Registro.
    6) Instala atualizacoes de software e driver separadamente.

.NOTES
    Autor: Tony (by ChatGPT)
    Data: 24/01/2025
#>

Param(
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs",

    [Parameter(Mandatory=$false)]
    [switch]$EnableSfc  # Se quiser rodar SFC /scannow
)

# Ajuste se quiser forcar versoes minimas de Windows 10 e 11
$CurrentWin10 = [Version]"10.0.19045.5371"
$CurrentWin11 = [Version]"10.0.26100.2894"

# ===================================================
#  Verifica se estamos em modo Admin
# ===================================================
Function Test-Admin {
    try {
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        return $isAdmin
    }
    catch {
        return $false
    }
}

If (-not (Test-Admin)) {
    Write-Host "Este script precisa ser executado em modo Administrador. Tentando elevar..."
    Start-Process PowerShell -ArgumentList ("-ExecutionPolicy Bypass -File `"" + $PSCommandPath + "`" " + $PSBoundParameters.ForEach({ ' -'+$_ }) ) -Verb RunAs
    Return
}

# Cria pasta de log se nao existir
If (-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

# Inicia transcript
$TranscriptFile = Join-Path $LogPath "#WindowsUpdates-FullFix.log"
Start-Transcript -Path $TranscriptFile
Write-Output "=== [INICIO] Script FULL FIX Windows Update (Com NetFx) ... ==="

# ===================================================
#  1) Habilitar .NET 3.5 e .NET 4.7+ (NetFx4-AdvSrvs)
# ===================================================
Function Ensure-NetFeature {
    Param([string[]]$Features)
    foreach ($feature in $Features) {
        try {
            $featureInfo = Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction SilentlyContinue
            if ($featureInfo -and $featureInfo.State -eq 'Disabled') {
                Write-Output "Habilitando $($feature)..."
                Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart | Out-Null
            }
            else {
                Write-Output "$($feature) ja esta habilitado OU nao disponivel."
            }
        }
        catch {
            Write-Output "Falha ao habilitar $($feature): $($Error[0])"
        }
    }
}

Write-Output "Verificando e habilitando NetFx3 e NetFx4-AdvSrvs se necessario..."
Ensure-NetFeature -Features @("NetFx3","NetFx4-AdvSrvs")

# ===================================================
#  2) Parar servicos e matar processos do Windows Update
# ===================================================
Write-Output "Parando servicos e matando processos do Windows Update..."

$servicesToStop = "wuauserv","cryptSvc","bits","msiserver","TrustedInstaller"
foreach ($svc in $servicesToStop) {
    try {
        $serviceObj = Get-Service -Name $svc -ErrorAction SilentlyContinue
        If ($serviceObj -and $serviceObj.Status -eq 'Running') {
            Write-Output "Parando servico: $($svc)"
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-Output "Falha ao parar servico $($svc): $($Error[0])"
    }
}

# Matar processos (tiworker, TrustedInstaller, wuauclt, etc.)
$processesToKill = "tiworker","trustedinstaller","wuauclt"
foreach ($p in $processesToKill) {
    $procList = Get-Process -Name $p -ErrorAction SilentlyContinue
    foreach ($proc in $procList) {
        try {
            Write-Output "Matando processo: $($proc.Name) (PID: $($proc.Id))"
            $proc.Kill()
        }
        catch {
            Write-Output "Falha ao matar processo $($proc.Name): $($Error[0])"
        }
    }
}

Start-Sleep -Seconds 2

# ===================================================
#  3) Renomear SoftwareDistribution / catroot2 (5 tentativas)
# ===================================================
Function Cleanup-OldFolder {
    Param([string]$FolderPath)
    $folders = Get-ChildItem -Path (Split-Path $FolderPath) -Directory -Filter "$(Split-Path $FolderPath -Leaf).old*" -ErrorAction SilentlyContinue
    foreach ($f in $folders) {
        try {
            Write-Output "Apagando pasta antiga: $($f.FullName)"
            Remove-Item -Path $f.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
        catch {
            Write-Output "Falha ao remover pasta antiga $($f.FullName): $($Error[0])"
        }
    }
}

Function Force-RenameFolder {
    Param(
        [string]$OriginalPath,
        [string]$Prefix
    )
    $newName = $Prefix + ".old_{0}" -f (Get-Date -Format 'yyyyMMddHHmmss')
    $newPath = Join-Path (Split-Path $OriginalPath) $newName

    If (Test-Path $OriginalPath) {
        for ($i=1; $i -le 5; $i++) {
            Write-Output "Tentando renomear ($i/5) $($OriginalPath) -> $($newPath)"
            try {
                Rename-Item -Path $OriginalPath -NewName $newName -Force
                Write-Output "Renomeado com sucesso!"
                break
            }
            catch {
                Write-Output "Falha ao renomear (tentativa $i): $($Error[0])"
                Write-Output "Executando takeown + icacls..."
                try {
                    takeown /f "$OriginalPath" /r /d y | Out-Null
                    icacls "$OriginalPath" /grant Administrators:F /t | Out-Null
                    Start-Sleep -Seconds 2
                }
                catch {
                    Write-Output "Falha ao tomar posse: $($Error[0])"
                }
            }
        }
    }
    else {
        Write-Output "Pasta $($OriginalPath) nao existe, prosseguindo..."
    }
}

$SoftwareDistribution = "C:\Windows\SoftwareDistribution"
$Catroot2 = "C:\Windows\System32\catroot2"

Cleanup-OldFolder -FolderPath $SoftwareDistribution
Cleanup-OldFolder -FolderPath $Catroot2

Force-RenameFolder -OriginalPath $SoftwareDistribution -Prefix "SoftwareDistribution"
Force-RenameFolder -OriginalPath $Catroot2             -Prefix "catroot2"

# ===================================================
#  4) Re-registrar DLLs do Windows Update
# ===================================================
$dlls = @(
    "atl.dll","urlmon.dll","mshtml.dll","shdocvw.dll","browseui.dll","jscript.dll",
    "vbscript.dll","scrrun.dll","msxml.dll","msxml3.dll","msxml6.dll","actxprxy.dll",
    "softpub.dll","wintrust.dll","initpki.dll","dssenh.dll","rsaenh.dll","gpkcsp.dll",
    "sccbase.dll","slbcsp.dll","cryptdlg.dll","oleaut32.dll","ole32.dll","shell32.dll",
    "wuapi.dll","wuaueng.dll","wuaueng2.dll","wucltui.dll","wups.dll","wups2.dll",
    "wuweb.dll","qmgr.dll","qmgrprxy.dll","wucltux.dll","muweb.dll","wuwebv.dll"
)
Write-Output "Re-registrando DLLs do Windows Update..."
foreach ($dll in $dlls) {
    $dllPath = Join-Path $env:SystemRoot "System32\$dll"
    if (Test-Path $dllPath) {
        try {
            regsvr32.exe /s $dllPath
        }
        catch {
            Write-Output "Falha ao registrar $($dllPath): $($Error[0])"
        }
    }
}

# ===================================================
#  5) Iniciar servicos novamente
# ===================================================
Write-Output "Iniciando servicos do Windows Update novamente..."
foreach ($svc in $servicesToStop) {
    try {
        $serviceObj = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($serviceObj -and $serviceObj.Status -ne 'Running') {
            Write-Output "Iniciando servico: $($svc)"
            Start-Service -Name $svc -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-Output "Falha ao iniciar servico $($svc): $($Error[0])"
    }
}

# ===================================================
#  6) Executar Troubleshooter do Windows Update
# ===================================================
try {
    $TroubleshooterPath = "C:\Windows\diagnostics\system\WindowsUpdate"
    If (Test-Path $TroubleshooterPath) {
        Write-Output "Executando Solucionador de Problemas do Windows Update..."
        Get-TroubleshootingPack -Path $TroubleshooterPath | Invoke-TroubleshootingPack -Unattended
    }
    else {
        Write-Output "Diretorio do Troubleshooter nao encontrado em $($TroubleshooterPath)."
    }
}
catch {
    Write-Output "Falha ao executar o Solucionador de Problemas: $($Error[0])"
}

# ===================================================
#  7) DISM /RestoreHealth e (Opcional) SFC
# ===================================================
try {
    Write-Output "Executando DISM /RestoreHealth..."
    $DismLog = Join-Path $LogPath "#DISM.log"
    Repair-WindowsImage -RestoreHealth -NoRestart -Online -LogPath $DismLog -Verbose -ErrorAction Continue
}
catch {
    Write-Output "Falha ao executar DISM: $($Error[0])"
}

If ($EnableSfc) {
    try {
        Write-Output "Executando SFC /scannow..."
        sfc /scannow | Out-Null
    }
    catch {
        Write-Output "Falha ao executar SFC /scannow: $($Error[0])"
    }
}

# ===================================================
#  8) Remover chaves de pausa/bloqueio no Registro
# ===================================================
Write-Output "Removendo chaves/valores que possam bloquear updates..."

Function Remove-RegKeyIfExists {
    Param([string]$KeyPath)
    If (Test-Path $KeyPath) {
        try {
            Write-Output "Removendo chave de registro: $($KeyPath)"
            Remove-Item -Path $KeyPath -Recurse -Force -Verbose
        }
        catch {
            Write-Output "Falha ao remover $($KeyPath): $($Error[0])"
        }
    }
    else {
        Write-Output "Chave $($KeyPath) nao existe. Prosseguindo..."
    }
}

Function Remove-RegValueIfExists {
    Param([string]$KeyPath, [string]$ValueName)
    If (Test-Path $KeyPath) {
        $exists = (Get-Item $KeyPath -EA Ignore).Property -contains $ValueName
        If ($exists) {
            try {
                Write-Output "Removendo valor $($ValueName) de $($KeyPath)"
                Remove-ItemProperty -Path $KeyPath -Name $ValueName -Verbose -ErrorAction SilentlyContinue
            }
            catch {
                Write-Output "Falha ao remover valor $($ValueName) em $($KeyPath): $($Error[0])"
            }
        }
    }
}

Function Set-RegValue {
    Param([string]$KeyPath, [string]$ValueName, [Object]$ValueData, [string]$Type = "DWORD")
    try {
        If (-not (Test-Path $KeyPath)) {
            Write-Output "Chave $($KeyPath) nao existe, criando..."
            New-Item -Path $KeyPath -Force | Out-Null
        }
        Write-Output "Definindo $($ValueName) = $($ValueData) em $($KeyPath)"
        Set-ItemProperty -Path $KeyPath -Name $ValueName -Value $ValueData -Type $Type -Verbose
    }
    catch {
        Write-Output "Falha ao definir valor $($ValueName) em $($KeyPath): $($Error[0])"
    }
}

$WUPolicyKey      = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$keyWUSettings    = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings"
$keyPolicyManager = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update"
$keyDataCollection= "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
$keyGWX           = "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Appraiser\GWX"

Remove-RegKeyIfExists -KeyPath $WUPolicyKey

Remove-RegValueIfExists -KeyPath $keyWUSettings -ValueName "PausedQualityDate"
Remove-RegValueIfExists -KeyPath $keyWUSettings -ValueName "PausedFeatureDate"
Remove-RegValueIfExists -KeyPath $keyPolicyManager -ValueName "PauseQualityUpdatesStartTime"
Remove-RegValueIfExists -KeyPath $keyPolicyManager -ValueName "PauseQualityUpdatesStartTime_ProviderSet"
Remove-RegValueIfExists -KeyPath $keyPolicyManager -ValueName "PauseQualityUpdatesStartTime_WinningProvider"
Remove-RegValueIfExists -KeyPath $keyPolicyManager -ValueName "PauseFeatureUpdatesStartTime"
Remove-RegValueIfExists -KeyPath $keyPolicyManager -ValueName "PauseFeatureUpdatesStartTime_ProviderSet"
Remove-RegValueIfExists -KeyPath $keyPolicyManager -ValueName "PauseFeatureUpdatesStartTime_WinningProvider"

Set-RegValue -KeyPath $keyWUSettings    -ValueName "PausedQualityStatus" -ValueData 0
Set-RegValue -KeyPath $keyWUSettings    -ValueName "PausedFeatureStatus" -ValueData 0
Set-RegValue -KeyPath $keyPolicyManager -ValueName "PauseQualityUpdates"  -ValueData 0
Set-RegValue -KeyPath $keyPolicyManager -ValueName "PauseFeatureUpdates"  -ValueData 0
Set-RegValue -KeyPath $keyPolicyManager -ValueName "DeferFeatureUpdatesPeriodInDays" -ValueData 0

Set-RegValue -KeyPath $keyDataCollection -ValueName "AllowDeviceNameInTelemetry"   -ValueData 1
Set-RegValue -KeyPath $keyDataCollection -ValueName "AllowTelemetry_PolicyManager" -ValueData 1

Set-RegValue -KeyPath $keyGWX -ValueName "GStatus" -ValueData 2

Write-Output "Chaves e valores de registro atualizados."

# ===================================================
#  9) Instalar modulos e tentar upgrades
# ===================================================
Try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Write-Output "Verificando se o provedor NuGet esta instalado..."
    $NuGetProv = Get-PackageProvider -Name "NuGet" -ListAvailable -ErrorAction SilentlyContinue
    If (-not $NuGetProv) {
        Write-Output "Instalando provedor NuGet..."
        Install-PackageProvider -Name NuGet -Force -ErrorAction SilentlyContinue
    }
    else {
        Write-Output "NuGet ja esta instalado."
    }
}
Catch {
    Write-Output "Erro ao verificar/instalar NuGet: $($Error[0])"
}

Try {
    Write-Output "Verificando modulo PSWindowsUpdate..."
    $PSWUInstalled = Get-InstalledModule -Name "PSWindowsUpdate" -ErrorAction SilentlyContinue
    If (-not $PSWUInstalled) {
        Write-Output "Instalando PSWindowsUpdate..."
        Install-Module PSWindowsUpdate -Force -Scope AllUsers -ErrorAction SilentlyContinue
    }
    else {
        Write-Output "PSWindowsUpdate ja instalado."
    }
    Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue

    If (Get-Command -Module PSWindowsUpdate -Name Reset-WUComponents -ErrorAction SilentlyContinue) {
        Write-Output "Resetando componentes do Windows Update via PSWindowsUpdate..."
        Reset-WUComponents -ErrorAction SilentlyContinue
    }
}
Catch {
    Write-Output "Falha ao instalar/usar PSWindowsUpdate: $($Error[0])"
}

# Checar se precisa remover bloqueios de Feature Update
Try {
    $OSversionString = (Get-ComputerInfo -Property OsVersion).OsVersion
    $OSversion = [Version]$OSversionString
    Write-Output "Versao do Windows detectada: $($OSversionString)"

    Function Install-ModuleIfMissing {
        Param([string]$ModuleName)
        $installed = Get-InstalledModule -Name $ModuleName -ErrorAction SilentlyContinue
        If (-not $installed) {
            Write-Output "Instalando modulo $($ModuleName)..."
            Install-Module -Name $ModuleName -Force -Scope AllUsers -ErrorAction SilentlyContinue
        }
        else {
            Write-Output "Modulo $($ModuleName) ja esta instalado."
        }
    }

    If ($OSversion.Major -eq 10 -and $OSversion.Minor -eq 0) {
        # Windows 10/11
        If ($OSversion -ge [Version]"10.0.2") {
            # Windows 11
            If ($OSversion -lt $CurrentWin11) {
                Write-Output "Windows 11 abaixo de $($CurrentWin11). Removendo bloqueios de Feature Update..."
                Install-ModuleIfMissing -ModuleName "FU.WhyAmIBlocked"
                Import-Module FU.WhyAmIBlocked -ErrorAction SilentlyContinue
                Get-FUBlocks -ErrorAction SilentlyContinue
            }
            else {
                Write-Output "Windows 11 ja esta na versao $($OSversionString) ou superior."
            }
        }
        else {
            # Windows 10
            If ($OSversion -lt $CurrentWin10) {
                Write-Output "Windows 10 abaixo de $($CurrentWin10). Removendo bloqueios de Feature Update..."
                Install-ModuleIfMissing -ModuleName "FU.WhyAmIBlocked"
                Import-Module FU.WhyAmIBlocked -ErrorAction SilentlyContinue
                Get-FUBlocks -ErrorAction SilentlyContinue
            }
            else {
                Write-Output "Windows 10 ja esta na versao $($OSversionString) ou superior."
            }
        }
    }
    else {
        Write-Output "Sistema nao identificado como Windows 10/11. Prosseguindo..."
    }
}
Catch {
    Write-Output "Falha ao checar/instalar FU.WhyAmIBlocked: $($Error[0])"
}

# ===================================================
#  10) Instalar atualizacoes (Software e Driver)
# ===================================================
Try {
    Write-Output "=== [1/2] Instalando atualizacoes de SOFTWARE... ==="
    $SoftUpdates = Get-WindowsUpdate -Install -AcceptAll -UpdateType Software -IgnoreReboot -ErrorAction SilentlyContinue
    Write-Output "=== [RELATORIO - SOFTWARE] ==="
    if ($SoftUpdates) {
        foreach ($s in $SoftUpdates) {
            Write-Output "Titulo: $($s.Title)"
            Write-Output "KB: $($s.KB)"
            Write-Output "Resultado: $($s.Result)"
            Write-Output "Reboot Requerido: $($s.RebootRequired)"
            Write-Output "-----------------------------"
        }
    }
    else {
        Write-Output "Nenhuma atualizacao SOFTWARE encontrada/instalada."
    }
}
Catch {
    Write-Output "Falha ao checar/instalar (Software) via PSWindowsUpdate: $($Error[0])"
}

Try {
    Write-Output "=== [2/2] Instalando atualizacoes de DRIVER... ==="
    $DrvUpdates = Get-WindowsUpdate -Install -AcceptAll -UpdateType Driver -IgnoreReboot -ErrorAction SilentlyContinue
    Write-Output "=== [RELATORIO - DRIVERS] ==="
    if ($DrvUpdates) {
        foreach ($d in $DrvUpdates) {
            Write-Output "Titulo: $($d.Title)"
            Write-Output "KB: $($d.KB)"
            Write-Output "Resultado: $($d.Result)"
            Write-Output "Reboot Requerido: $($d.RebootRequired)"
            Write-Output "-----------------------------"
        }
    }
    else {
        Write-Output "Nenhuma atualizacao DRIVER encontrada/instalada."
    }
}
Catch {
    Write-Output "Falha ao checar/instalar (Driver) via PSWindowsUpdate: $($Error[0])"
}

Write-Output "=== [FIM] Script FULL FIX Windows Update (Com NetFx) concluido. ==="

Stop-Transcript

# Caso queira reiniciar automaticamente caso haja pendencia, descomente:
# if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
#     Write-Output "Reboot pendente. Reiniciando agora..."
#     Restart-Computer -Force
# }
