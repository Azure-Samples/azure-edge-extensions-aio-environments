# Optimization for Arc memory footprintview

This repository sets up the infrastructure to create vhdx images for the Arc memory footprint investigations.
Because of the nature of efficiency, customer demand a low memory footprint to save costs in terms of hardware and devices.
This infrastructure enables you to install instrumentation tools and collect memory dumps components.

## Workflows

### Image Creation

Once you enabled the GitHub Action workflows you can run the **Build VHDX** pipeline to create the vhdx images based on the selected parameters and configuration.
It installs the corresponding version of [AKS-EE](https://learn.microsoft.com/en-us/azure/aks/hybrid/aks-edge-overview) and [Azure IoT Operations](https://learn.microsoft.com/en-us/azure/iot-operations/).

### VM Creation

On top of the created vhdx images you can create a VM with the **Create VM** pipeline that references the image in the image gallery.
