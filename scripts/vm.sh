#! /bin/bash
LOCATION=$1
az deployment sub create \
   --name arc-footprint-deployment \
   --location $LOCATION \
   --template-file ./main-image.bicep \
   --parameters   resourceGroupName="rg-vm-vhdx-arc-footprint" \
                  galleryName="igarcfootprint" \
                  imageDefinitionName="id-arc-footprint" \
                  imageVersion="latest"