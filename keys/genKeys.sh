#!/bin/sh

openssl req -config ./openssl_minuteman.cnf -newkey rsa:2048 -nodes -keyout domain_mm.key -x509 -days 365 -out domain_mm.crt -subj "/C=US/ST=WA/L=Mill Creek/O=flak.io/CN=reg.flak.io"
openssl req -config ./openssl_mesosdns.cnf -newkey rsa:2048 -nodes -keyout domain_msd.key -x509 -days 365 -out domain_msd.crt -subj "/C=US/ST=WA/L=Mill Creek/O=flak.io/CN=reg.dcostoy.jchein.name"
