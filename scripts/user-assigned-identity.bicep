param name string
param location string = resourceGroup().location
param exists bool

output userAssignedIdentity object = {
  id: (exists) ? userAssignedIdentityExistingResource.id: userAssignedIdentityResource.id
  principalId: (exists) ? userAssignedIdentityExistingResource.properties.principalId : userAssignedIdentityResource.properties.principalId
  principalType: 'ServicePrincipal'
  clientId: (exists) ? userAssignedIdentityExistingResource.properties.clientId : userAssignedIdentityResource.properties.clientId
  name: name
}

resource userAssignedIdentityResource 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = if(!exists){
  name: name
  location: location
}

resource userAssignedIdentityExistingResource 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = if(exists) {
  name: name
}

resource galleryAccessRole 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' = {
  name: guid(resourceGroup().id, 'GalleryAccessCustomRole')
  properties: {
    roleName: 'GalleryAccessCustomRole-${guid(resourceGroup().id)}'
    type: 'customRole'
    permissions: [
      {
        actions: [
          'Microsoft.Compute/galleries/read'
          'Microsoft.Compute/galleries/images/read'
          'Microsoft.Compute/galleries/images/versions/read'
          'Microsoft.Compute/galleries/images/versions/write'
          'Microsoft.Compute/images/write'
          'Microsoft.Compute/images/read'
          'Microsoft.Compute/images/delete'
        ]
        notActions: []
      }
    ]
    assignableScopes: [
      resourceGroup().id
    ]
  }
}

resource customRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid(resourceGroup().id, (exists) ? userAssignedIdentityExistingResource.id: userAssignedIdentityResource.id, galleryAccessRole.id)
  properties: {
    principalId: (exists) ? userAssignedIdentityExistingResource.properties.principalId : userAssignedIdentityResource.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: galleryAccessRole.id
  }
}
