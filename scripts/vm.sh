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
