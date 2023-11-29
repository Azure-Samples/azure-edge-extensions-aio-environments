param location string = resourceGroup().location
param identityId string
param spClientId string
param spObjectId string
@secure()
param spClientSecret string
param customLocationsObjectId string
param stagingResourceGroupName string
//param imageVersionNumber string
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
var arcClusterName = imageTemplateName

output azureImageTemplateName string = azureImageBuilderTemplate.name

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

resource azureImageBuilderTemplate 'Microsoft.VirtualMachineImages/imageTemplates@2022-02-14' = {
  name: imageTemplateName
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
        name: 'AzSetup'
        inline: [
          'az login --service-principal -u ${spClientId} -p ${spClientSecret} --tenant ${subscription().tenantId}'
          'az account show'
          'az extension add --name connectedk8s'
          'Invoke-WebRequest -Uri https://secure.globalsign.net/cacert/Root-R1.crt -OutFile c:\\globalsignR1.crt'
          'Import-Certificate -FilePath c:\\globalsignR1.crt -CertStoreLocation Cert:\\LocalMachine\\Root'
        ]
      }
      {
        type: 'WindowsRestart'
        name: 'StartAKSEdgeInstall-EnableHyperV'
        restartTimeout: '15m'
        restartCommand: 'powershell.exe -File c:\\scripts\\AksEdgeQuickStartForAio.ps1 -SubscriptionId ${subscription().subscriptionId} -TenantId ${subscription().tenantId} -Location ${location} -ResourceGroupName ${resourceGroup().name} -ClusterName ${arcClusterName}'
      }
      {
        type: 'PowerShell'
        name: 'ResumeInstall'
        runElevated: true
        inline: [
          '$ConfirmPreference = \'None\'; c:\\scripts\\AksEdgeQuickStartForAio.ps1 -SubscriptionId ${subscription().subscriptionId} -TenantId ${subscription().tenantId} -Location ${location} -ResourceGroupName ${resourceGroup().name} -ClusterName ${arcClusterName}'
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
          'az connectedk8s enable-features -n ${arcClusterName} -g ${resourceGroup().name} --custom-locations-oid ${customLocationsObjectId} --features cluster-connect custom-locations'
        ]
      }
      // {
      //   type: 'PowerShell'
      //   runElevated: true
      //   name: 'InstallAIO'
      //   inline: [
      //     'az iot ops init --cluster ${arcClusterName} -g ${resourceGroup().name} --kv-id $(az keyvault create -n kv-${imageTemplateName} -g ${resourceGroup().name} -o tsv --query id) --sp-app-id ${spClientId} --sp-object-id ${spObjectId} --sp-secret ${spClientSecret}'
      //   ]
      // }
      // {
      //   type: 'PowerShell'
      //   runElevated: true
      //   name: 'Disconnect Arc'
      //   inline: [
      //     'az connectedk8s delete -n ${arcClusterName} -g ${resourceGroup().name} --force --yes'
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
    scriptContent: 'Invoke-AzResourceAction -ResourceName ${azureImageBuilderTemplate.name} -ResourceGroupName ${resourceGroup().name} -ResourceType Microsoft.VirtualMachineImages/imageTemplates -Action Run -Force'
    retentionInterval: 'P1D'
  }
}
