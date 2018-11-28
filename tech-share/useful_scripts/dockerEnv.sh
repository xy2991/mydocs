#!/bin/sh

#########pre##########
HOST=$(ip add|grep '10.64'|awk -F '[ /]+' '{print $3}')
caPath=/etc/docker/ssl
[[ -z ${HOST} ]] && exit -1
[ -d $caPath ] || mkdir -p $caPath
[ -d ~/.docker ] || mkdir -p ~/.docker

#########Func#########
function genSsl() {
    cd $caPath
    openssl rand -base64 48 > passphrase.txt
    openssl genrsa -aes256 -passout file:passphrase.txt -out ca-key.pem 4096
    openssl req -new -passin file:passphrase.txt -x509 -days 3650 -key ca-key.pem -sha256 -out ca.pem -subj "/C=CN/ST=Chongqing/L=Chongqing/O=Changan/OU=IT Department/CN=$HOST"
    openssl genrsa  -out server-key.pem -passout file:passphrase.txt 4096
    openssl req -subj "/CN=$HOST" -sha256 -new -key server-key.pem -passin file:passphrase.txt  -out server.csr
    echo subjectAltName = DNS:$HOST,IP:$HOST,IP:127.0.0.1 > extfile.cnf
    openssl x509 -req -days 3650 -sha256 -passin file:passphrase.txt -in server.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server-cert.pem -extfile extfile.cnf
    openssl genrsa -out key.pem 4096
    openssl req -subj '/CN=client' -new -key key.pem -out client.csr
    echo extendedKeyUsage = clientAuth > extfile.cnf
    openssl x509 -req -days 3650 -sha256 -in client.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out cert.pem -passin file:passphrase.txt  -extfile extfile.cnf
    rm -f client.csr server.csr
    chmod -v 0400 ca-key.pem key.pem server-key.pem
    chmod -v 0444 ca.pem server-cert.pem cert.pem
}

function modDocker() {
    cat > /etc/docker/daemon.json <<EOF
{
    "hosts": ["tcp://0.0.0.0:2376","unix:///var/run/docker.sock"],
    "bip": "244.244.0.1/16",
    "tls": true,
    "tlscacert": "/etc/docker/ssl/ca.pem",
    "tlscert": "/etc/docker/ssl/server-cert.pem",
    "tlskey": "/etc/docker/ssl/server-key.pem",
    "tlsverify": true
}
EOF
    cp -v $caPath/{ca,cert,key}.pem ~/.docker
    export DOCKER_HOST=tcp://$HOST:2376 DOCKER_TLS_VERIFY=1
    echo "export DOCKER_HOST=tcp://$HOST:2376 DOCKER_TLS_VERIFY=1" >> /etc/profile
    source /etc/profile
}

function modSsh() {
    sshdconf='/etc/ssh/sshd_config'
    ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
    cp ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys
    grep -i '^RSAAuthentication no' $sshdconf && sed -i 's/^RSAAuthentication no/RSAAuthentication yes/' $sshdconf
    grep -i '^PubkeyAuthentication no' $sshdconf && sed -i 's/^PubkeyAuthentication no/PubkeyAuthentication yes/' $sshdconf
    grep -i '^PubkeyAuthentication yes' $sshdconf || sed -i '/\#PubkeyAuthentication yes/a\PubkeyAuthentication yes' $sshdconf
    grep -i '^RSAAuthentication yes' $sshdconf || sed -i '/^PubkeyAuthentication yes/a\RSAAuthentication yes' $sshdconf
    chk2=$(grep -i '^RSAAuthentication yes' $sshdconf|wc -l)
    if [ $chk2 -ne 1 ]; then echo "The configuration of RSAAuthentication maybe wrong，please cheak the $sshdconf"; exit 1; fi
    chk3=$(grep -i '^PubkeyAuthentication yes' $sshdconf|wc -l)
    if [ $chk3 -ne 1 ]; then echo "The configuration of PubkeyAuthentication maybe wrong，please cheak the $sshdconf"; exit 1; fi
    systemctl restart sshd
}

