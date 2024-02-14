param name string
param location string = resourceGroup().location
param identityExists bool

output userAssignedIdentity object = {
  id: (identityExists) ? userAssignedIdentityExistingResource.id: userAssignedIdentityResource.id
  principalId: (identityExists) ? userAssignedIdentityExistingResource.properties.principalId : userAssignedIdentityResource.properties.principalId
  principalType: 'ServicePrincipal'
  clientId: (identityExists) ? userAssignedIdentityExistingResource.properties.clientId : userAssignedIdentityResource.properties.clientId
  name: name
}

resource userAssignedIdentityResource 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = if(!identityExists){
  name: name
  location: location
}

resource userAssignedIdentityExistingResource 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = if(identityExists) {
  name: name
}

resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c' //'Contributor'
}

resource contributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = if(!identityExists) {
  name: guid(subscription().id, (identityExists) ? userAssignedIdentityExistingResource.id: userAssignedIdentityResource.id, contributorRoleDefinition.id)
  properties: {
    principalId: (identityExists) ? userAssignedIdentityExistingResource.properties.principalId : userAssignedIdentityResource.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: contributorRoleDefinition.id
  }
}
