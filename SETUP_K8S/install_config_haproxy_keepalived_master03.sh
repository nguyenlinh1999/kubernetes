#!/bin/bash

#set Variable
IP_VIP_K8S="10.15.13.117"
IP_MASTER01="10.15.13.111"
IP_MASTER02="10.15.13.112"
IP_MASTER03="10.15.13.113"

HOST_VIP="k8s-master-vip"
HOST_MASTER01="k8s-master01"
HOST_MASTER02="k8s-master02"
HOST_MASTER03="k8s-master03"
APISERVER_PORT=6443

#Install haproxy and keepalived
yum install haproxy keepalived -y

####Config haproxy and keepalived###
###haproxy
mv /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.default
cat <<EOF | sudo tee /etc/haproxy/haproxy.cfg
global
        log /dev/log    local0
        log /dev/log    local1 notice
        chroot /var/lib/haproxy
        stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
        stats timeout 30s
        user haproxy
        group haproxy
        daemon

        # Default SSL material locations
        ca-base /etc/ssl/certs
        crt-base /etc/ssl/private

        # See: https://ssl-config.mozilla.org/#server=haproxy&server-version=2.0.3&config=intermediate
        ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
        ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
        ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets

defaults
        log     global
        mode    http
        option  httplog
        option  dontlognull
        timeout connect 5000
        timeout client  50000
        timeout server  50000
        errorfile 400 /etc/haproxy/errors/400.http
        errorfile 403 /etc/haproxy/errors/403.http
        errorfile 408 /etc/haproxy/errors/408.http
        errorfile 500 /etc/haproxy/errors/500.http
        errorfile 502 /etc/haproxy/errors/502.http
        errorfile 503 /etc/haproxy/errors/503.http
        errorfile 504 /etc/haproxy/errors/504.http
        option http-server-close
        option forwardfor       except 127.0.0.0/8
        option                  redispatch
        retries                 1
        timeout http-request    10s
        timeout queue           20s
        timeout connect         5s
        timeout client          20s
        timeout server          20s
        timeout http-keep-alive 10s
        timeout check           10s
        listen stats
        bind :1936
        mode http
        log global
        maxconn 10
        stats enable
        stats hide-version
        stats refresh 30s
        stats show-node
        stats auth u:p
        stats uri /stats
#KUBERNERTES
frontend kubernetes-frontend
    bind *:8443
    mode tcp
    option tcplog
    default_backend kubernetes-backend

backend kubernetes-backend
    option httpchk GET /healthz
    http-check expect status 200
    mode tcp
    option ssl-hello-chk
    balance roundrobin
    server $HOST_MASTER01 $IP_MASTER01:$APISERVER_PORT check fall 3 rise 2
    server $HOST_MASTER02 $IP_MASTER02:$APISERVER_PORT check fall 3 rise 2
    server $HOST_MASTER03 $IP_MASTER03:$APISERVER_PORT check fall 3 rise 2
EOF

####keepalived
mv /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf.default
cat <<EOF | sudo tee /etc/keepalived/keepalived.conf
global_defs {
    router_id LVS_DEVEL
}
vrrp_script check_apiserver {
  script "/etc/keepalived/check_apiserver.sh"
  interval 3
  weight -2
  fall 10
  rise 2
}

vrrp_instance VI_1 {
    state BACKUP
    preempt
    interface ens192
    virtual_router_id 151
    priority 253
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass P@##D321!
    }
    virtual_ipaddress {
        $IP_VIP_K8S/24
    }
    track_script {
        check_apiserver
    }
}
EOF

#Script check api server keepalived
cat <<EOF | sudo tee /etc/keepalived/check_apiserver.sh
#!/bin/sh
APISERVER_VIP=10.15.13.117
APISERVER_DEST_PORT=6443

errorExit() {
    echo "*** $*" 1>&2
    exit 1
}

curl --silent --max-time 2 --insecure https://localhost:${APISERVER_DEST_PORT}/ -o /dev/null || errorExit "Error GET https://localhost:${APISERVER_DEST_PORT}/"
if ip addr | grep -q ${APISERVER_VIP}; then
    curl --silent --max-time 2 --insecure https://${APISERVER_VIP}:${APISERVER_DEST_PORT}/ -o /dev/null || errorExit "Error GET https://${APISERVER_VIP}:${APISERVER_DEST_PORT}/"
fi
EOF

#Set permission run Script
chmod u+x /etc/keepalived/check_apiserver.sh

#Start keepalived
systemctl start keepalived && systemctl enable keepalived --now
#Start haproxy
systemctl start haproxy && systemctl enable haproxy --now