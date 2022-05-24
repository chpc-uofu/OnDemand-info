#!/bin/bash

mkdir -p /var/cache/httpd/mod_auth_cas
chown apache:apache /var/cache/httpd/mod_auth_cas
chmod a+rX /var/cache/httpd/mod_auth_cas
tee -a /etc/httpd/conf.d/auth_cas.conf <<EOF
LoadModule auth_cas_module modules/mod_auth_cas.so
CASCookiePath /var/cache/httpd/mod_auth_cas/
CASCertificatePath /etc/pki/tls/certs/ca-bundle.crt
CASLoginURL https://go.utah.edu/cas/login
CASValidateURL https://go.utah.edu/cas/serviceValidate
EOF
