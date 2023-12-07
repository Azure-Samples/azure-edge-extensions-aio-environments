param location string = resourceGroup().location
param identityId string
param stagingResourceGroupName string
param runOutputName string = 'arc_footprint_image'
param galleryName string
param imageDefinitionName string
param imageTemplateName string

param imageVersion string = 'latest'
var versionSuffix = imageVersion == 'latest' ? '' : '/versions/${imageVersion}'

param publisher string
param offer string
param sku string
param version string
param architecture string
param vmSize string
param osType string
param exists bool

output azureImageTemplateid string = osType == 'Windows' ? imageTemplateWindows.outputs.id : imageTemplateLinux.outputs.id

resource gallery 'Microsoft.Compute/galleries@2021-10-01' = if(!exists) {
  name: galleryName
  location: location
  properties: {}
  tags: {}
}

resource galleryNameImageDefinition 'Microsoft.Compute/galleries/images@2021-10-01' = if(!exists) {
  parent: gallery
  name: imageDefinitionName
  location: location
  properties: {
    osType: osType
    osState: 'Generalized'
    identifier: {
      publisher: publisher
      offer: offer
      sku: sku
    }
    hyperVGeneration: 'V2'
    features: [
      {
        name: 'securityType'
        value: 'TrustedLaunch'
      }
      {
        name: 'diskControllerTypes'
        value: 'SCSI'
      }
      {
        name: 'isAcceleratedNetworkSupported'
        value: 'true'
      }
    ]
    architecture: architecture
    recommended: {
      vCPUs: {
        min: 4
        max: 16
      }
      memory: {
        min: 16
        max: 32
      }
    }
  }
  tags: {}
}

resource galleryExisting 'Microsoft.Compute/galleries@2021-10-01' existing = if(exists) {
  name: galleryName
}

resource galleryExistingNameImageDefinition 'Microsoft.Compute/galleries/images@2021-10-01' existing = if(exists) {
  parent: galleryExisting
  name: imageDefinitionName
}

module imageTemplateWindows 'image-template-windows.bicep' = if(osType == 'Windows') {
  name: 'imageTemplateWindows'
  params: {
    location: location
    identityId: identityId
    stagingResourceGroupName: stagingResourceGroupName
    runOutputName: runOutputName
    imageTemplateName: imageTemplateName
    galleryImageId: '${ ((exists) ? galleryExistingNameImageDefinition.id : galleryNameImageDefinition.id)}${versionSuffix}'
    publisher: publisher
    offer: offer
    sku: sku
    version: version
    vmSize: vmSize
  }
}

module imageTemplateLinux 'image-template-linux.bicep' = if(osType == 'Linux') {
  name: 'imageTemplateLinux'
  params: {
    location: location
    identityId: identityId
    stagingResourceGroupName: stagingResourceGroupName
    runOutputName: runOutputName
    imageTemplateName: imageTemplateName
    galleryImageId: '${ ((exists) ? galleryExistingNameImageDefinition.id : galleryNameImageDefinition.id)}${versionSuffix}'
    publisher: publisher
    offer: offer
    sku: sku
    version: version
    vmSize: vmSize
  }
}

resource runImageTemplate 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'runPowerShellInline'
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    azPowerShellVersion: '9.7'
    scriptContent: 'Invoke-AzResourceAction -ResourceName ${imageTemplateName} -ResourceGroupName ${resourceGroup().name} -ResourceType Microsoft.VirtualMachineImages/imageTemplates -Action Run -Force'
    retentionInterval: 'P1D'
  }
}
