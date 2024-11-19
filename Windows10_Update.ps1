# Bloquear Gerenciamento de Políticas de Windows Update pelo Intune
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "ManagePreviewBuilds" -Value 2 -Type DWord

# Bloquear Atualização para Windows 11 e Forçar Última Build do Windows 10 (22H2)
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "TargetReleaseVersion" -Value 1 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "TargetReleaseVersionInfo" -Value "22H2" -Type String

# Configurar Atualizações Automáticas (Forçar Download e Instalação)
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -Value 4 -Type DWord

# Permitir Atualizações de Drivers
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "AllowAutoUpdateDrivers" -Value 1 -Type DWord

# Permitir Atualizações Opcionais
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "AllowMUUpdateService" -Value 1 -Type DWord

# Habilitar Atualizações de Firmware e BIOS via Windows Update (se suportado)
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "AllowFirmwareUpdates" -Value 1 -Type DWord

# Forçar Atualizações de Segurança e Outros Produtos Microsoft
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "DoNotConnectToWindowsUpdateInternetLocations" -Value 0 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "MicrosoftUpdateServiceEnabled" -Value 1 -Type DWord

# Habilitar Atualizações Frequentes (checar a cada 3 horas)
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "DetectionFrequency" -Value 3 -Type DWord

# Configurar Horário Ativo para Evitar Reinicializações Durante o Trabalho (9h às 22h)
New-Item -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "ActiveHoursStart" -Value 9 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "ActiveHoursEnd" -Value 22 -Type DWord

# Forçar Atualização de Aplicativos da Microsoft Store
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore" -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore" -Name "AutoDownload" -Value 4 -Type DWord

# Forçar Atualizações Imediatas (Sem Espera)
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AutoInstallMinorUpdates" -Value 1 -Type DWord

# Exibir Notificações de Atualizações
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "SetUpdateNotificationLevel" -Value 1 -Type DWord

# Garantir que Configurações de Grupo não Impedem Atualizações
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "NoAutoUpdate" -Value 0 -Type DWord

# Desabilitar Configurações de Windows Update Forçadas pelo Intune
New-Item -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update" -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update" -Name "DisableDualScan" -Value 1 -Type DWord
