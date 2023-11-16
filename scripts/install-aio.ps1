Write-Host "Installing AIO"
Write-Host "Yet to be implemented"

$ApplicationName = {0}
$SubscriptionId = {1}
$TenantId = {2}
$ResourceGroupName = {3}
$Location = {4}
$AksClusterName = {5}

$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; Remove-Item .\AzureCLI.msi

$url = "https://raw.githubusercontent.com/Azure/AKS-Edge/main/tools/scripts/AksEdgeQuickStart/AksEdgeQuickStartForAio.ps1"
Invoke-WebRequest -Uri $url -OutFile .\AksEdgeQuickStartForAio.ps1
Unblock-File .\AksEdgeQuickStartForAio.ps1
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

.\AksEdgeQuickStartForAio.ps1 -SubscriptionId $SubscriptionId -TenantId $TenantId -ResourceGroupName $ResourceGroupName  -Location $Location  -ClusterName $AksClusterName

$SpResult = (az ad sp create-for-rbac -n $ApplicationName --role "Contributor" --scopes /subscriptions/$SubscriptionId --only-show-errors)

if (!$?) {
    Write-Error "Error creating Service Principal on Subscription $SubscriptionId"
    Exit 1
}

$AkseeServicePrincipal = $SpResult | ConvertFrom-Json

# Sleep to allow SP to be replicated across AAD instances.
# TODO: Update this to be more deterministic.
Start-Sleep -s 30

$AkseeClientId = $AkseeServicePrincipal.appId
$AkseeClientSecret = $AkseeServicePrincipal.password
$AkseeTenantId = $AkseeServicePrincipal.tenant

# Login as service principal
az login --service-principal --username $AkseeClientId --password $AkseeClientSecret --tenant $AkseeTenantId

# Set default subscription to run commands against
az account set --subscription $SubscriptionId

# Making extension install dynamic
az config set extension.use_dynamic_install=yes_without_prompt

# Register resource providers
az provider register -n "Microsoft.ExtendedLocation" --wait
az provider register -n "Microsoft.Kubernetes" --wait
az provider register -n "Microsoft.KubernetesConfiguration" --wait
az provider register -n "Microsoft.IoTOperationsOrchestrator" --wait
az provider register -n "Microsoft.IoTOperationsMQ" --wait
az provider register -n "Microsoft.IoTOperationsDataProcessor" --wait
az provider register -n "Microsoft.DeviceRegistry" --wait

# Arc-enable Aks cluster
az connectedk8s connect -n $AksClusterName -l $Location -g $ResourceGroupName --subscription $SubscriptionId

# Enable custom location support
$ObjectId = (az ad sp show --id bc313c14-388c-4e7d-a58e-70017303ee3b --query id -o tsv)
az connectedk8s enable-features -n $AksClusterName -g $ResourceGroupName --custom-locations-oid $ObjectId --features cluster-connect custom-locations

# Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
# choco install kubernetes-helm -y
