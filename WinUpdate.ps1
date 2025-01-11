# Reinicia os serviços relacionados ao Windows Update
Write-Host "Parando serviços relacionados ao Windows Update..."
Stop-Service -Name wuauserv -Force
Stop-Service -Name bits -Force
Stop-Service -Name cryptsvc -Force

Write-Host "Limpando cache do Windows Update..."
Remove-Item -Path "C:\Windows\SoftwareDistribution" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\System32\catroot2" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Reiniciando serviços relacionados ao Windows Update..."
Start-Service -Name wuauserv
Start-Service -Name bits
Start-Service -Name cryptsvc

# Repara componentes do Windows Update
Write-Host "Executando reparos nos componentes do Windows Update..."
DISM /Online /Cleanup-Image /RestoreHealth
sfc /scannow

# Força a verificação e instalação de atualizações pendentes
Write-Host "Verificando e instalando atualizações pendentes..."
Install-Module PSWindowsUpdate -Force -ErrorAction SilentlyContinue
Import-Module PSWindowsUpdate
Get-WindowsUpdate -Install -AcceptAll -AutoReboot

# Verifica a versão atual do sistema operacional e força atualização para a última versão, se necessário
$CurrentVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ReleaseId
$LatestVersion = "24H2" # Substitua pelo número da versão mais recente disponível

if ($CurrentVersion -lt $LatestVersion) {
    Write-Host "Atualizando para a versão mais recente do Windows..."
    $DownloadURL = "https://go.microsoft.com/fwlink/?LinkID=799445" # Assistente de Atualização do Windows
    $InstallerPath = "$env:TEMP\WindowsUpgradeAssistant.exe"
    Invoke-WebRequest -Uri $DownloadURL -OutFile $InstallerPath
    Start-Process -FilePath $InstallerPath -ArgumentList "/quietinstall /forcerestart" -Wait
} else {
    Write-Host "O sistema já está na versão mais recente."
}

Write-Host "Processo concluído!"
