#!/bin/bash
set -e

Usage() {
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
  g)
    resourceGroup=$OPTARG
    ;;
  m)
    monitorName=$OPTARG
    ;;
  v)
    vmName=$OPTARG
    ;;
  l)
    laName=$OPTARG
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

if [[ $OPTIND -eq 1 || -z $resourceGroup || -z $vmName || -z $monitorName ]]; then
  Usage
  exit 1
fi

laName="${laName:-la-footprint}"
BASEDIR=$(dirname $0)

vmResource=$(az vm show --name $vmName --resource-group $resourceGroup | jq -c .)
osType=$(echo $vmResource | jq -r .storageProfile.osDisk.osType)

agent=AzureMonitor${osType}Agent
if [[ -z $(az vm extension show --name $agent --vm-name $vmName -g $resourceGroup 2>/dev/null | jq .name) ]]; then
  echo "Installing AzureMonitor agent extension on $vmName..."
  az vm extension set --name $agent --publisher Microsoft.Azure.Monitor --vm-name $vmName -g $resourceGroup
fi
echo $agent installed.

vmId=$(echo $vmResource | jq -r .id)
$BASEDIR/configure-hostmemusage-collector.sh -g $resourceGroup -m $monitorName -v $vmId -l $laName -o $osType
