param (
    [string]$windowsAdminUsername,
    [string]$windowsAdminPassword,
    [string]$isoDownloadsBase64Json,
    [string]$artifactsBaseUrl
)

$TranscriptFile = "c:\Bootstrap.log"
Start-Transcript -Path $TranscriptFile

# TODO: Set time zone from argument
Set-TimeZone -Id "Central Europe Standard Time"

# Disabling Windows Server Manager Scheduled Task
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask

# Formatting VMs disk
Write-Host "Formatting VMs disk"
$disk = (Get-Disk | Where-Object partitionstyle -eq 'raw')[0]
$driveLetter = "F"
$label = "VMsDisk"
$disk | Initialize-Disk -PartitionStyle MBR -PassThru | `
    New-Partition -UseMaximumSize -DriveLetter $driveLetter | `
    Format-Volume -FileSystem NTFS -NewFileSystemLabel $label -Confirm:$false -Force

# Extending C:\ partition to the maximum size
Write-Host "Extending C:\ partition to the maximum size"
Resize-Partition -DriveLetter C -Size $(Get-PartitionSupportedSize -DriveLetter C).SizeMax

# Downloading scripts
Write-Host "Downloading scripts"
$scriptsDir = "F:\Scripts"
New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
Invoke-WebRequest ($artifactsBaseUrl + "scripts/RunAfterRestart.ps1") -OutFile $scriptsDir\RunAfterRestart.ps1

# Disable Microsoft Edge sidebar
Write-Host "Disabling Microsoft Edge sidebar"
$RegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$Name = 'HubsSidebarEnabled'
$Value = '00000000'
# Create the key if it does not exist
If (-NOT (Test-Path $RegistryPath)) {
    New-Item -Path $RegistryPath -Force | Out-Null
}
New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force

# Disable Microsoft Edge first-run Welcome screen
Write-Host "Disabling Microsoft Edge first-run Welcome screen"
$RegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$Name = 'HideFirstRunExperience'
$Value = '00000001'
# Create the key if it does not exist
If (-NOT (Test-Path $RegistryPath)) {
    New-Item -Path $RegistryPath -Force | Out-Null
}
New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force

# Set Diagnostic Data settings
Write-Host "Setting Diagnostic Data settings via registry"
$telemetryPath = "HKLM:\Software\Policies\Microsoft\Windows\DataCollection"
$telemetryProperty = "AllowTelemetry"
$telemetryValue = 0 # 0 - Disable telemetry
# Create the registry key and set the value for AllowTelemetry
if (-not (Test-Path $telemetryPath)) {
    New-Item -Path $telemetryPath -Force | Out-Null
}
Set-ItemProperty -Path $telemetryPath -Name $telemetryProperty -Value $telemetryValue

$oobePath = "HKLM:\Software\Policies\Microsoft\Windows\OOBE"
$oobeProperty = "DisablePrivacyExperience"
$oobeValue = 1
# Create the registry key and set the value for DisablePrivacyExperience
if (-not (Test-Path $oobePath)) {
    New-Item -Path $oobePath -Force | Out-Null
}
Set-ItemProperty -Path $oobePath -Name $oobeProperty -Value $oobeValue

Write-Host "Registry keys and values for Diagnostic Data settings have been set successfully."

# Install AutomatedLab
Write-Host "Installing AutomatedLab"
Install-PackageProvider Nuget -Force -Confirm:$False
Install-Module PSFramework -SkipPublisherCheck -Force -Confirm:$False -AllowClobber
Install-Module AutomatedLab -SkipPublisherCheck -Force -Confirm:$False -AllowClobber

#  Disable (which is already the default) and in addition skip dialog
[Environment]::SetEnvironmentVariable('AUTOMATEDLAB_TELEMETRY_OPTIN', 'false', 'Machine')
$env:AUTOMATEDLAB_TELEMETRY_OPTIN = 'false'

# Pre-configure Lab Host Remoting
Enable-LabHostRemoting -Force

New-LabSourcesFolder -DriveLetter F



<#
Write-Host "Installing PowerShell 7"
$ProgressPreference = 'SilentlyContinue'
$url = "https://github.com/PowerShell/PowerShell/releases/latest"
$latestVersion = (Invoke-WebRequest -UseBasicParsing -Uri $url).Content | Select-String -Pattern "v[0-9]+\.[0-9]+\.[0-9]+" | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
$downloadUrl = "https://github.com/PowerShell/PowerShell/releases/download/$latestVersion/PowerShell-$($latestVersion.Substring(1,5))-win-x64.msi"
Invoke-WebRequest -UseBasicParsing -Uri $downloadUrl -OutFile .\PowerShell7.msi
Start-Process msiexec.exe -Wait -ArgumentList '/I PowerShell7.msi /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1'
Remove-Item .\PowerShell7.msi
#>



# mozna presunout stahovani iso do RunAfterRestart.ps1


# Download ISOs
Write-Host "Downloading ISOs..."
# Decode base64 and convert JSON string to PowerShell object
$isoList = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($isoDownloadsBase64Json)) | ConvertFrom-Json
$targetDir = "F:\LabSources\ISOs"

foreach ($iso in $isoList) {
    $filePath = Join-Path $targetDir $iso.name
    Write-Host "Downloading $iso.isoDownloadUrl to $filePath"
    Start-BitsTransfer -Source $iso.isoDownloadUrl -Destination $filePath
}



# Install Hyper-V and reboot
Write-Host "Installing Hyper-V and restart"
Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
Install-WindowsFeature -Name Hyper-V -IncludeAllSubFeature -IncludeManagementTools -Restart


# Register schedule task to run after system reboot
Write-Host "Registering scheduled task to run after system reboot"
$Trigger = New-ScheduledTaskTrigger -AtStartup
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"$scriptsDir\RunAfterRestart.ps1`" -windowsAdminUsername `"$windowsAdminUsername`" -windowsAdminPassword `"$windowsAdminPassword`""
Register-ScheduledTask -TaskName "RunOnceAfterRestart" -Trigger $Trigger -User SYSTEM -Action $Action -RunLevel "Highest" -Force
Write-Host "Registered scheduled task 'RunOnceAfterRestart' to run after system reboot."

Stop-Transcript

# Restart computer
#Restart-Computer
