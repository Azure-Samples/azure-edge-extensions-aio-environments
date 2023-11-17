param location string = resourceGroup().location
param identityId string
param stagingResourceGroupName string
//param imageVersionNumber string
param runOutputName string = 'arc_footprint_image'
param galleryName string
param imageDefinitionName string
param imageBuilderName string

param imageVersion string = 'latest'
var versionSuffix = imageVersion == 'latest' ? '' : '/versions/${imageVersion}'

param publisher string
param offer string
param sku string
param version string
param architecture string
param vmSize string

output azureImageBuilderName string = azureImageBuilder.name

resource gallery 'Microsoft.Compute/galleries@2021-10-01' = {
  name: galleryName
  location: location
  properties: {}
  tags: {}
}

resource galleryNameImageDefinition 'Microsoft.Compute/galleries/images@2021-10-01' = {
  parent: gallery
  name: imageDefinitionName
  location: location
  properties: {
    osType: 'Windows'
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

resource azureImageBuilder 'Microsoft.VirtualMachineImages/imageTemplates@2022-02-14' = {
  name: imageBuilderName
  location: location
  tags: {}
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    buildTimeoutInMinutes: 120
    customize: [
      {
        type: 'File'
        name: 'DownloadAIOScript'
        sourceUri: 'https://raw.githubusercontent.com/Azure/AKS-Edge/main/tools/scripts/AksEdgeQuickStart/AksEdgeQuickStart.ps1'
        destination: 'c:\\scripts\\AksEdgeQuickStart.ps1'
      }
      {
        type: 'PowerShell'
        name: 'InstallAzureCLI'
        runElevated: true
        inline: [
          '$ProgressPreference = \'SilentlyContinue\'; Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList \'/I AzureCLI.msi /quiet\'; Remove-Item .\\AzureCLI.msi'
        ]
      }
      {
        type: 'WindowsRestart'
        name: 'StartAKSEdgeInstall-EnableHyperV'
        restartCommand: 'powershell.exe -File c:\\scripts\\AksEdgeQuickStart.ps1'
      }
      {
        type: 'PowerShell'
        name: 'ResumeInstall'
        runElevated: true
        inline: [
          'c:\\scripts\\AksEdgeQuickStart.ps1'
        ]
      }
      {
        type: 'PowerShell'
        runElevated: true
        name: 'ValidateInstall'
        inline: [
          'kubectl get pods -A'
          'Kubectl get nodes'
        ]
      }
    ]
    distribute: [
      {
        type: 'SharedImage'
        runOutputName: runOutputName
        galleryImageId: '${galleryNameImageDefinition.id}${versionSuffix}'
        replicationRegions: [
          location
        ]
        storageAccountType: 'Standard_LRS'
      }
    ]
    stagingResourceGroup: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${stagingResourceGroupName}'
    source: {
      type: 'PlatformImage'
      publisher: publisher
      offer: offer
      sku: sku
      version: version
    }
    validate: {}
    vmProfile: {
      vmSize: vmSize
      osDiskSizeGB: 0
    }
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
    scriptContent: 'Invoke-AzResourceAction -ResourceName ${azureImageBuilder.name} -ResourceGroupName ${resourceGroup().name} -ResourceType Microsoft.VirtualMachineImages/imageTemplates -Action Run -Force'
    retentionInterval: 'P1D'
  }
}
