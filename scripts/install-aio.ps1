Write-Host "Installing AIO"
Write-Host "Yet to be implemented"

Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco install kubernetes-helm

# wsl --install

# sudo -e /etc/wsl.conf

# Add the following:
# [boot]
# systemd=true

# sudo sh -c 'echo :WSLInterop:M::MZ::/init:PF > /usr/lib/binfmt.d/WSLInterop.conf'
# sudo systemctl unmask systemd-binfmt.service
# sudo systemctl restart systemd-binfmt
# sudo systemctl mask systemd-binfmt.service

# mkdir ~/.kube
# cp ~/.kube/config ~/.kube/config.back
# sudo KUBECONFIG=~/.kube/config:/etc/rancher/k3s/k3s.yaml kubectl config view --flatten > ~/.kube/merged
# mv ~/.kube/merged ~/.kube/config
# chmod  0600 ~/.kube/config
# export KUBECONFIG=~/.kube/config
# #switch to k3s context
# kubectl config use-context default

# sudo apt install nfs-common

# echo fs.inotify.max_user_instances=8192 | sudo tee -a /etc/sysctl.conf
# echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf

# sudo sysctl -p