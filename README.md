# Pre-Built Azure IoT Operations Environments

This repository sets up the infrastructure to create vhdx images and VMs for Azure IoT Operations on Arc-enabled servers.
This infrastructure enables you to install instrumentation tools and collect memory dumps for applications and core components.

## Getting Started

### Supported Operating Systems

- Windows Server
- Windows IoT Enterprise
- Linux Ubuntu
- Azure Stack HCI

### Prerequisites

1. Install [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
2. Install [GitHub CLI](https://cli.github.com/)
3. An Azure subscription
4. Fork this repository and run

`az login --tenant <tenant-id>`--scope https://graph.microsoft.com//.default

`az account set --subscription <subscription-id>`

### Setup

Execute the PowerShell script [`./setup.ps1`](./setup.ps1):

```powershell
./setup.ps1 -ForkedRepo <owner/forked-repo-name> -SubscriptionId <subid> -ServicePrincipalName <name-for-new-sp> -HciAksGroupName <hci-aks-groupname> -VmAdminUsername <vm-usrname> -VmAdminPassword <vm-usrpassword>
```

```sh

# or 
./setup.ps1 <owner/forked-repo-name> <subid> <name-for-new-sp> <hci-aks-groupname> <vm-usrname> <vm-usrpassword>
```

to create the required Service Principal, Role Assignments and GitHub Secrets.

You have to provide the following parameters to the script:

- Azure Subscription Id
- Service Principal Name
- Entra Id Group Name for AKS HCI Cluster
- VM Admin Username (for the VMs created based on the images)
- VM Admin Password (for the VMs created based on the images)

<details>

  <summary>The script executes the steps described in the following sections:</summary>

### Azure Subscription Access

```sh
# Create an sp for gh actions. Create a secret named AZURE_CREDENTIALS from the output of the following command
# Owner role required to create identities
az ad sp create-for-rbac --name "myApp" --role owner \
                                --scopes /subscriptions/{subscription-id}/resourceGroups/{resource-group} \
                                --json-auth
```

Due to flexibility reasons, the output JSON of the above command doesn´t need to be stored.
Instead, you have to store the single properties subscriptionId, tenantId, clientId, clientSecret and objectId in separate secrets named `AZURE_SUBSCRIPTION_ID`, `AZURE_TENANT_ID`, `AZURE_SP_CLIENT_ID`, `AZURE_SP_CLIENT_SECRET` and `AZURE_SP_OBJECT_ID` in the GitHub repository.

You can obtain the objectId by executing the following command:

```sh
# Get the objectId of the sp
az ad sp show --id <client-id> --query id -o tsv
```

```sh
# Create role assignment for the SP to create Grafana dashboards
az role assignment create --assignee <client-id> --role "Grafana Admin" --scope /subscriptions/<subscription-id>
```

### GitHub Secrets

GitHub secrets that are required for the workflows to run:

| Secret | Description |
| ------------- | ------------- |
| AZURE_SUBSCRIPTION_ID | subscription id (also part of the output from az ad sp create-for-rbac command) |
| AZURE_TENANT_ID | tenant id (also part of the output from az ad sp create-for-rbac command) |
| AZURE_SP_CLIENT_ID | client id from az ad sp create-for-rbac command |
| AZURE_SP_CLIENT_SECRET | client secret from az ad sp create-for-rbac command |
| AZURE_SP_OBJECT_ID | object id from az ad sp create-for-rbac command |
| AZURE_STACK_HCI_OBJECT_ID | object id of the 'Microsoft.AzureStackHCI Resource Provider' app registration |
| CUSTOM_LOCATIONS_OBJECT_ID | object id of the contributor SP (see below) |
| HCI_AKS_GROUP_OBJECT_ID | object id of the group required for the AKS HCI Workload cluster |
| VMADMINPASSWORD | admin username for the VM |
| VMADMINUSERNAME | admin password for the VM |

### Arc Custom Locations

In order to enable [Arc custom locations](https://learn.microsoft.com/en-us/azure/azure-arc/platform/conceptual-custom-locations), the service principle created for the workflow must have the ability to read Applications in Microsoft Graph. 

Since this requires admin consent, you also execute the following command to obtain the required objectId of the `Contributor` role in that Azure tenant by using a user/service principle having the permission mentioned above.

```sh
az ad sp show --id bc313c14-388c-4e7d-a58e-70017303ee3b --query id -o tsv
```

You need to store the command output in a secret name `CUSTOM_LOCATIONS_OBJECT_ID` in the GitHub repository.

</details>

## Pre-requisites

### Azure VM Sizes

Since nested virtualization is required to install AKS-EE on Windows, you need to select a VM size that supports this feature, such as Dv5 or Dsv5 series. For more information, you can refer to [hardware requirements](https://learn.microsoft.com/en-us/azure/aks/hybrid/aks-edge-system-requirements#hardware-requirements).

## Workflows

### Azure Stack HCI

This repo also supports the creation of an [Azure Stack HCI](https://learn.microsoft.com/en-us/azure-stack/hci/overview) environment.
It utilizes the [Azure Arc Jumpstart HCIBox](https://arcjumpstart.com/azure_jumpstart_hcibox) resources to create an AKS HCI cluster on Azure Stack HCI and is fully automated by the GitHub Actions workflows.
To start the deployment of an Azure Stack HCI sandbox which installs Azure IoT Operations on top of it, you need to run the **Build HCI** pipeline.

Additionally, you can also run the **Build Monitoring** pipeline to create monitoring resources for the AKS HCI cluster by enabling the **Start 'Build Monitoring' Workflow** checkbox.\
This workflow also exposes measures of the memory for the HCIBox-Client VM.\
You can find more details in the [Monitoring](#monitoring) section.

> **Troubleshooting:** If you encounter any issues during the deployment and the VM extension execution fails, delete the HCIBox-Client VM´s customextension "vmHyperVInstall" and restart the VM and re-run the workflow. Also note that the VM extension execution times out after 90 minutes and the workflow will fail but the installation process will continue on the HCIBox-Client VM.

<img src='img/build-hci.png' width='25%' height='25%'>

### Image Creation

Once you enabled the GitHub Action workflows you can run the **Build VHDX** pipeline to create the vhdx images based on the selected parameters and configuration.
It installs the corresponding version of [AKS-EE](https://learn.microsoft.com/en-us/azure/aks/hybrid/aks-edge-overview) directly on the os disk/image for a Windows os type. For a Linux os type, it installs [K3s](https://docs.k3s.io/quick-start) lightweight Kubernetes cluster.

#### How to create a new image

Just navigate to the GitHub Actions of the repository and select the **Build VHDX** workflow. You can now start a workflow run by clicking on the **Run workflow** button and specifying all parameters and the image configuration.
If you check the **Create VM from image** checkbox, the workflow will automatically create a VM from image by starting the **Build VM** pipeline.

<img src='img/build-vhdx.png' width='25%' height='25%'>

### VM Creation

On top of the created vhdx images you can create a VM with the **Build VM** pipeline that references the image in the image gallery.
It also sets up a VM extension that connects the Cluster to the Arc control plane and installs [Azure IoT Operations](https://learn.microsoft.com/en-us/azure/iot-operations/).

> **Note:** The VM creation workflows targets to create virtual machines in an Azure subscription. If you want to create Industrial PCs in a different environment or on-premise, you need to modify the workflow.

#### How to build a new VM

As mentioned in section [How to create a new image](#how-to-create-a-new-image), you can implicitly run the **Build VM** pipeline by checking the **Create VM from image** checkbox for the **Build VHDX** workflow.
But you can also start a workflow run manually by submitting the right parameters to point to an existing image. Due to reusability of os disks you can create multiple VMs based on the same image.
Monitoring resources creation is automatically triggered via separate pipeline, see [Monitoring](#monitoring) section for more details.

<img src='img/build-vm.png' width='25%' height='25%'>

### Monitoring

Azure Monitoring resources like Log Analytics and Grafana are created by the **Build Monitoring** pipeline. This workflow is automatically triggered by the **Build VM** pipeline.
You can also run the **Build Monitoring** workflow manually to create monitoring resources for an existing cluster.

It deploys the [Azure Monitor Extension](https://learn.microsoft.com/en-us/azure/azure-monitor/containers/kubernetes-monitoring-enable?tabs=cli#arc-enabled-cluster) for Arc-enabled clusters and the [Azure Monitor Agent](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/agents-overview) as extension for VMs.

Additionally, the Windows OS images are prepared with the Windows Assessment and Deployment Kit ([Windows ADK](https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install)) to expose the host memory metrics to the Log Analytics workspace via DataCollection Rules. On Linux those metrics are available out-of-the-box in the file system of the OS itself.

> Note: This pipeline will skip installing the azuremonitor-extension for arc-clusters if the provided cluster is not found

<img src='img/build-monitoring.png' width='25%' height='25%'>

#### Grafana Dashboard

After running the Build-VM (or manually running the Build-Monitoring) pipeline, you should be equipped with a Grafana dashboard that is uses the Prometheus endpoint of Azure Monitor as datasource to retrieve the metrics.

In order to access the dashboard, users must have at least "Grafana Reader" role.

```sh
# Assign the signed-in user appropriate Grafana role with az cli
id=$(az ad signed-in-user show --query id -o tsv)
az role assignment create --assignee $id --role "Grafana Admin"
```

Two dashboards are available in the `Footprint Dashboards` folder:

- *Memory Footprint - Cluster*: This dashboard shows the memory usage of the cluster including AIO and Arc resources.
<img src='img/dashboard-cluster.png'>

- *Memory Footprint - Host*: This dashboard shows the memory usage of the VM (host) processes.
<img src='img/dashboard-host.png'>
