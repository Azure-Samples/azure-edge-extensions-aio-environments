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

var akseeVersion = '1.5.203.0'

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
        name: 'DownloadAksEdgeModules'
        runElevated: true
        inline: [
          '$ProgressPreference = \'SilentlyContinue\''
          'Set-ExecutionPolicy Bypass -Scope LocalMachine -Force'
          '$installDir=\'C:\\scripts\\aksedge\'; New-Item -Path "$installDir" -ItemType Directory | Out-Null'          
          'Write-Host "Step 1 : Azure/AKS-Edge repo setup"'
          '$outFile = $installDir + \'\\AKS-Edge.zip\'; Invoke-WebRequest -Uri https://github.com/Azure/AKS-Edge/archive/refs/tags/${akseeVersion}.zip -OutFile $outFile'
          'Expand-Archive -Path $outFile -DestinationPath $installDir -Force'
          '$aksedgeShell = (Get-ChildItem -Path "$installDir" -Filter AksEdgeShell.ps1 -Recurse).FullName; . $aksedgeShell'
        ]
      }
      {
        type: 'PowerShell'
        name: 'PrepAksEEConfig'
        runElevated: true
        inline: [
          'Write-Host "Step 2 : Create config files"'
          '$installDir=\'C:\\scripts\\aksedge\''
          '$productName = "AKS Edge Essentials - K3s"'
          '$networkplugin = "flannel"'
          '$aksedgeConfig = @"'
          '{'
              '"SchemaVersion": "1.9",'
              '"Version": "1.0",'
              '"DeploymentType": "SingleMachineCluster",'
              '"Init": {'
                  '"ServiceIPRangeSize": 10'
              '},'
              '"Network": {'
                  '"NetworkPlugin": "$networkplugin",'
                  '"InternetDisabled": false'
              '},'
              '"User": {'
                  '"AcceptEula": true,'
                  '"AcceptOptionalTelemetry": true'
              '},'
              '"Machines": ['
                  '{'
                      '"LinuxNode": {'
                          '"CpuCount": 8,'
                          '"MemoryInMB": 8192,'
                          '"DataSizeInGB": 30,'
                          '"LogSizeInGB": 4'
                      '}'
                  '}'
              ']'
          '}'
          '"@'
          '$aksConfigPath=$installDir+\'\\aksedge-config.json\''
          'Set-Content -Path $aksConfigPath -Value $aksedgeConfig -Force'
          '$aideuserConfig = @"'
          '{'
              '"SchemaVersion": "1.1",'
              '"Version": "1.0",'
              '"AksEdgeProduct": "$productName",'
              '"AksEdgeProductUrl": "",'
              '"Azure": {'
                  '"SubscriptionName": "",'
                  '"SubscriptionId": "",'
                  '"TenantId": "",'
                  '"ResourceGroupName": "aksedge-rg",'
                  '"ServicePrincipalName": "aksedge-sp",'
                  '"Location": "",'
                  '"CustomLocationOID":"",'
                ' "Auth":{'
                      '"ServicePrincipalId":"",'
                      '"Password":""'
                  '}'
              '},'
              '"AksEdgeConfigFile": "C:\\\\scripts\\\\aksedge\\\\aksedge-config.json"'
          '}'
          '"@'
          '$aideuserConfigPath=$installDir+\'\\aide-userconfig.json\''
          'Set-Content -Path $aideuserConfigPath -Value $aideuserConfig -Force'
        ]
      }
      {
        type: 'WindowsRestart'
        name: 'StartAKSEdgeInstall-EnableHyperV'
        restartTimeout: '15m'
        restartCommand: 'powershell.exe $installDir=\'C:\\scripts\\aksedge\'; $aksedgeShell = (Get-ChildItem -Path "$installDir" -Filter AksEdgeShell.ps1 -Recurse).FullName; . $aksedgeShell; Start-AideWorkflow -jsonFile C:\\scripts\\aksedge\\aide-userconfig.json'
      }
      {
        type: 'PowerShell'
        name: 'ResumeInstall'
        runElevated: true
        inline: [
          '$ConfirmPreference = \'None\'; $ErrorActionPreference = \'Stop\''
          '$installDir=\'C:\\scripts\\aksedge\''
          'Write-Host "Resume Step 3: install of AKS Edge Essentials after restart"'
          '$aksedgeShell = (Get-ChildItem -Path "$installDir" -Filter AksEdgeShell.ps1 -Recurse).FullName; . $aksedgeShell;'
          'Start-AideWorkflow -jsonFile C:\\scripts\\aksedge\\aide-userconfig.json'
        ]
      }
      {
        type: 'PowerShell'
        runElevated: true
        name: 'SaveKubeConfig'
        inline: [
          'Write-Host "Step 4: Save kubeconfig to c:\\scripts"'
          'Get-AksEdgeKubeConfig -KubeConfigPath C:\\Scripts -Confirm:$false'
          'kubectl get pods -A --kubeconfig C:\\Scripts\\config'
          'Kubectl get nodes --kubeconfig C:\\Scripts\\config'
        ]
      }
      {
        type: 'PowerShell'
        runElevated: true
        name: 'CleanupAksRepo'
        inline: [
          'Write-Host "Step 5: Cleanup repo files. Leave config files"'
          'Remove-Item -LiteralPath C:\\scripts\\aksedge\\AKS-Edge-${akseeVersion} -Force -Recurse'
          'Remove-Item -LiteralPath C:\\scripts\\aksedge\\AKS-Edge.zip -Force'
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
