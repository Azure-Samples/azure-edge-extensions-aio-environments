#!/bin/bash
set -e

Usage() {
  echo "Usage: configure-vm-azmon.sh <OPTIONS>"
  echo "Description:"
  echo "  Creates Azure Monitor for VM"
  echo "Options:"
  echo "  -g| Azure resource group (required)"
  echo "  -m| Azure monitor resource name (required)"
  echo "  -v| Azure VM name (required)"
}

while getopts ":g:m:v:" opt; do
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

BASEDIR=$(dirname $0)

vmResource=$(az vm show --name $vmName --resource-group $resourceGroup | jq -c .)
osType=$(echo $vmResource | jq -r .storageProfile.osDisk.osType)

agent=AzureMonitor${osType}Agent
if [[ -z $(az vm extension show --name $agent --vm-name $vmName -g $resourceGroup 2>/dev/null | jq .name) ]]; then
  echo "Installing AzureMonitor agent extension on $vmName..."
  az vm extension set --name $agent --publisher Microsoft.Azure.Monitor --vm-name $vmName -g $resourceGroup
fi
echo $agent installed.
