#!/bin/bash

# Logo images
wget https://github.com/CHPC-UofU/OnDemand-info/blob/master/var/www/ood/public/CHPC-logo35.png /var/www/ood/public/CHPC-logo35.png
wget https://github.com/CHPC-UofU/OnDemand-info/blob/master/var/www/ood/public/CHPC-logo.png /var/www/ood/public/CHPC-logo.png
wget https://github.com/CHPC-UofU/OnDemand-info/blob/master/var/www/ood/public/chpc_logo_block.png /var/www/ood/public/chpc_logo_block.png

# Locales
mkdir -p /etc/ood/config/locales/
wget https://raw.githubusercontent.com/CHPC-UofU/OnDemand-info/master/config/locales/en.yml /etc/ood/config/locales/en.yml

# Dashboard, incl. logos, quota warnings,...
mkdir -p /etc/ood/config/apps/dashboard/initializers/
wget https://raw.githubusercontent.com/CHPC-UofU/OnDemand-info/master/config/apps/dashboard/initializers/ood.rb /etc/ood/config/apps/dashboard/initializers/ood.rb
wget https://raw.githubusercontent.com/CHPC-UofU/OnDemand-info/master/config/apps/dashboard/env /etc/ood/config/apps/dashboard/env

# Active jobs environment
mkdir -p /etc/ood/config/apps/activejobs
wget https://raw.githubusercontent.com/CHPC-UofU/OnDemand-info/master/config/apps/activejobs/env /etc/ood/config/apps/activejobs/env

# Base apps configs
mkdir -p /etc/ood/config/apps/bc_desktop/submit
wget https://raw.githubusercontent.com/CHPC-UofU/OnDemand-info/master/config/apps/bc_desktop/submit/slurm.yml.erb /etc/ood/config/apps/bc_desktop/submit/slurm.yml.erb
wget https://raw.githubusercontent.com/CHPC-UofU/OnDemand-info/master/config/apps/shell/env /etc/ood/config/apps/shell/env
wget https://raw.githubusercontent.com/CHPC-UofU/OnDemand-info/master/var/www/ood/apps/sys/shell/bin/ssh /var/www/ood/apps/sys/shell/bin/ssh

#Announcements, XdMoD
wget https://github.com/CHPC-UofU/OnDemand-info/edit/master/config/announcement.md.motd /etc/ood/config/announcement.md.motd 
wget https://raw.githubusercontent.com/CHPC-UofU/OnDemand-info/master/config/nginx_stage.yml /etc/ood/config/nginx_stage.yml

#Widgets/pinned apps
mkdir /etc/ood/config/ondemand.d/
wget https://raw.githubusercontent.com/CHPC-UofU/OnDemand-info/master/config/ondemand.d/ondemand.yml /etc/ood/config/ondemand.d/ondemand.yml

# SLURM job templates
mkdir -p /etc/ood/config/apps/myjobs
ln -s /uufs/chpc.utah.edu/sys/ondemand/chpc-myjobs-templates /etc/ood/config/apps/myjobs/templates

