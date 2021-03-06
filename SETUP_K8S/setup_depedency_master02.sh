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

#set hostname
hostnamectl set-hostname $HOST_MASTER02
echo "$IP_VIP_K8S   $HOST_VIP" >> /etc/hosts
echo "$IP_MASTER01   $HOST_MASTER01" >> /etc/hosts
echo "$IP_MASTER02   $HOST_MASTER02" >> /etc/hosts
echo "$IP_MASTER03   $HOST_MASTER03" >> /etc/hosts
echo "$IP_WORKER01   $HOST_WORKER01" >> /etc/hosts
echo "$IP_WORKER02   $HOST_WORKER02" >> /etc/hosts
echo "$IP_WORKER03   $HOST_WORKER03" >> /etc/hosts

#set allow trafic iptables
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

#apply config
sysctl --system

#disable swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

#disable selinux
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config

#disable firewall
systemctl stop firewalld && systemctl disable firewalld
systemctl stop iptables && systemctl stop iptables
yum update -y
reboot
