#! /bin/bash
LOCATION="eastus"
az deployment sub create \
   --name arc-footprint-deployment \
   --location $LOCATION \
   --template-file main-image.bicep \
   --parameters   resourceGroupName="rg-vm-vhdx-arc-footprint-new" \
                  galleryName="igarcfootprint" \
                  imageDefinitionName="id-arc-footprint" \
                  imageVersion="latest" \