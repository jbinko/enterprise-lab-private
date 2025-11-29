param (
    [string]$windowsAdminUsername,
    [string]$windowsAdminPassword,
    [string]$isoDownloadsJson
)

Start-Transcript -Path c:\Bootstrap.log

# Formatting VMs disk
$disk = (Get-Disk | Where-Object partitionstyle -eq 'raw')[0]
$driveLetter = "F"
$label = "VMsDisk"
$disk | Initialize-Disk -PartitionStyle MBR -PassThru | `
    New-Partition -UseMaximumSize -DriveLetter $driveLetter | `
    Format-Volume -FileSystem NTFS -NewFileSystemLabel $label -Confirm:$false -Force

# Extending C:\ partition to the maximum size
Write-Host "Extending C:\ partition to the maximum size"
Resize-Partition -DriveLetter C -Size $(Get-PartitionSupportedSize -DriveLetter C).SizeMax

# Installing tools
Write-Host "Installing PowerShell 7"

$ProgressPreference = 'SilentlyContinue'
$url = "https://github.com/PowerShell/PowerShell/releases/latest"
$latestVersion = (Invoke-WebRequest -UseBasicParsing -Uri $url).Content | Select-String -Pattern "v[0-9]+\.[0-9]+\.[0-9]+" | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
$downloadUrl = "https://github.com/PowerShell/PowerShell/releases/download/$latestVersion/PowerShell-$($latestVersion.Substring(1,5))-win-x64.msi"
Invoke-WebRequest -UseBasicParsing -Uri $downloadUrl -OutFile .\PowerShell7.msi
Start-Process msiexec.exe -Wait -ArgumentList '/I PowerShell7.msi /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1'
Remove-Item .\PowerShell7.msi

# Disable Microsoft Edge sidebar
$RegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$Name = 'HubsSidebarEnabled'
$Value = '00000000'
# Create the key if it does not exist
If (-NOT (Test-Path $RegistryPath)) {
    New-Item -Path $RegistryPath -Force | Out-Null
}
New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force

# Disable Microsoft Edge first-run Welcome screen
$RegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$Name = 'HideFirstRunExperience'
$Value = '00000001'
# Create the key if it does not exist
If (-NOT (Test-Path $RegistryPath)) {
    New-Item -Path $RegistryPath -Force | Out-Null
}
New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force

# Set Diagnostic Data settings

$telemetryPath = "HKLM:\Software\Policies\Microsoft\Windows\DataCollection"
$telemetryProperty = "AllowTelemetry"
$telemetryValue = 3

$oobePath = "HKLM:\Software\Policies\Microsoft\Windows\OOBE"
$oobeProperty = "DisablePrivacyExperience"
$oobeValue = 1

# Create the registry key and set the value for AllowTelemetry
if (-not (Test-Path $telemetryPath)) {
    New-Item -Path $telemetryPath -Force | Out-Null
}
Set-ItemProperty -Path $telemetryPath -Name $telemetryProperty -Value $telemetryValue

# Create the registry key and set the value for DisablePrivacyExperience
if (-not (Test-Path $oobePath)) {
    New-Item -Path $oobePath -Force | Out-Null
}
Set-ItemProperty -Path $oobePath -Name $oobeProperty -Value $oobeValue

Write-Host "Registry keys and values for Diagnostic Data settings have been set successfully."

# Install Hyper-V and reboot
Write-Host "Installing Hyper-V and restart"
Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
Install-WindowsFeature -Name Hyper-V -IncludeAllSubFeature -IncludeManagementTools -NoRestart

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

# Download ISOs
Write-Host "Downloading ISOs in parallel..."
# Convert JSON string to PowerShell object
$isoList = $isoDownloadsJson | ConvertFrom-Json

# Set your target directory
$targetDir = "F:\LabSources\ISOs"

$jobs = @()
foreach ($iso in $isoList) {
    $jobs += Start-Job -ScriptBlock {
        param($url, $dir, $name)
        $filePath = Join-Path $dir $name
        Write-Host "Downloading $url to $filePath"
        Invoke-WebRequest -Uri $url -OutFile $filePath
    } -ArgumentList $iso.isoDownloadUrl, $targetDir, $iso.name
}

# Wait for completion
$jobs | ForEach-Object { $_ | Wait-Job; Receive-Job $_; Remove-Job $_ }

# Create and install lab
Write-Host "Creating and installing lab"
# Get-LabAvailableOperatingSystem
$labName = 'MyEnterpriseLab'
$labDomainName = 'MyEnterpriseLab.net'
$labDnsServer1 = '192.168.84.10'
$labSources = 'F:\LabSources'
New-LabDefinition -Name $labName -DefaultVirtualizationEngine HyperV -VmPath F:\VMs
Add-LabVirtualNetworkDefinition -Name $labName -AddressSpace 192.168.84.0/24
Set-LabInstallationCredential -Username $windowsAdminUsername -Password $windowsAdminPassword
# DC
Add-LabDomainDefinition -Name $labDomainName -AdminUser $windowsAdminUsername -AdminPassword $windowsAdminPassword
Add-LabMachineDefinition -Name DC1 -Memory 3GB -Network $labName -IpAddress 192.168.84.10 `
    -DnsServer1 $labDnsServer1 -DomainName $labDomainName -Roles RootDC `
    -ToolsPath $labSources\Tools -OperatingSystem 'Windows Server 2025 Standard (Desktop Experience)'
# WEB
$role = Get-LabMachineRoleDefinition -Role WebServer -Properties @{ OrganizationName = 'Marketing' }
Add-LabMachineDefinition -Name WEB01 -Memory 3GB -Network $labName -IpAddress 192.168.84.20 `
    -DnsServer1 $labDnsServer1 -DomainName $labDomainName -Roles $role `
    -ToolsPath $labSources\Tools -OperatingSystem 'Windows Server 2025 Standard (Desktop Experience)'
Install-Lab
Show-LabDeploymentSummary
# -TimeZone -OrganizationalUnit -ActivateWindows

Stop-Transcript

# Restart computer
Restart-Computer
