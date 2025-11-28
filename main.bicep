@description('Azure region for resources')
param location string

@maxLength(7)
@description('The naming prefix for the resources')
param namingPrefix string

@description('Username for Windows account')
param windowsAdminUsername string

@description('Password for Windows account. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long')
@minLength(12)
@maxLength(123)
@secure()
param windowsAdminPassword string

param autoShutdownEnabled bool = true
param autoShutdownTime string = '0100' // The time for auto-shutdown in HHmm format (24-hour clock)
param autoShutdownTimezone string = 'UTC' // Timezone for the auto-shutdown
param autoShutdownEmailRecipient string = ''

@description('Option to enable spot pricing for the master VM')
param enableAzureSpotPricing bool = true

var virtualNetworkName = '${namingPrefix}-VNet'
var addressPrefix = '192.168.0.0/24'
var subnetName = 'vm-subnet'
var subnetAddressPrefix = '192.168.0.0/24'

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
        }
      }
    ]
  }
}
