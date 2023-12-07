# Optimization for Arc memory footprintview

This repository sets up the infrastructure to create vhdx images for the Arc memory footprint investigations.
Because of the nature of efficiency, customer demand a low memory footprint to save costs in terms of hardware and devices.
This infrastructure enables you to install instrumentation tools and collect memory dumps components.

## Pre-requisites

```sh
# Create an sp for gh actions. Create a secret named AZURE_CREDENTIALS from the output of the following command
# Owner role required to create identities
az ad sp create-for-rbac --name "myApp" --role owner \
                                --scopes /subscriptions/{subscription-id}/resourceGroups/{resource-group} \
                                --json-auth
                                
az role assignment create --assignee <client-id> --role "Grafana Admin" --scope /subscriptions/<subscription-id>
```
### Arc Custom Locations
In order to enable [Arc custom locations](https://learn.microsoft.com/en-us/azure/azure-arc/platform/conceptual-custom-locations),  the service principle created for the workflow must have the ability to read Applications in Microsoft Graph. 

## Workflows

### Image Creation

Once you enabled the GitHub Action workflows you can run the **Build VHDX** pipeline to create the vhdx images based on the selected parameters and configuration.
It installs the corresponding version of [AKS-EE](https://learn.microsoft.com/en-us/azure/aks/hybrid/aks-edge-overview) and [Azure IoT Operations](https://learn.microsoft.com/en-us/azure/iot-operations/).

### VM Creation

On top of the created vhdx images you can create a VM with the **Create VM** pipeline that references the image in the image gallery.

#### Grafana Dashboard 

After running the Build-VM pipeline, you should be equipped with a Grafana dashboard. In order to access the dashboard, users must have at least "Grafana Reader" role. 

```sh
# Assign the signed-in user appropriate Grafana role with az cli
id=$(az ad signed-in-user show --query id -o tsv)
az role assignment create --assignee $id --role "Grafana Admin"
```