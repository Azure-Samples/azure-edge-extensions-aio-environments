#!/bin/bash

# Output CSV file
output_file="$HOME/hostmem/cgroup_memory_usage"

# Write CSV header
echo "Cgroup|Memory Usage (bytes)|Total Cache (bytes)|Container Name|Pod Name|Namespace|Timestamp" > "$output_file"

timestamp=$(date +"%Y-%m-%d %H:%M:%S")

# Iterate through cgroups and get memory usage
for cgroup in $(sudo find /sys/fs/cgroup/ -type d); do
    # Extract cgroup name and parent cgroup
    cgroup_name=$(basename "$cgroup")

    # Get memory usage using systemctl
    memory_usage=$(sudo systemctl show --property=MemoryCurrent "$cgroup_name" 2>/dev/null | awk -F= '{print $2}')
    if [ -z "$memory_usage" ]; then
        memory_usage=0
    fi

    # Get total cache 
    if [ -e "$cgroup/memory.stat" ]; then
        total_cache=$(sudo cat "$cgroup/memory.stat" | grep "total_cache" | awk '{print $2}')
    else
        total_cache=0
    fi

    # Check if container
    if [[ "$cgroup_name" == *"cri-containerd"* ]]; then
        # Get container ID
        container_id=$(basename "$cgroup" | awk -F 'cri-containerd-' '{print $2}' | cut -d'.' -f1)
        container_name=$(sudo ctr container info $container_id --format=json | jq -r .Image)
        pod_name=$(sudo ctr container info $container_id --format=json | jq -r '.Labels."io.kubernetes.pod.name"')
        namespace=$(sudo ctr container info $container_id --format=json | jq -r '.Labels."io.kubernetes.pod.namespace"')

        echo "$cgroup_name|$memory_usage|$total_cache|$container_name|$pod_name|$namespace|$timestamp" >> "$output_file"
    else
        echo "$cgroup_name|$memory_usage|$total_cache|||$timestamp" >> "$output_file"
    fi
done