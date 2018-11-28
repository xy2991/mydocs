#!/bin/bash

HOST=$(ip add|grep '10.64'|awk -F '[ /]+' '{print $3}')

openssl rand -base64 48 > passphrase.txt

openssl genrsa -des3 -passout file:passphrase.txt -out server.key 2048

openssl req -new -passin file:passphrase.txt -days 3650 -key server.key  -out server.csr -subj "/C=CN/ST=Chongqing/L=Chongqing/O=Changan/OU=IT Department/CN=$HOST"

cp server.key server.key.org

openssl rsa -in server.key.org -passin file:passphrase.txt -out server.key

openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt

cat server.key server.crt | tee server-allinone.pem
