#!/bin/bash

#set Variable
IP_VIP_K8S="10.15.13.117"
IP_MASTER01="10.15.13.111"
IP_MASTER02="10.15.13.112"
IP_MASTER03="10.15.13.113"
IP_WORKER01="10.15.13.114"
IP_WORKER02="10.15.13.115"
IP_WORKER03="10.15.13.116"

HOST_VIP="k8s-master-vip"
HOST_MASTER01="k8s-master01"
HOST_MASTER02="k8s-master02"
HOST_MASTER03="k8s-master03"
HOST_WORKER01="k8s-worker01"
HOST_WORKER02="k8s-worker02"
HOST_WORKER03="k8s-worker03"

#Install docker
yum install -y yum-utils
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce docker-ce-cli containerd.io

#Start Docker
systemctl start docker && systemctl enable docker

#Config Docker Daemon run with systemd
mkdir /etc/docker
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "insecure-registries":["10.30.19.132:8080"],
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

#Restart Docker
systemctl daemon-reload && systemctl restart docker

#Install kubeadm, kubelet and kubectl version 1.21.5.0
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

yum update -y
yum install -y kubelet-1.21.5-0 kubeadm-1.21.5-0 kubectl-1.21.5-0 --disableexcludes=kubernetes
systemctl enable --now kubelet && systemctl start kubelet

#Join k8s cluster
kubeadm join