function cpCacert() {
    jendir="/u01/devopts/data-jenkins/.docker/${HOST}"
    prifile='/root/.ssh/id_rsa'
    prikey="-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAyRZL/Q5+G4GKYb0gisWBuWjF5IOzTUOBYLMS7glPP/t+GHl7
Wd73Q05SfVvm0Nw9VkLbLAhbhgvVvZEeAN4FvGqsG6sNRqI25O3jO8nvEq00rv7y
P14xgkMu0f+Z34cndisMurNcYzFY3LN8yUqEksxfvWyuF/gMCDo0UKwFmTrpMVo8
ysKaqbh2i/+Y8QLOWs8+BWde7U9D0noxvAEFZlmk/F6Zc78403k6TaQPxYyJ5ZqQ
oPegIZD802DEdjHIgv5l5qfKk1LrAYqSDtM4QvKFsIH6f2fO85r+pr34DqjTG0vk
QLpyXHCnoioZPQhA1mExyT6qSAlATBh+6DbHvQIDAQABAoIBAHD3Lq82AhBPwL7R
scNj21Gek3WhqwvfvYHmd97zqerGzPrQ3EQLpxrPmDXGeC+jWm3oVxowg8IVSfkZ
2iIgmFZWEuPkPywMGwyWu44uDjmOxkb9AHgq4WNNfLMKhZX2ZmvTGW6VLnSnF0W9
K4Aldb7GQ461zEO43IGOuS8MxIRkfQcrX1+dlMoTUh+BoiUkOoE5MISfgx8GGaTG
U/jaeMEYYq8Nb3O+OMWJ/RyHHvF2VY3BaTejmwki+Ad16zRsbY/DRVg1M8Qp0D9b
kvj7AuBAqjj15OecLHOAfm0G6z+Tr6u4y5roZBBo0S8zLHUvLh59coZLwNAg66eo
vRpKh10CgYEA+ANZTga4iA02uQQoF4tNDjhxdKFlXdCiwzY0S9dsKVpRfPDB8DBY
Ol0OY6GZx9RWlS0WT7WmQyVovadlPD5+Q52LFLjJI5owvnc6RnvMaXUhGGtdypmt
w4/lDv4lB+9Wj3ahWW819ey63ubCuoiKP3w2BMwbhj0I64f0394R6JsCgYEAz5AV
kPrIdyUKjWMaK1Svh58eKKNtwvWoQ1+emKBflgXyXcVB7k70O6V6oABjnu5YFSoO
tUTCbSHixmyyhlEjlfHJa1A3HMfS07CQpxqU26UYgdj3yMFjYMV9DwAfjyCPOqge
ZWJFhGDhJ5weTMw7uy6Ez41RtNNbFlQQHm5WOocCgYBVgboRd6m5ZmzefvtfmqxX
YchkAJ0VKjBjg1WmbEAjRbtgixUiPVi9zoV+fiGpzqCHUAMoOiV3cvdYo9T4X0dj
AncIDulx9+AkWrDhyh7goPxnEeVFS5SoHv1HHQIhaTf7wFfCoOAGyLZo0UCD1T1s
w+NP5hr7PiHMKpSXdlXQTwKBgQDBplP4p4FQZ6aossU/mAsMJVAl6hQFyNvrv9Jf
44BKn9G32sngZJlI7OKzVKmdJhHX7R070aLz3qGNLuyAlEL3KlYZYQWKPIReLGVJ
AmvPYQC0ZJEJJCRrrNU4oYzQJDh9KUzymfTxxNFL+0PpssInqQcP/XE1m9tnwZYo
Thj1EQKBgQCY8H8CAiMZAQObU+DwDAXtRkrXh5mjWArarLaOIkBgVLQf0dcxPBwI
cx8erdPn2IgtifRGySXLg0gm22n63mF4f2mHMEM/0i6TXFP4CkPhpoxUkKLOUxTG
ijvtb+InrhOSXEAydJCQQEU9a5qa9m7cG9ydQP+Z9cr8Afek7vimSg==
-----END RSA PRIVATE KEY-----"

     if [ ! -d /root/.ssh ];then
         mkdir /root/.ssh
     fi
     if [ -f ${prifile} ];then
         mv ${prifile} ${prifile}-bak66
     fi
     [ -f ~/.ssh/id_rsa.pub ] && mv ~/.ssh/id_rsa.pub ~/.ssh/id_rsa.pub-bak66
     echo "${prikey}" > ${prifile}
     chmod 600 ${prifile}
     ssh root@10.64.250.68 /bin/bash <<EOF
        [ -d ${jendir} ] && rm -rf ${jendir}
        mkdir -p ${jendir}
        exit
EOF
    scp ${caPath}/{ca,cert,key}.pem root@10.64.250.68:${jendir}
    ssh root@10.64.250.68 chown -R admin.admin ${jendir}

    if [ ! -d /etc/docker/certs.d/10.64.250.16 ];then
        mkdir -p /etc/docker/certs.d/10.64.250.16; cd /etc/docker/certs.d/10.64.250.16
        scp root@10.64.250.68:/etc/docker/certs.d/10.64.250.16/ca.crt .
    fi
    rm -f ${prifile}
    [ -f ${prifile}-bak66 ] && mv ${prifile}-bak66 ${prifile}
    [ -f ~/.ssh/id_rsa.pub-bak66 ] && mv ~/.ssh/id_rsa.pub-bak66 ~/.ssh/id_rsa.pub
    systemctl daemon-reload
    echo "restarting docker"
    systemctl restart docker
    if [ $? -ne 0 ];then
        printf "docker restart failed"
        exit -1
    else
        echo "restarted docker"
    fi
}

#########################-main-#########################
genSsl
modDocker
cpCacert
