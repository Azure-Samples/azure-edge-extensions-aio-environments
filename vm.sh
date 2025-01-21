#!/bin/bash

az vm extension set \
            --resource-group rg-arc-vmnext \
            --vm-name arc-vmnext \
            --name customScript \
            --publisher Microsoft.Azure.Extensions \
            --force-update \
            --protected-settings "{\"commandToExecute\": \" \
                export KUBECONFIG=/etc/rancher/k3s/k3s.yaml && \
                notReadyNotes=\$(kubectl get nodes | grep NotReady | awk '{print \$1}' 2>/dev/null) && \
                len=\${#notReadyNotes} && \
                echo \"\"not ready\$len\"\" && \
                if [[ -z \$notReadyNotes ]]; then echo \"\"xxxx\"\" && kubectl delete node \"\"\$notReadyNotes\"\"; fi && \
                kubectl config use-context default && \
                kubectl get pods -A -v6 \
            \"}"
            