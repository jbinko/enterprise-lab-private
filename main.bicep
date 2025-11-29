@description('Azure region for resources')
param location string

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

param autoShutdownEnabled bool = true
param autoShutdownTime string = '0100' // The time for auto-shutdown in HHmm format (24-hour clock)
param autoShutdownTimezone string = 'UTC' // Timezone for the auto-shutdown
@secure()
param autoShutdownEmailRecipient string = ''

@description('Option to enable spot pricing for the master VM')
param enableAzureSpotPricing bool = true

@description('The base URL used for accessing artifacts and automation artifacts.')
param templateBaseUrl string

@description('JSON string containing ISO download links for various OSes.')
//@secure()
param isoDownloadsJson string

var networkSecurityGroupName = '${namingPrefix}-nsg'

var virtualNetworkName = '${namingPrefix}-vnet'
var addressPrefix = '192.168.0.0/24'
var subnetName = 'vm-subnet'
var subnetAddressPrefix = '192.168.0.0/24'

var publicIpAddressName = '${vmName}-pip'

var networkInterfaceName = '${vmName}-nic'

var vmName = '${namingPrefix}-vm'
var vmDiskSku string = 'Premium_LRS'
var vmOSDiskType = 'Premium_LRS'
var vmSize string = 'Standard_D8s_v5'
var vmWindowsOSVersion = '2025-datacenter-g2'

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: [
    ]
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
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: networkInterfaceName
  location: location
  properties: {
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
  location: location
  name: '${vmName}-DataDisk'
  sku: {
    name: vmDiskSku
  }
  properties: {
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: 256
    burstingEnabled: false
    diskMBpsReadWrite: 200
    diskIOPSReadWrite: 5000
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
          storageAccountType: vmOSDiskType
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
    billingProfile: enableAzureSpotPricing ? {
      maxPrice: -1
    } : null
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
        uri(templateBaseUrl, 'Bootstrap.ps1')
      ]
      commandToExecute: 'powershell.exe -ExecutionPolicy Bypass -File Bootstrap.ps1 -windowsAdminUsername ${windowsAdminUsername} -windowsAdminPassword ${windowsAdminPassword} -isoDownloadsJson ${isoDownloadsJson}'
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
      status: empty(autoShutdownEmailRecipient) ? 'Disabled' : 'Enabled' // Set status based on whether an email is provided
      timeInMinutes: 30
      webhookUrl: ''
      emailRecipient: autoShutdownEmailRecipient
      notificationLocale: 'en'
    }
    targetResourceId: vm.id
  }
}



// TODO: Entra ID login for VM admin user ???
