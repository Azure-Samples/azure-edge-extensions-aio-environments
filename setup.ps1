Param(
    [string]
    [Parameter(mandatory=$true)]
    $SubscriptionId,

    [string]
    [Parameter(mandatory=$true)]
    $ServicePrincipalName,

    [string]
    [Parameter(mandatory=$true)]
    $VmAdminUsername,

    [securestring]
    [Parameter(mandatory=$true)]
    $VmAdminPassword
)

# Create Service Principal
$azureCredentials = az ad sp create-for-rbac --name $ServicePrincipalName --role owner `
                                --scopes /subscriptions/$SubscriptionId `
                                --json-auth | ConvertFrom-Json
$jsonAzCreds = $azureCredentials | ConvertTo-Json

# Assign Grafana Admin Role to Service Principal
az role assignment create --assignee $azureCredentials.clientId --role "Grafana Admin" --scope /subscriptions/$SubscriptionId

# Get Service Principal Object Id
$spObjectId = az ad sp show --id $azureCredentials.clientId --query id -o tsv

# Get Custom Location SP Object Id
$customLocationsObjectId = az ad sp show --id bc313c14-388c-4e7d-a58e-70017303ee3b --query id -o tsv

gh secret set AZURE_CREDENTIALS -b $jsonAzCreds
gh secret set AZURE_SP_CLIENT_ID -b $azureCredentials.clientId
gh secret set AZURE_SP_CLIENT_SECRET -b $azureCredentials.clientSecret
gh secret set AZURE_SP_OBJECT_ID -b $spObjectId
gh secret set CUSTOM_LOCATIONS_OBJECT_ID -b $customLocationsObjectId
gh secret set VMADMINUSERNAME -b $VmAdminUsername
gh secret set VMADMINPASSWORD -b ($VmAdminPassword | ConvertFrom-SecureString -AsPlainText)
