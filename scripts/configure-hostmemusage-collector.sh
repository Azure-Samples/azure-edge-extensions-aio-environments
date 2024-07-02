#!/bin/bash
set -e

Usage() {
  echo "Usage: configure-vm-hostmemusage-collector.sh <OPTIONS>"
  echo "Description:"
  echo "  Creates necessary resources to ingest hostmemusage to Azure Monitor/Log Analytics"
  echo "Options:"
  echo "  -g| Azure resource group (required)"
  echo "  -m| Azure monitor resource name (required)"
  echo "  -v| Azure VM ID (required)"
  echo "  -l| Log analytics workspace name (default: la-footprint)"
  echo "  -o| OS Type (default: Windows)"
}

while getopts ":g:m:v:l:o:" opt; do
  case $opt in
  g)
    resourceGroup=$OPTARG
    ;;
  m)
    monitorName=$OPTARG
    ;;
  v)
    vmId=$OPTARG
    ;;
  l)
    laName=$OPTARG
    ;;
  o)
    osType=$OPTARG
    ;;
  \?)
    echo "Invalid option -$OPTARG" >&2
    exit 1
    ;;
  esac

  case $OPTARG in
  -*)
    echo "Option $opt needs a valid argument"
    exit 1
    ;;
  esac
done

if [[ $OPTIND -eq 1 || -z $resourceGroup || -z $vmId || -z $monitorName ]]; then
  Usage
  exit 1
fi

laName="${laName:-la-footprint}"
BASEDIR=$(dirname $0)

monitor_resource=$(az resource show --resource-type Microsoft.monitor/accounts --name $monitorName --resource-group $resourceGroup | jq -c .)
vmResource=$(az resource show --ids $vmId)
vmName=$(echo $vmResource | jq -r .name)
vmResourceGroup=$(echo $vmResource | jq -r .resourceGroup)
osType="${osType:-Windows}"
ruleName="$vmName-hostmemcollector"
subscriptionId=$(az account show --query id -o tsv)

grafanaName=$(az grafana list --query "[?resourceGroup=='$resourceGroup'].name" -o tsv)
if [ -z $grafanaName ]; then
  echo "Error: Grafana resource not found. Please create a Grafana resource first."
  exit 1
else
  echo "Grafana resource ($grafanaName) found. Use existing..."
fi

allDashboardName="Memory Footprint $osType"
hostDashboardName="Memory Footprint - Host $osType"
echo "Creating grafana dashboard..."
sed -i "s/##SUBSCRIPTION_ID##/$subscriptionId/g" monitoring/mem_by_all.json
sed -i "s/##SUBSCRIPTION_ID##/$subscriptionId/g" monitoring/mem_by_proc.json
sed -i "s/##RESOURCE_GROUP##/$resourceGroup/g" monitoring/mem_by_all.json
sed -i "s/##RESOURCE_GROUP##/$resourceGroup/g" monitoring/mem_by_proc.json
if [ $osType == "Linux" ]; then
  ts_query='CgroupMem_CL\\r\\n| where $__timeFilter(TimeGenerated)\\r\\n| summarize Memory=sum(MemoryUsage) by PodName, Namespace, TimeGenerated\\r\\n| project Memory, Workload=strcat(Namespace, \\"/\\", PodName), TimeGenerated\\r\\n| order by TimeGenerated asc\\r\\n'
  t_query='CgroupMem_CL\\r\\n| where $__timeFilter(TimeGenerated)\\r\\n| summarize Memory=avg(MemoryUsage) by PodName, Namespace\\r\\n| project Workload=strcat(Namespace, \\"/\\", PodName), Memory\\r\\n| order by Memory desc \\r\\n'
  echo "Linux OS detected. Using Linux queries..."
  echo $ts_query
  echo $t_query
  sed -i "s?##TIME_SERIES_QUERY##?$ts_query?g" monitoring/mem_by_all.json
  sed -i "s?##TABLE_QUERY##?$t_query?g" monitoring/mem_by_all.json
  sed -i "s/##MEM_UNIT##/decbytes/g" monitoring/mem_by_all.json
  sed -i "s?##TIME_SERIES_QUERY##?$ts_query?g" monitoring/mem_by_proc.json
  sed -i "s?##TABLE_QUERY##?$t_query?g" monitoring/mem_by_proc.json
  sed -i "s/##MEM_UNIT##/decbytes/g" monitoring/mem_by_proc.json
else
  echo "Windows OS detected. Using Windows queries..."
  echo $ts_query
  echo $t_query
  ts_query='ResidentSetSummary_CL\\r\\n| where $__timeFilter(TimeGenerated)\\r\\n| summarize Memory=sum(SizeMB)*1024 by TraceProcessName, TimeGenerated\\r\\n| order by TimeGenerated asc'
  t_query='ResidentSetSummary_CL\\r\\n| where $__timeFilter(TimeGenerated)\\r\\n| summarize Memory=avg(SizeMB)*1024 by TraceProcessName\\r\\n| order by Memory desc'
  sed -i "s/##TIME_SERIES_QUERY##/$ts_query/g" monitoring/mem_by_all.json
  sed -i "s/##TABLE_QUERY##/$t_query/g" monitoring/mem_by_all.json
  sed -i "s/##MEM_UNIT##/deckbytes/g" monitoring/mem_by_all.json
  sed -i "s/##TIME_SERIES_QUERY##/$ts_query/g" monitoring/mem_by_proc.json
  sed -i "s/##TABLE_QUERY##/$t_query/g" monitoring/mem_by_proc.json
  sed -i "s/##MEM_UNIT##/deckbytes/g" monitoring/mem_by_proc.json
fi
if [[ -z $(az grafana dashboard list -n $grafanaName --query "[?title=='$hostDashboardName']" -o json | jq '.[].id') ]]; then
  az grafana dashboard create \
    -n $grafanaName \
    -g $resourceGroup \
    --title "$hostDashboardName" \
    --folder "Footprint Dashboards" \
    --definition $BASEDIR/../monitoring/mem_by_proc.json
fi
if [[ -z $(az grafana dashboard list -n $grafanaName --query "[?title=='$allDashboardName']" -o json | jq '.[].id') ]]; then
  az grafana dashboard create \
    -n $grafanaName \
    -g $resourceGroup \
    --title "$allDashboardName" \
    --folder "Footprint Dashboards" \
    --definition $BASEDIR/../monitoring/mem_by_all.json
fi

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

ruleId=$(az monitor data-collection rule show --name $ruleName -g $vmResourceGroup 2>/dev/null | jq -r .id)
dataCollectionEndpointId=$(echo $monitor_resource | jq -r .properties.defaultIngestionSettings.dataCollectionEndpointResourceId)
if [ -z $ruleId ]; then
  echo "Creating data collection rule..."
  ruleId=$(az deployment group create -n hostmemdc -g $vmResourceGroup --template-file $BASEDIR/hostmemcollector.$osType.bicep \
    --parameters ruleName=$ruleName dataCollectionEndpointId=$dataCollectionEndpointId logAnalyticsWorkspaceId=$laId | jq -r '.properties.outputResources[0].id')
else
  echo "Data collection rule found: $ruleId"
fi

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
