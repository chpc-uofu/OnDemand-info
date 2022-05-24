#!/bin/bash

# General apps
/uufs/chpc.utah.edu/sys/ondemand/chpc-apps/update.sh
cd /var/www/ood/apps/sys
mkdir org
mv bc_desktop/ org
cd /var/www/ood/apps
ln -s /uufs/chpc.utah.edu/sys/ondemand/chpc-apps/app-templates templates
cd /var/www/ood/apps/templates
source /etc/profile.d/chpc.sh
./genmodulefiles.sh

echo !!! Make sure to hand edit single version module files in /var/www/ood/apps/templates/*.txt

# Class apps
/uufs/chpc.utah.edu/sys/ondemand/chpc-class/update.sh
