#!/bin/bash
set -e

Usage(){
  echo "Usage: configure-azmon-grafana.sh <OPTIONS>"
  echo "Description:"
  echo "  Creates Azure Monitor and Grafana resources to house metrics and dashboards"
  echo "Options:"
  echo "  -g| Azure resource group (required)"
  echo "  -m| Azure monitor resource name (default: footprint)"
  echo "  -d| Grafana dashboard resource name. Must be globally unique (default: footprint-<random4char>)"
  echo "  -c| Azure monitor resource name. Skips extension install for connected cluster if not provided."
}

while getopts ":v:g:m:d:c:" opt; do
  case $opt in
    v) vmName=$OPTARG
    ;;
    g) resourceGroup=$OPTARG
    ;;
    m) monitorName=$OPTARG
    ;;
    d) grafanaDashboardName=$OPTARG
    ;;
    c) clusterName=$OPTARG
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    exit 1
    ;;
  esac

  case $OPTARG in
    -*) echo "Option $opt needs a valid argument"
    exit 1
    ;;
  esac
done

if [[ $OPTIND -eq 1 || -z $vmName ]]; then
  Usage
  exit 1
fi

randoStr=$(tr -dc a-z0-9 </dev/urandom | head -c 4; echo)
grafanaDashboardName=${grafanaDashboardName:-footprint-$randoStr}
monitorName="${monitorName:-footprint}"

BASEDIR=$(dirname $0)

if [ -z $resourceGroup ]; then
  echo "Please provide a valid resource group."
  exit 1
else 
  az group show --name $resourceGroup
  echo "Executing script with monitor name: $monitorName and grafana dashboard name: $grafanaDashboardName"
fi

location=$(az group show -n $resourceGroup --query location -o tsv)
subscriptionId=$(az account show --query id -o tsv)
monitor_resource=$(az resource show --resource-type Microsoft.monitor/accounts --name $monitorName --resource-group $resourceGroup 2>/dev/null | jq -c .)
osType=$(az vm show --name $vmName --resource-group $resourceGroup --query 'storageProfile.osDisk.osType' -o tsv)

if [ -z $monitor_resource ]; then
  echo "Creating new Azure Monitor workspace..."
  monitor_resource=$(az resource create -g $resourceGroup --namespace microsoft.monitor --resource-type accounts --name $monitorName --properties "{}" | jq -c .)
else
  echo "Azure Monitor workspace found. Use existing..."
fi

if [[ -z $(az vm extension show --name AzureMonitorWindowsAgent --vm-name $vmName -g $resourceGroup 2>/dev/null | jq .name) ]]; then
  echo "Installing AzureMonitor agent extension on $vmName..."
  if [ $osType == "Windows" ]; then
    az vm extension set --name AzureMonitorWindowsAgent --publisher Microsoft.Azure.Monitor --vm-name $vmName -g $resourceGroup
  else
    az vm extension set --name AzureMonitorLinuxAgent --publisher Microsoft.Azure.Monitor --vm-name $vmName -g $resourceGroup
  fi
fi

grafana=$(az grafana list --query "[?resourceGroup=='$resourceGroup']" -o json | jq -c '.[0]')
if [ -z $(az grafana list --query "[?resourceGroup=='$resourceGroup'].name" -o tsv) ]; then
  echo "Creating Grafana resource in azure..."
  grafana=$(az grafana create -n $grafanaDashboardName -g $resourceGroup | jq -c .)
else
  grafanaDashboardName=$(echo $grafana | jq -r .name)
  echo "Grafana resource ($grafanaDashboardName) found. Use existing..."
fi
grafanaIdentity=$(echo $grafana | jq -r '.identity.principalId')
echo "Grafana identity: $grafanaIdentity"
az role assignment create --assignee $grafanaIdentity --role "Monitoring Data Reader" --scope /subscriptions/$subscriptionId

if [[ -z $(az grafana data-source show -n $grafanaDashboardName --data-source "Azure Managed Prometheus-1" 2>/dev/null | jq .name) ]]; then
  echo "Adding prometheus data source to Grafana..."
  promUrl=$(echo $monitor_resource | jq -r .properties.metrics.prometheusQueryEndpoint)
  az grafana data-source create -n $grafanaDashboardName -g $resourceGroup --definition '{
      "name": "Azure Managed Prometheus-1",
      "type": "prometheus",
      "access": "proxy",
      "url": "'"$promUrl"'",
      "jsonData": {
        "httpMethod": "POST",
        "azureCredentials": { "authType": "msi" }
      }
    }'
fi

if [[ -z $(az grafana folder show -n $grafanaDashboardName --folder "Footprint Dashboards" 2>/dev/null | jq .id) ]]; then
  echo "Creating grafana folder for the first time..."
  az grafana folder create -n $grafanaDashboardName -g $resourceGroup --title "Footprint Dashboards"
fi

if [[ -z $(az grafana dashboard list -n $grafanaDashboardName  --query "[?title=='Memory Footprint / Namespace (Workloads)']" -o json | jq '.[].id') ]]; then
  echo "Creating grafana dashboard..."
  az grafana dashboard create \
    -n $grafanaDashboardName \
    -g $resourceGroup \
    --title "Memory Footprint / Namespace (Workloads)" \
    --folder "Footprint Dashboards" \
    --definition $BASEDIR/../monitoring/mem_by_ns.json
fi

if [[ -z $clusterName || -z $(az connectedk8s show -n $clusterName -g $resourceGroup 2>/dev/null | jq .name) ]]; then
  echo "Arc connected cluster not provided or not found. Skipping azmon-extension create."
else
  echo "Creating k8s-extension azuremonitor-metrics..."
  workspaceId=$(echo $monitor_resource | jq -r .id)
  if [[ -z $( az k8s-extension show --resource-group $resourceGroup --cluster-name $clusterName --cluster-type connectedClusters --name azuremonitor-metrics 2>/dev/null | jq .name) ]]; then
    az k8s-extension create --name azuremonitor-metrics \
      --cluster-name $clusterName \
      --resource-group $resourceGroup \
      --cluster-type connectedClusters \
      --extension-type Microsoft.AzureMonitor.Containers.Metrics \
      --configuration-settings azure-monitor-workspace-resource-id=$workspaceId
  fi  
fi
