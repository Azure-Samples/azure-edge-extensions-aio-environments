#! /bin/bash
LOCATION=$1
PUBLISHER=$2
OFFER=$3
SKU=$4
VERSION=$5
ARCHITECTURE=$6
VMSIZE=$7
az deployment sub create \
   --name arc-footprint-deployment \
   --location $LOCATION \
   --template-file ./main-image.bicep \
   --parameters   applicationName="vm-vhdx-arc-footprint" \
                  galleryName="igarcfootprint" \
                  imageDefinitionName="id-arc-footprint" \
                  imageBuilderName="arc-footprint-image" \
                  imageVersion="latest" \
                  publisher=$PUBLISHER \
                  offer=$OFFER \
                  sku=$SKU \
                  version=$VERSION \
                  architecture=$ARCHITECTURE \
                  vmSize=$VMSIZE

az deployment sub create `                                              
   --name arc-footprint-deployment `
   --location eastus `
   --template-file ./main-image.bicep `
   --parameters   applicationName="vm-vhdx-arc-footprint" `
                  spClientId="ea106e24-425a-4c72-88e4-8b46d2d4b127" \
                  spClientSecret="QOI8Q~eroJpgI.gdPne9yG30a4LEm4wtbn.l-dmy" \
                  galleryName="igarcfootprint" `
                  imageDefinitionName="id-arc-footprint" `
                  imageBuilderName="arc-footprint-image" `
                  imageVersion="latest" `
                  publisher="MicrosoftWindowsServer" `
                  offer="WindowsServer" `
                  sku="2022-datacenter-g2" `
                  version="latest" `
                  architecture="x64" `
                  vmSize="Standard_D4s_v5"