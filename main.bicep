@description('Azure region for resources')
param location string

@description('Admin username for VMs')
param adminUsername string

@description('Admin password for VMs')
@secure()
param adminPassword string

// Your Bicep resources go here
