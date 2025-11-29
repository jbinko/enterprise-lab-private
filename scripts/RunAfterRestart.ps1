Start-Transcript -Path c:\Bootstrap.log -Append






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