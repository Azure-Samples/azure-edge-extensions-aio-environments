targetScope = 'subscription'

param location string = deployment().location
param applicationName string
var resourceGroupName = 'rg-${applicationName}'

param galleryName string
param imageDefinitionName string
param imageBuilderName string
param imageVersion string

param publisher string = 'MicrosoftWindowsServer'
param offer string = 'WindowsServer'
param sku string = '2022-datacenter-g2'
param version string = 'latest'
param architecture string = 'x64'
param vmSize string = 'Standard_D2s_v3'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
}

module imageIdentityModule 'user-assigned-identity.bicep' = {
  name: 'imageIdentityModule'
  scope: resourceGroup
  params: {
    location: location
    name: 'id-image-identity'
  }
}

resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c' //'Contributor'
}

resource contributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid(subscription().id, resourceGroupName, contributorRoleDefinition.id)
  properties: {
    principalId: imageIdentityModule.outputs.userAssignedIdentity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: contributorRoleDefinition.id
  }
}

module imageBuilder 'image-builder.bicep' = {
  name: 'imageBuilder'
  scope: resourceGroup
  params: {
    location: location
    identityId: imageIdentityModule.outputs.userAssignedIdentity.id
    stagingResourceGroupName: '${resourceGroup.name}-staging'
    galleryName: galleryName
    imageDefinitionName: imageDefinitionName
    imageBuilderName: imageBuilderName
    imageVersion: imageVersion
    //imageVersionNumber: '1.0.0' //TODO get versionnumber from script and increment by 1
    publisher: publisher
    offer: offer
    sku: sku
    version: version
    architecture: architecture
    vmSize: vmSize
  }
}
