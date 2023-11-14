#! /bin/bash
LOCATION="eastus"
uuid=$(uuidgen)
az deployment sub create \
   --name arc-footprint-$uuid \
   --location $LOCATION \
   --template-file main-image.bicep \
   --parameters   resourceGroupName="rg-vm-vhdx-arc-footprint-new" \
                  galleryName="igarcfootprint" \
                  imageDefinitionName="id-arc-footprint" \
                  imageVersion="latest" \