metadata description = 'Enterprise lab infrastructure deployment with Hyper-V capable VM'

@description('Azure region for resources')
param location string = resourceGroup().location

@maxLength(7)
@description('The naming prefix for the resources')
param namingPrefix string

@description('Username for Windows account')
@secure()
param windowsAdminUsername string

@description('Password for Windows account. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long')
@minLength(12)
@maxLength(123)
@secure()
param windowsAdminPassword string

@description('Enable auto-shutdown for the VM')
param autoShutdownEnabled bool = true

@description('The time for auto-shutdown in HHmm format (24-hour clock)')
param autoShutdownTime string = '0100'

@description('Timezone for the auto-shutdown')
param autoShutdownTimezone string = 'UTC'

@description('Email recipient for auto-shutdown notifications')
@secure()
param autoShutdownEmailRecipient string = ''

@description('Enable Azure Spot pricing for the VM')
param enableAzureSpotPricing bool = true

@description('The base URL used for accessing artifacts')
param artifactsBaseUrl string

@description('Base64-encoded JSON string containing ISO download links for various OSes')
@secure()
param isoDownloadsBase64Json string

@description('VM size for the master VM')
param vmSize string = 'Standard_D8s_v5'

@description('Windows OS version for the VM')
param vmWindowsOSVersion string = '2025-datacenter-g2'

@description('Storage account type for VM disks')
@allowed([
  'Premium_LRS'
  'StandardSSD_LRS'
  'Standard_LRS'
])
param vmDiskSku string = 'Premium_LRS'

@description('Data disk size in GB')
@minValue(1)
@maxValue(32767)
param dataDiskSizeGB int = 256

// Naming variables
var vmName = '${namingPrefix}-vm'
var networkSecurityGroupName = '${namingPrefix}-nsg'
var virtualNetworkName = '${namingPrefix}-vnet'
var publicIpAddressName = '${vmName}-pip'
var networkInterfaceName = '${vmName}-nic'

// Network configuration
var addressPrefix = '192.168.0.0/24'
var subnetName = 'vm-subnet'
var subnetAddressPrefix = '192.168.0.0/24'

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: []
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-07-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
    ]
  }
}

resource publicIpAddress 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: publicIpAddressName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: networkInterfaceName
  location: location
  properties: {
    enableIPForwarding: true // THIS IS REQUIRED FOR HYPER-V NESTED VMs TO BE ABLE TO REACH INET
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: virtualNetwork.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIpAddress.id
          }
        }
      }
    ]
  }
}

resource vmDisk 'Microsoft.Compute/disks@2024-03-02' = {
  name: '${vmName}-DataDisk'
  location: location
  sku: {
    name: vmDiskSku
  }
  properties: {
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: dataDiskSizeGB
    burstingEnabled: false
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        name: '${vmName}-OSDisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: vmDiskSku
        }
        diskSizeGB: 127
      }
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: vmWindowsOSVersion
        version: 'latest'
      }
      dataDisks: [
        {
          createOption: 'Attach'
          lun: 0
          managedDisk: {
            id: vmDisk.id
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: windowsAdminUsername
      adminPassword: windowsAdminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
    }
    priority: enableAzureSpotPricing ? 'Spot' : 'Regular'
    evictionPolicy: enableAzureSpotPricing ? 'Deallocate' : null
    billingProfile: enableAzureSpotPricing
      ? {
          maxPrice: -1
        }
      : null
  }
}

resource vmBootstrap 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: vm
  name: 'Bootstrap'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      fileUris: [
        uri(artifactsBaseUrl, 'scripts/Bootstrap.ps1')
      ]
      // The format() function in protectedSettings preserves the secure nature of the parameters, keeping them encrypted during transmission to the VM.
      commandToExecute: format('powershell.exe -ExecutionPolicy Bypass -File Bootstrap.ps1 -windowsAdminUsername {0} -windowsAdminPassword {1} -isoDownloadsBase64Json {2} -artifactsBaseUrl {3}', windowsAdminUsername, windowsAdminPassword, isoDownloadsBase64Json, artifactsBaseUrl)
    }
  }
}

resource autoShutdown 'Microsoft.DevTestLab/schedules@2018-09-15' = if (autoShutdownEnabled) {
  name: 'shutdown-computevm-${vm.name}'
  location: location
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: autoShutdownTime
    }
    timeZoneId: autoShutdownTimezone
    notificationSettings: {
      status: empty(autoShutdownEmailRecipient) ? 'Disabled' : 'Enabled'
      timeInMinutes: 30
      emailRecipient: autoShutdownEmailRecipient
      notificationLocale: 'en'
    }
    targetResourceId: vm.id
  }
}

// Outputs
output vmName string = vm.name
output vmResourceId string = vm.id
output publicIpAddress string = publicIpAddress.properties.ipAddress
output vmSystemAssignedIdentityPrincipalId string = vm.identity.principalId
