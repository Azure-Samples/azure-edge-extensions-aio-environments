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
        type: 'Shell'
        name: 'Install K3s'
        inline: [
          'curl -sfL https://get.k3s.io | sh -'
          'mkdir ~/.kube'
          'cp ~/.kube/config ~/.kube/config.back'
          'sudo KUBECONFIG=~/.kube/config:/etc/rancher/k3s/k3s.yaml kubectl config view --flatten > ~/.kube/merged'
          'mv ~/.kube/merged ~/.kube/config'
          'chmod  0600 ~/.kube/config'
          'export KUBECONFIG=~/.kube/config'
          'kubectl config use-context default'
        ]
      }
      {
        type: 'Shell'
        name: 'Install nfs-common'
        inline: [
          'sudo apt install nfs-common'
        ]
      }
      {
        type: 'Shell'
        name: 'Increase the user watch/instance limits'
        inline: [
          'echo fs.inotify.max_user_instances=8192 | sudo tee -a /etc/sysctl.conf'
          'echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf'
          'sudo sysctl -p'
        ]
      }
      {
        type: 'Shell'
        name: 'Increase the user watch/instance limits'
        inline: [
          'echo fs.file-max = 100000 | sudo tee -a /etc/sysctl.conf'
          'sudo sysctl -p'
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
