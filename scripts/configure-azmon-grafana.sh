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
  echo "  -c| Azure Arc resource name. Skips extension install for connected cluster if not provided."
  echo "  -r| The resource group name of the Azure Arc cluster. (default: same as Azure resource group)."
}

while getopts ":g:m:d:c:r:" opt; do
  case $opt in
    g) resourceGroup=$OPTARG
    ;;
    m) monitorName=$OPTARG
    ;;
    d) grafanaName=$OPTARG
    ;;
    c) clusterName=$OPTARG
    ;;
    r) clusterResourceGroup=$OPTARG
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

if [[ $OPTIND -eq 1 ]]; then
  Usage
  exit 1
fi

randoStr=$(tr -dc a-z0-9 </dev/urandom | head -c 4; echo)
grafanaName=${grafanaName:-footprint-$randoStr}
monitorName="${monitorName:-footprint}"
clusterResourceGroup=${clusterResourceGroup:-$resourceGroup}

BASEDIR=$(dirname $0)

if [ -z $resourceGroup ]; then
  echo "Please provide a valid resource group."
  exit 1
else 
  az group show --name $resourceGroup
  echo "Executing script with monitor name: $monitorName and grafana dashboard name: $grafanaName"
fi

location=$(az group show -n $resourceGroup --query location -o tsv)
subscriptionId=$(az account show --query id -o tsv)
monitor_resource=$(az resource show --resource-type Microsoft.monitor/accounts --name $monitorName --resource-group $resourceGroup 2>/dev/null | jq -c .)

if [ -z $monitor_resource ]; then
  echo "Creating new Azure Monitor workspace..."
  monitor_resource=$(az resource create -g $resourceGroup --namespace microsoft.monitor --resource-type accounts --name $monitorName --properties "{}" | jq -c .)
else
  echo "Azure Monitor workspace found. Use existing..."
fi

grafana=$(az grafana list --query "[?resourceGroup=='$resourceGroup']" -o json | jq -c '.[0]')
if [ -z $(az grafana list --query "[?resourceGroup=='$resourceGroup'].name" -o tsv) ]; then
  echo "Creating Grafana resource in azure..."
  grafana=$(az grafana create -n $grafanaName -g $resourceGroup | jq -c .)
else
  grafanaName=$(echo $grafana | jq -r .name)
  echo "Grafana resource ($grafanaName) found. Use existing..."
fi

grafanaIdentity=$(echo $grafana | jq -r '.identity.principalId')
echo "Grafana identity: $grafanaIdentity"
az role assignment create --assignee-object-id $grafanaIdentity --assignee-principal-type ServicePrincipal --role "Monitoring Data Reader" --scope /subscriptions/$subscriptionId/resourceGroups/$resourceGroup

if [[ -z $(az grafana data-source show -n $grafanaName --data-source "Azure Managed Prometheus-1" 2>/dev/null | jq .name) ]]; then
  echo "Adding prometheus data source to Grafana..."
  promUrl=$(echo $monitor_resource | jq -r .properties.metrics.prometheusQueryEndpoint)
  az grafana data-source create -n $grafanaName -g $resourceGroup --definition '{
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

if [[ -z $(az grafana folder show -n $grafanaName --folder "Footprint Dashboards" 2>/dev/null | jq .id) ]]; then
  echo "Creating grafana folder for the first time..."
  az grafana folder create -n $grafanaName -g $resourceGroup --title "Footprint Dashboards"
fi
clusterDashboardName="Memory Footprint - Cluster"
if [[ -z $(az grafana dashboard list -n $grafanaName  --query "[?title=='$clusterDashboardName']" -o json | jq '.[].id') ]]; then
  az grafana dashboard create \
    -n $grafanaName \
    -g $resourceGroup \
    --title "$clusterDashboardName" \
    --folder "Footprint Dashboards" \
    --definition $BASEDIR/../monitoring/mem_by_ns.json
fi

if [[ -z $clusterName || -z $(az connectedk8s show -n $clusterName -g $clusterResourceGroup 2>/dev/null | jq .name) ]]; then
  echo "Arc connected cluster not provided or not found. Skipping azmon-extension create."
else
  echo "Creating k8s-extension azuremonitor-metrics..."
  workspaceId=$(echo $monitor_resource | jq -r .id)
  if [[ -z $( az k8s-extension show --resource-group $clusterResourceGroup --cluster-name $clusterName --cluster-type connectedClusters --name azuremonitor-metrics 2>/dev/null | jq .name) ]]; then
    az k8s-extension create --name azuremonitor-metrics \
      --cluster-name $clusterName \
      --resource-group $clusterResourceGroup \
      --cluster-type connectedClusters \
      --extension-type Microsoft.AzureMonitor.Containers.Metrics \
      --configuration-settings azure-monitor-workspace-resource-id=$workspaceId
  fi  
fi
