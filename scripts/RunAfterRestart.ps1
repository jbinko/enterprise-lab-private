param (
    [string]$windowsAdminUsername,
    [string]$windowsAdminPassword
)

$TranscriptFile = "c:\Bootstrap.log"
Start-Transcript -Path $TranscriptFile -Append

# Headless/Non-interactive Environments: Disable all prompts
# Turn off telemetry, do not sync lab sources content
# Set-PSFConfig -FullName AutomatedLab.DoNotPrompt -Value $true -PassThru | Register-PSFConfig
# Set-PSFConfig -FullName AutomatedLab.Timeout_Sql2012Installation -Value 120 -PassThru | Register-PSFConfig

# Create and install lab
Write-Host "Creating and installing lab"
# Get-LabAvailableOperatingSystem -Path F:\LabSources
$labName = 'MyEnterpriseLab'
$labDomainName = 'MyEnterpriseLab.net'
$labDnsServer1 = '192.168.84.10'
$labSources = 'F:\LabSources'
New-LabDefinition -Name $labName -DefaultVirtualizationEngine HyperV -VmPath F:\VMs
Add-LabVirtualNetworkDefinition -Name $labName -AddressSpace 192.168.84.0/24

Add-LabIsoImageDefinition -Name SQLServer2012 -Path $labSources\ISOs\en_sql_server_2012_standard_edition_x86_x64_dvd_813403.iso

# DC
Add-LabDomainDefinition -Name $labDomainName -AdminUser $windowsAdminUsername -AdminPassword $windowsAdminPassword
Set-LabInstallationCredential -Username $windowsAdminUsername -Password $windowsAdminPassword
Add-LabMachineDefinition -Name DC01 -Memory 3GB -Network $labName -IpAddress 192.168.84.10 `
    -DnsServer1 $labDnsServer1 -DomainName $labDomainName -Roles RootDC `
    -ToolsPath $labSources\Tools -OperatingSystem 'Windows Server 2025 Standard (Desktop Experience)'

# SQL
Add-LabMachineDefinition -Name SQL01 -Memory 3GB -Network $labName -IpAddress 192.168.84.25 `
    -DnsServer1 $labDnsServer1 -DomainName $labDomainName -Roles SQLServer2012 -TimeZone "Central Europe Standard Time" `
    -ToolsPath $labSources\Tools -OperatingSystem 'Windows Server 2012 Standard (Server with a GUI)'

# FS
Add-LabMachineDefinition -Name FS01 -Memory 3GB -Network $labName -IpAddress 192.168.84.15 `
    -DnsServer1 $labDnsServer1 -DomainName $labDomainName -Roles FileServer -TimeZone "Central Europe Standard Time" `
    -ToolsPath $labSources\Tools -OperatingSystem 'Windows Server 2012 Standard (Server with a GUI)'

# WEB
Add-LabMachineDefinition -Name WEB01 -Memory 3GB -Network $labName -IpAddress 192.168.84.20 `
    -DnsServer1 $labDnsServer1 -DomainName $labDomainName -Roles WebServer -TimeZone "Central Europe Standard Time" `
    -ToolsPath $labSources\Tools -OperatingSystem 'Windows Server 2012 Standard (Server with a GUI)'

<#

'Windows Server 2012 Standard (Server with a GUI)'
-OrganizationalUnit Marketing 


$role = Get-LabMachineRoleDefinition -Role WebServer -Properties @{ OrganizationName = 'Marketing' }
Add-LabMachineDefinition -Name WEB01 -Memory 3GB -Network $labName -IpAddress 192.168.84.20 `
    -DnsServer1 $labDnsServer1 -DomainName $labDomainName -Roles $role `
    -ToolsPath $labSources\Tools -OperatingSystem 'Windows Server 2012 Standard (Server with a GUI)'

Add-LabMachineDefinition -Name UBU01 -Memory 3GB -Network $labName -IpAddress 192.168.14.10 `
    -DnsServer1 $labDnsServer1 `
    -OperatingSystem 'Ubuntu-Server 24.04.3 LTS "Noble Numbat"' -UbuntuPackage Minimal
#>

Install-Lab
Show-LabDeploymentSummary
# -ActivateWindows


Unregister-ScheduledTask -TaskName 'RunOnceAfterRestart' -Confirm:$false

Stop-Transcript




# Import-Lab -Name MyEnterpriseLab -NoValidation
# Remove-LabVm -Name WEB01
# Remove-Lab -Name $labName
# & "F:\Scripts\RunAfterRestart.ps1" -windowsAdminUsername XYZ -windowsAdminPassword XYZ