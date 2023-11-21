param location string = resourceGroup().location
param applicationName string
param identityId string
param spClientId string
param spClientSecret string
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
param exists bool

output azureImageBuilderName string = azureImageBuilder.name

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

resource galleryExisting 'Microsoft.Compute/galleries@2021-10-01' existing = if(exists) {
  name: galleryName
}

resource galleryExistingNameImageDefinition 'Microsoft.Compute/galleries/images@2021-10-01' = if(exists) {
  parent: galleryExisting
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
        sourceUri: 'https://raw.githubusercontent.com/Azure/AKS-Edge/main/tools/scripts/AksEdgeQuickStart/AksEdgeQuickStartForAio.ps1'
        destination: 'c:\\scripts\\AksEdgeQuickStartForAio.ps1'
      }
      {
        type: 'File'
        name: 'DownloadScript'
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
        type: 'PowerShell'
        runElevated: true
        name: 'AzLogin'
        inline: [
          'az login --service-principal -u ${spClientId} -p ${spClientSecret} --tenant ${subscription().tenantId}'
          'az account show'
          'az extension add --name connectedk8s'
          'Invoke-WebRequest -Uri https://storage.googleapis.com/kubernetes-release/release/stable.txt'
        ]
      }
      {
        type: 'WindowsRestart'
        name: 'StartAKSEdgeInstall-EnableHyperV'
        restartTimeout: '15m'
        restartCommand: 'powershell.exe -File c:\\scripts\\AksEdgeQuickStart.ps1 -SubscriptionId=${subscription().subscriptionId} -TenantId=${subscription().tenantId} -Location=${location} -ResourceGroupName=${resourceGroup().name} -ClusterName=aks-${applicationName}'
      }
      {
        type: 'PowerShell'
        name: 'ResumeInstall'
        runElevated: true
        inline: [
          '$ConfirmPreference = \'None\'; c:\\scripts\\AksEdgeQuickStartForAio.ps1 -SubscriptionId ${subscription().subscriptionId} -TenantId ${subscription().tenantId} -Location ${location} -ResourceGroupName ${resourceGroup().name} -ClusterName aks-${applicationName}'
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
      {
        type: 'PowerShell'
        runElevated: true
        name: 'InstallAzureCLIExtension'
        inline: [
          'az extension add --name azure-iot-ops'
        ]
      }
      // {
      //   type: 'PowerShell'
      //   runElevated: true
      //   name: 'InstallAIO'
      //   inline: [
      //     'az iot ops init --cluster aks-${applicationName} -g ${resourceGroup().name} --kv-id $(az keyvault create -n kv-${applicationName} -g ${resourceGroup().name} -o tsv --query id)'
      //   ]
      // }
      // optional inbound firewall rule for MQTT
      // {
      //   type: 'PowerShell'
      //   runElevated: true
      //   name: 'InstallAIO'
      //   inline: [
      //     'New-NetFirewallRule -DisplayName "Azure IoT MQ" -Direction Inbound -Protocol TCP -LocalPort 8883 -Action Allow'
      //     '$IpAddress = kubectl get svc aio-mq-dmqtt-frontend -n azure-iot-operations -o jsonpath=\'{.status.loadBalancer.ingress[0].ip}\'; netsh interface portproxy add v4tov4 listenport=8883 listenaddress=0.0.0.0 connectport=8883 connectaddress=$IpAddress'
      //   ]
      // }
    ]
    distribute: [
      {
        type: 'SharedImage'
        runOutputName: runOutputName
        galleryImageId: '${ ((exists) ? galleryExistingNameImageDefinition.id : galleryNameImageDefinition.id)}${versionSuffix}'
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
