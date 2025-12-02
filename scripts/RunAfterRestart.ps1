param (
    [string]$windowsAdminUsername,
    [string]$windowsAdminPassword
)

$TranscriptFile = "c:\Bootstrap.log"
Start-Transcript -Path $TranscriptFile -Append




# Wait for the Hyper-V Virtual Machine Management Service (vmms) to be running
$maxWaitSeconds = 120
$intervalSeconds = 5
$elapsed = 0

Write-Host "Waiting for the Hyper-V VMMS service to be running..."

do {
    $service = Get-Service -Name vmms -ErrorAction SilentlyContinue
    if ($null -eq $service) {
        Write-Host "vmms service not found. Waiting..."
    }
    elseif ($service.Status -eq 'Running') {
        Write-Host "vmms service is running!"
        break
    } else {
        Write-Host "vmms service status: $($service.Status). Waiting..."
    }
    Start-Sleep -Seconds $intervalSeconds
    $elapsed += $intervalSeconds
} while ($elapsed -lt $maxWaitSeconds)

if ($null -eq $service -or $service.Status -ne 'Running') {
    Write-Host "Timeout waiting for vmms service to start. Please investigate."
    exit 1
}




# Create LabNATSwitch
$LabNATSwitch = "LabNATSwitch"
New-VMSwitch -SwitchName $LabNATSwitch -SwitchType Internal
New-NetIPAddress -IPAddress 192.168.12.1 -PrefixLength 24 -InterfaceAlias "vEthernet ($LabNATSwitch)"
New-NetNat -Name LabNATNetwork -InternalIPInterfaceAddressPrefix 192.168.12.0/24

# Headless/Non-interactive Environments: Disable all prompts
# Turn off telemetry, do not sync lab sources content
# Set-PSFConfig -FullName AutomatedLab.DoNotPrompt -Value $true -PassThru | Register-PSFConfig
# Set-PSFConfig -FullName AutomatedLab.Timeout_Sql2012Installation -Value 120 -PassThru | Register-PSFConfig

# Create and install lab
Write-Host "Creating and installing lab"
# Get-LabAvailableOperatingSystem -Path F:\LabSources
$labName = 'MyEnterpriseLab'
$labDomainName = 'MyEnterpriseLab.net'
#$labDnsServer1 = '192.168.10.10'
$labTimeZone = 'Central Europe Standard Time'
$labSources = 'F:\LabSources'
New-LabDefinition -Name $labName -DefaultVirtualizationEngine HyperV -VmPath F:\VMs
Add-LabVirtualNetworkDefinition -Name $labName
Add-LabVirtualNetworkDefinition -Name $LabNATSwitch -HyperVProperties @{ SwitchType = 'Internal' }

Add-LabIsoImageDefinition -Name SQLServer2012 -Path $labSources\ISOs\en_sql_server_2012_standard_edition_x86_x64_dvd_813403.iso

# DC
Add-LabDomainDefinition -Name $labDomainName -AdminUser $windowsAdminUsername -AdminPassword $windowsAdminPassword
Set-LabInstallationCredential -Username $windowsAdminUsername -Password $windowsAdminPassword
Add-LabMachineDefinition -Name DC01 -Memory 3GB -Network $labName `
    -DomainName $labDomainName -Roles RootDC -TimeZone $labTimeZone `
    -ToolsPath $labSources\Tools -OperatingSystem 'Windows Server 2025 Standard (Desktop Experience)'

# Router
$netAdapter = @()
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch $labName
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch $LabNATSwitch -UseDhcp
Add-LabMachineDefinition -Name Router01 -Memory 3GB -NetworkAdapter $netAdapter `
    -DomainName $labDomainName -Roles Routing -TimeZone $labTimeZone `
    -ToolsPath $labSources\Tools -OperatingSystem 'Windows Server 2012 Standard (Server with a GUI)'

# SQL
Add-LabMachineDefinition -Name SQL01 -Memory 3GB -Network $labName `
    -DomainName $labDomainName -Roles SQLServer2012 -TimeZone $labTimeZone `
    -ToolsPath $labSources\Tools -OperatingSystem 'Windows Server 2012 Standard (Server with a GUI)'

# FS
Add-LabMachineDefinition -Name FS01 -Memory 3GB -Network $labName `
    -DomainName $labDomainName -Roles FileServer -TimeZone $labTimeZone `
    -ToolsPath $labSources\Tools -OperatingSystem 'Windows Server 2012 Standard (Server with a GUI)'

# WEB
Add-LabMachineDefinition -Name WEB01 -Memory 3GB -Network $labName `
    -DomainName $labDomainName -Roles WebServer -TimeZone $labTimeZone `
    -ToolsPath $labSources\Tools -OperatingSystem 'Windows Server 2012 Standard (Server with a GUI)'

<#

'Windows Server 2012 Standard (Server with a GUI)'
-OrganizationalUnit Marketing 


$role = Get-LabMachineRoleDefinition -Role WebServer -Properties @{ OrganizationName = 'Marketing' }
Add-LabMachineDefinition -Name WEB01 -Memory 3GB -Network $labName -IpAddress 192.168.10.20 `
    -DnsServer1 $labDnsServer1 -DomainName $labDomainName -Roles $role `
    -ToolsPath $labSources\Tools -OperatingSystem 'Windows Server 2012 Standard (Server with a GUI)'

Add-LabMachineDefinition -Name UBU01 -Memory 3GB -Network $labName -IpAddress 192.168.10.10 `
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