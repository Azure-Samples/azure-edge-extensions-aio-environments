$WarningPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop" 
$ProgressPreference = 'SilentlyContinue'

# Import Configuration Module
$HCIBoxConfig = Import-PowerShellDataFile -Path $Env:HCIBoxConfigFile

Start-Transcript -Path "$($HCIBoxConfig.Paths.LogsDir)\Install-AIO.log"

# Install Azure CLI extension
az extension add --name azure-iot-ops

# Install KV + AIO
az keyvault create --enable-rbac-authorization false --name $HCIBoxConfig.AKSworkloadClusterName --resource-group $env:resourceGroup

az iot ops init --include-dp --simulate-plc --cluster $HCIBoxConfig.AKSworkloadClusterName --resource-group $env:resourceGroup --kv-id $(az keyvault show --name $HCIBoxConfig.AKSworkloadClusterName -o tsv --query id) --sp-app-id "$env:spnClientID" --sp-object-id "$env:spnObjectID" --sp-secret "$env:spnClientSecret" --no-progress

Stop-Transcript
