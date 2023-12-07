param location string = resourceGroup().location
param identityId string
param stagingResourceGroupName string
//param imageVersionNumber string
param runOutputName string = 'arc_footprint_image'
param imageTemplateName string

param galleryImageId string

param publisher string
param offer string
param sku string
param version string
param vmSize string

output id string = azureImageBuilderTemplate.id

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
        name: 'AzSetup'
        inline: [
          'Invoke-WebRequest -Uri https://secure.globalsign.net/cacert/Root-R1.crt -OutFile c:\\globalsignR1.crt'
          'Import-Certificate -FilePath c:\\globalsignR1.crt -CertStoreLocation Cert:\\LocalMachine\\Root'
        ]
      }
      {
        type: 'PowerShell'
        runElevated: true
        name: 'Prep script and PowerShell'
        inline: [
          'Unblock-File c:\\scripts\\AksEdgeQuickStart.ps1'
          'Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope LocalMachine -Force'
        ]
      }
      {
        type: 'WindowsRestart'
        name: 'StartAKSEdgeInstall-EnableHyperV'
        restartTimeout: '15m'
        restartCommand: 'powershell.exe -ExecutionPolicy Bypass -File c:\\scripts\\AksEdgeQuickStart.ps1'
      }
      {
        type: 'PowerShell'
        name: 'ResumeInstall'
        runElevated: true
        inline: [
          '$ConfirmPreference = \'None\'; c:\\scripts\\AksEdgeQuickStart.ps1'
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
        galleryImageId: galleryImageId
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
