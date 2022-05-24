#!/bin/bash

/sbin/httpd -t
RESULT=$?
if [ $RESULT == 0 ]; then
  systemctl try-restart httpd.service htcacheclean.service
  /sbin/httpd -V
else
  echo Config file syntax check failed
fi

