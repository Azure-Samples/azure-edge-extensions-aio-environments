targetScope = 'subscription'

param location string = deployment().location
param resourceGroupName string

param galleryName string
param imageDefinitionName string
param imageTemplateName string
param imageVersion string

param publisher string = 'MicrosoftWindowsServer'
param offer string = 'WindowsServer'
param sku string = '2022-datacenter-g2'
param version string = 'latest'
param architecture string = 'x64'
param vmSize string = 'Standard_D2s_v3'
param osType string = 'Windows'
param exists bool = false
param identityExists bool = false

output azureImageTemplateid string = imageBuilder.outputs.azureImageTemplateid

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
}

module imageIdentityModule 'user-assigned-identity.bicep' = {
  name: 'imageIdentityModule'
  scope: resourceGroup
  params: {
    location: location
    name: '${galleryName}-identity'
    identityExists: identityExists
  }
}

module imageBuilder 'image-builder.bicep' = {
  name: 'imageBuilder'
  scope: resourceGroup
  params: {
    location: location
    identityId: imageIdentityModule.outputs.userAssignedIdentity.id
    stagingResourceGroupName: '${imageTemplateName}-staging'
    galleryName: galleryName
    imageDefinitionName: imageDefinitionName
    imageTemplateName: imageTemplateName
    imageVersion: imageVersion
    //imageVersionNumber: '1.0.0' //TODO get versionnumber from script and increment by 1
    publisher: publisher
    offer: offer
    sku: sku
    version: version
    architecture: architecture
    vmSize: vmSize
    osType: osType
    exists: exists
  }
}
