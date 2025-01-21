#!/bin/bash

az vm extension set \
            --resource-group rg-arc-exec \
            --vm-name arc-exec \
            --name customScript \
            --publisher Microsoft.Azure.Extensions \
            --force-update \
            --protected-settings "{\"commandToExecute\": \" \
                export KUBECONFIG=/etc/rancher/k3s/k3s.yaml && \
                notReadyNodes=\$(kubectl get nodes | grep NotReady | awk '{print \$1}' 2>/dev/null) && \
                if [ -n \"\"\$notReadyNotes\"\" ]; then kubectl delete node \"\"\$notReadyNotes\"\" fi && \
                kubectl delete node \$(kubectl get nodes | grep NotReady | awk '{print \$1}') && \
                kubectl config use-context default && \
                kubectl get pods -A -v6 \
            \"}"
            