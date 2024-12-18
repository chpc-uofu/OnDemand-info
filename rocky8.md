# Rocky 8 installation notes

## Initial VM setup

VM was set up by sysadmin (David R) following
[https://osc.github.io/ood-documentation/latest/installation/install-software.html](https://osc.github.io/ood-documentation/latest/installation/install-software.html)
up to and including
[setting up SSL](https://osc.github.io/ood-documentation/latest/installation/add-ssl.html)

Sysadmin additions to that on the top of this:
- copy SSH host keys in /etc/ssh from old servers before they are re-built
- in /etc/ssh/ssh_config.d/00-chpc-config on OOD servers enable host based authentication
- add all cluster file systems mounts
- install maria-db-server to allow resolveip - used to find compute node hostname by OOD (hostfromroute.sh)
- add all HPC scratch mounts
- passwordless ssh to all interactive nodes
- Modify `/etc/security/access.conf` to add: ```+:ALL:LOCAL```

## Further installation

### CAS authentication

Some info on other sites implementation at (https://discourse.openondemand.org/t/implementing-authentication-via-cas/34/9).

Build mod_auth_cas from source, based on [https://linuxtut.com/en/69296a1f9b6bf93f076f/](https://linuxtut.com/en/69296a1f9b6bf93f076f/)
```
$ yum install libcurl-devel pcre-devel
$ cd /usr/local/src
$ wget https://github.com/apereo/mod_auth_cas/archive/v1.2.tar.gz
$ tar xvzf v1.2.tar.gz
$ cd mod_auth_cas-1.2
$ autoreconf -iv
$ ./configure --with-apxs=/usr/bin/apxs
$ make
$ make check
$ make install
```

or `install_scripts/build_cas.sh`

Further setup of CAS
```
$ mkdir -p /var/cache/httpd/mod_auth_cas
$ chown apache:apache /var/cache/httpd/mod_auth_cas
# chmod a+rX /var/cache/httpd/mod_auth_cas
$ vi /etc/httpd/conf.d/auth_cas.conf
LoadModule auth_cas_module modules/mod_auth_cas.so
CASCookiePath /var/cache/httpd/mod_auth_cas/
CASCertificatePath /etc/pki/tls/certs/ca-bundle.crt
CASLoginURL https://go.utah.edu/cas/login
CASValidateURL https://go.utah.edu/cas/serviceValidate
```

or `install_scripts/setup_cas.sh`

### Base OOD config and start Apache

OOD base config files:
```
# cd /etc/ood/config
# cp ood_portal.yml  ood_portal.yml.org
# scp u0101881@ondemand.chpc.utah.edu:/etc/ood/config/ood_portal.yml .
OR # wget https://raw.githubusercontent.com/CHPC-UofU/OnDemand-info/master/config/ood_portal.yml
# vi ood_portal.yml
```
- search for "ondemand.chpc.utah.edu", replace with "ondemand-test.chpc.utah.edu"
- (for ondemand-test - set Google Analytics "    id: 'UA-122259839-4'" 
- copy the `SSLCertificate` part from `ood_portal.yml.org`
- (comment out line `"  - 'Include "/root/ssl/ssl-standard.conf"'"`

Update Apache and start it
```
# /opt/ood/ood-portal-generator/sbin/update_ood_portal
# systemctl try-restart httpd.service htcacheclean.service
```
Once this is done one should be able to log into https://ondemand-test.chpc.utah.edu and see the vanilla OOD interface.

### Improve Apache configuration

Mainly for performance reasons if > 10s simultaneous users.

```
# vi /etc/httpd/conf.modules.d/00-mpm.conf
LoadModule mpm_event_module modules/mod_mpm_event.so

<IfModule mpm_event_module>
  ServerLimit 32
  StartServers 2
  MaxRequestWorkers 512
  MinSpareThreads 25
  MaxSpareThreads 75
  ThreadsPerChild 32
  MaxRequestsPerChild 0
  ThreadLimit 512
  ListenBacklog 511
</IfModule>
```

Check Apache config syntax: 
```https://github.com/chpc-uofu/OnDemand-info/blob/master/readme.md#slurm-accounts-and-partitions-available-to-user-part-1
# /sbin/httpd -t
```

Then restart Apache:
```
# systemctl try-restart httpd.service htcacheclean.service
```

Check that the Server MPM is event: 
```
# /sbin/httpd -V
```

or `install_scripts/check_apache_config.sh`

### SLURM setup

```
$ sudo dnf install munge-devel munge munge-libs
$ sudo rsync -av kingspeak1:/etc/munge/ /etc/munge/
$ sudo systemctl enable munge
$ sudo systemctl start munge
```

### Clusters setup
https://github.com/chpc-uofu/OnDemand-info/blob/master/readme.md#slurm-accounts-and-partitions-available-to-user-part-1
```
scp -r u0101881@ondemand.chpc.utah.edu:/etc/ood/config/clusters.d /etc/ood/config
```
- !!!! in all /etc/ood/config/clusters.d/*.yml replace ondemand.chpc.utah.edu with ondemand-test.chpc.utah.edu
- !!!! may replace websockify/0.8.0 with websockify/0.8.0.r8

### Other customizations

Logo images
```
# scp -r u0101881@ondemand.chpc.utah.edu:/var/www/ood/public/CHPC-logo35.png /var/www/ood/public
# scp -r u0101881@ondemand.chpc.utah.edu:/var/www/ood/public/chpc_logo_block.png /var/www/ood/public
# scp -r u0101881@ondemand.chpc.utah.edu:/var/www/ood/public/CHPC-logo.png /var/www/ood/public
```

Locales
```
# mkdir -p /etc/ood/config/locales/
# scp -r u0101881@ondemand.chpc.utah.edu:/etc/ood/config/locales/en.yml /etc/ood/config/locales/
```

Dashboard, incl. logos, quota warnings,...
```
# mkdir -p /etc/ood/config/apps/dashboard/initializers/
# scp -r u0101881@ondemand.chpc.utah.edu:/etc/ood/config/apps/dashboard/initializers/ood.rb /etc/ood/config/apps/dashboard/initializers/
# scp -r u0101881@ondemand.chpc.utah.edu:/etc/ood/config/apps/dashboard/env /etc/ood/config/apps/dashboard
```

Test disk quota
```
vi /etc/ood/config/apps/dashboard/env
```
temporarily modify `OOD_QUOTA_THRESHOLD="0.10"`, in OOD web interface Restart Web Server to verify that the quota warnings appear.

Active jobs environment
```
# mkdir -p /etc/ood/config/apps/activejobs
# scp -r u0101881@ondemand.chpc.utah.edu:/etc/ood/config/apps/activejobs/env /etc/ood/config/apps/activejobs
```

Base apps configs
```
# scp -r u0101881@ondemand.chpc.utah.edu:/etc/ood/config/apps/bc_desktop /etc/ood/config/apps/
# scp -r u0101881@ondemand.chpc.utah.edu:/etc/ood/config/apps/shell /etc/ood/config/apps/
# scp u0101881@ondemand.chpc.utah.edu:/var/www/ood/apps/sys/shell/bin/ssh /var/www/ood/apps/sys/shell/bin/
```

Announcements, XdMoD
```
# scp -r u0101881@ondemand.chpc.utah.edu:/etc/ood/config/announcement.md.motd /etc/ood/config/
# scp -r u0101881@ondemand.chpc.utah.edu:/etc/ood/config/nginx_stage.yml /etc/ood/config/
```

Widgets/pinned apps
```
# mkdir /etc/ood/config/ondemand.d/
# scp -r u0101881@ondemand.chpc.utah.edu:/etc/ood/config/ondemand.d/ondemand.yml /etc/ood/config/ondemand.d/
```

SLURM job templates
```
# mkdir -p /etc/ood/config/apps/myjobs
# ln -s /uufs/chpc.utah.edu/sys/ondemand/chpc-myjobs-templates /etc/ood/config/apps/myjobs/templates
```

OR `install_scripts/get_customizations.sh`

### Apps setup
```
# /uufs/chpc.utah.edu/sys/ondemand/chpc-apps/update.sh
# cd /var/www/ood/apps/sys
# mkdir org
# mv bc_desktop/ org
# cd /var/www/ood/apps
# ln -s /uufs/chpc.utah.edu/sys/ondemand/chpc-apps/app-templates templates
# cd /var/www/ood/apps/templates
# source /etc/profile.d/chpc.sh
# ./genmodulefiles.sh
```

OR `install_scripts/get_apps.sh` (NB - modules are set up differently, don't run ./genmodulefiles.sh

Restart web server in the client to see all the Interactive Apps. If seen proceed to testing the apps.
Including check cluster status app.


## Changes after initial R8 installation

### Auto-initialization of accounts, partitions, GPUs in partition

Described in [CHPC OOD's readme](https://github.com/chpc-uofu/OnDemand-info/blob/master/readme.md#slurm-accounts-and-partitions-available-to-user-part-1) and below, it involves modification of `/etc/ood/config/apps/dashboard/initializers/ood.rb` to read in the information, which is then used/parsed in the interactive apps (mainly `form.yml.erb` and `form.js`).

Supporting infrastructure includes running [script](https://github.com/chpc-uofu/OOD-apps-v3/blob/master/app-templates/grabPartitionsGPUs.sh) that produces a text file which lists the GPUs and partitions. The user accounts/partitions list is curled from portal.

### Change in file systems quota

Curled from portal via a cron job that runs on the ondemand server.

### Cluster status apps

Display node status for each node, e.g. for [notchpeak](https://github.com/chpc-uofu/OOD-apps-v3/tree/master/chpc-notchpeak-status). See this URL for description of what cron jobs are run and what and where they produce. Cron job on notchrm runs [getmodules.sh](https://github.com/chpc-uofu/OOD-apps-v3/blob/master/app-templates/getmodules.sh) once a day to generate file `/uufs/chpc.utah.edu/sys/ondemand/chpc-apps/app-templates/modules/notchpeak.json` which is then symlinked to `/var/www/ood/apps/templates/modules/notchpeak.json`. As each cluster requires its own `json` file, other clusters files are symlinks to `notchpeak.json` (incl. `redwood.json` as PE uses a copy of the sys branch from the GE).

### Dynamic modules

Using [OOD's built in way](https://osc.github.io/ood-documentation/latest/reference/files/ondemand-d-ymls.html?highlight=module) to auto-set available module versions for interactive apps. 

### Outstanding things

!!!! Netdata

### After full R8 update

- delete CentOS 7 modules in Jupyter, RStudio Server

### Things to look at in the future

- Dashboard allocation balance warnings: https://osc.github.io/ood-documentation/latest/customization.html#balance-warnings-on-dashboard
