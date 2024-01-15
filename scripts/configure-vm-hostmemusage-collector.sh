#!/bin/bash
set -e

Usage(){
  echo "Usage: configure-vm-hostmemusage-collector.sh <OPTIONS>"
  echo "Description:"
  echo "  Creates necessary resources to ingest hostmemusage to Azure Monitor/Log Analytics"
  echo "Options:"
  echo "  -g| Azure resource group (required)"
  echo "  -m| Azure monitor resource name (required)"
  echo "  -v| Azure VM name (required)"
  echo "  -l| Log analytics workspace name (default: la-footprint)"
}

while getopts ":g:m:v:l:" opt; do
  case $opt in
    g) resourceGroup=$OPTARG
    ;;
    m) monitorName=$OPTARG
    ;;
    v) vmName=$OPTARG
    ;;
    l) laName=$OPTARG
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

if [[ $OPTIND -eq 1 || -z $resourceGroup || -z $vmName || -z $monitorName ]]; then
  Usage
  exit 1
fi

laName="${laName:-la-footprint}"
BASEDIR=$(dirname $0)

monitor_resource=$(az resource show --resource-type Microsoft.monitor/accounts --name $monitorName --resource-group $resourceGroup | jq -c .)
vmResource=$(az vm show --name $vmName --resource-group $resourceGroup | jq -c .)
osType=$(echo $vmResource | jq -r .storageProfile.osDisk.osType)
ruleName="$vmName-hostmemcollector"

laId=$(az monitor log-analytics workspace show --name $laName -g $resourceGroup 2>/dev/null | jq -r .id)
if [ -z $laId ]; then
  echo "Creating new Log Analytics Workspace..."
  laId=$(az monitor log-analytics workspace create --resource-group $resourceGroup --name $laName --query id -o tsv)
else
  echo "Log analytics workspace found: $laId. Use existing..."
fi

if [ "$osType" == "Windows" ]; then
    tableName="ResidentSetSummary_CL"
    columns="TimeGenerated=datetime TraceProcessName=string SizeMB=real Process=string PCategory=string PPriority=string Description=string MMList=string"
    #az vm run-command create -g $resourceGroup --vm-name $vmName --script "Register-ScheduledJob -Name "Collect-HostmemUsage" -RunEvery (New-TimeSpan -Minutes 4) -FilePath \"C:\HostmemLogs\collect.ps1\"" --run-command-name "StartJob"
else
    tableName="CgroupMem_CL"
    columns="TimeGenerated=datetime Cgroup=string MemoryUsage=real TotalCache=real ContainerName=string PodName=string Namespace=string"
fi

if [[ -z $(az monitor log-analytics workspace table show --name $tableName --resource-group $resourceGroup --workspace-name $laName 2>/dev/null | jq .id) ]]; then
    echo "Creating new $tableName table in log analytics workspace..."
    az monitor log-analytics workspace table create --name $tableName --resource-group $resourceGroup --workspace-name $laName \
        --columns $columns
else
  echo "Log analytics table already exists"
fi

ruleId=$(az monitor data-collection rule show --name $ruleName -g $resourceGroup 2>/dev/null | jq -r .id)
dataCollectionEndpointId=$(echo $monitor_resource | jq -r .properties.defaultIngestionSettings.dataCollectionEndpointResourceId)
if [ -z $ruleId ]; then
  echo "Creating data collection rule..."
  ruleId=$(az deployment group create -n hostmemdc -g $resourceGroup --template-file $BASEDIR/hostmemcollector.$osType.bicep \
    --parameters ruleName=$ruleName dataCollectionEndpointId=$dataCollectionEndpointId logAnalyticsWorkspaceId=$laId | jq -r '.properties.outputResources[0].id')
else
  echo "Data collection rule found: $ruleId"
fi


vmId=$(echo $vmResource | jq -r .id)
if [[ -z $(az monitor data-collection rule association show --name configurationAccessEndpoint --resource $vmId 2>/dev/null | jq .name) ]]; then
  echo "Associate vm $vmId with rule..."
  az monitor data-collection rule association create --name configurationAccessEndpoint --resource $vmId --endpoint-id $dataCollectionEndpointId
else
  echo "Association vm with endpoint already created."
fi

if [[ -z $(az monitor data-collection rule association show --name $vmName --resource $vmId 2>/dev/null | jq .name) ]]; then
  echo "Associate vm $vmId with rule..."
  az monitor data-collection rule association create --name $vmName --resource $vmId --rule-id $ruleId
else
  echo "Association vm with rule already created."
fi

