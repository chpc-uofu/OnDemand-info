#!/bin/bash

yum install libcurl-devel pcre-devel
cd /usr/local/src
wget https://github.com/apereo/mod_auth_cas/archive/v1.2.tar.gz
tar xvzf v1.2.tar.gz
cd mod_auth_cas-1.2
autoreconf -iv
./configure --with-apxs=/usr/bin/apxs
make
make check
make install
