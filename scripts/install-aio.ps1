Write-Host "Installing AIO"
Write-Host "Yet to be implemented"

# $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; Remove-Item .\AzureCLI.msi

# $url = "https://raw.githubusercontent.com/Azure/AKS-Edge/main/tools/scripts/AksEdgeQuickStart/AksEdgeQuickStartForAio.ps1"
# Invoke-WebRequest -Uri $url -OutFile .\AksEdgeQuickStartForAio.ps1
# Unblock-File .\AksEdgeQuickStartForAio.ps1
# Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# .\AksEdgeQuickStartForAio.ps1 -SubscriptionId "<SUBSCRIPTION_ID>" -TenantId "<TENANT_ID>" -ResourceGroupName "<RESOURCE_GROUP_NAME>"  -Location "<LOCATION>"  -ClusterName "<CLUSTER_NAME>"

Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco install kubernetes-helm -y
