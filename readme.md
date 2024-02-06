Notes on Open Ondemand at CHPC
=================

Table of Contents

   * [Useful links](#useful-links)
   * [CHPC setup](#chpc-setup)
   * [Installation notes](#installation-notes)
      * [Authentication](#authentication)
         * [LDAP](#ldap)
         * [Keycloak](#keycloak)
         * [CAS](#cas)
      * [Apache configuration](#apache-configuration)
      * [Cluster configuration files](#cluster-configuration-files)
      * [Job templates](#job-templates)
      * [SLURM setup](#slurm-setup)
      * [Frisco jobs setup](#frisco-jobs-setup)
      * [OOD customization](#ood-customization)
         * [Additional directories (scratch) in Files Explorer](#additional-directories-scratch-in-files-explorer)
      * [Interactive desktop](#interactive-desktop)
      * [Other interactive apps](#other-interactive-apps)
      * [SLURM partitions in the interactive apps](#slurm-partitions-in-the-interactive-apps)
      * [SLURM accounts and partitions available to user, part 1](#slurm-accounts-and-partitions-available-to-user-part-1)
      * [SLURM accounts and partitions available to user, part 2](#slurm-accounts-and-partitions-available-to-user-part-2)
      * [Auto-filling GPU information](#auto-filling-gpu-information)
      * [Dynamic GPU filtering](#dynamic-gpu-filtering)
      * [Dynamic partition filtering](#dynamic-partition-filtering)
      * [Hiding job input fields when Frisco nodes are selected](#hiding-job-input-fields-when-frisco-nodes-are-selected)
      * [Google Analytics](#google-analytics)
      * [Google Analytics](#google-analytics)
      * [Impersonation](#impersonation)


## Useful links

- documentation: [https://osc.github.io/ood-documentation/master/index.html](https://osc.github.io/ood-documentation/master/index.html)
- installation [https://osc.github.io/ood-documentation/master/installation.html](https://osc.github.io/ood-documentation/master/installation.html)
- github repo: [https://github.com/OSC/Open-OnDemand](https://github.com/OSC/Open-OnDemand)
- recommendation for OOD deployment from OSC: [https://figshare.com/articles/Deploying_and_Managing_an_OnDemand_Instance/9170585](https://figshare.com/articles/Deploying_and_Managing_an_OnDemand_Instance/9170585)

## CHPC setup

CHPC runs OOD on a VM which is mounting cluster file systems (needed to see users files, and SLURM commands). We have two VMs, one called [ondemand.chpc.utah.edu](https://ondemand.chpc.utah.edu) is a production machine which we update only occasionally, the other is a testing VM called [ondemand-test.chpc.utah.edu](https://ondemand-test.chpc.utah.edu), where we experiment. We recommend this approach to prevent prolonged downtimes of the production machine - we had one of these where an auto-update broke authentication and it took us a long time to troubleshoot and fix it.
Also, having a dedicated short walltime/test queue or partition for prompt startup of jobs is essential to support the interactive desktop and apps, which are one of the big strengths of OOD. We did not have this at first which led to minimal use of OOD. The use picked up after we have dedicated two 64 core nodes to a partition with 8 hour walltime limit and 32 core per user CPU limit.

## Installation notes

Follow the [installation instructions](https://osc.github.io/ood-documentation/master/installation.html), which is quite straightforward now with the yum based packaging. The person doing the install needs at least sudo on the ondemand server, and have SSL certificates ready.

### Authentication

We had LDAP before, then Keycloak, and now have CAS. The CAS is much simpler to set up than Keycloak. In general, we followed the [authentication](https://osc.github.io/ood-documentation/master/authentication.html) section of the install guide.

#### LDAP
As for LDAP, following the [LDAP setup instructions](https://osc.github.io/ood-documentation/master/installation/add-ldap.html), we first made sure we can talk to LDAP, e.g., in our case:
```
$ ldapsearch -LLL -x -H ldaps://ldap.ad.utah.edu:636 -D 'cn=chpc atlassian,ou=services,ou=administration,dc=ad,dc=utah,dc=edu' -b ou=people,dc=ad,dc=utah,dc=edu -W -s sub samaccountname=u0101881 "*"
```
and then had the LDAP settings modifed for our purpose as
```
AuthLDAPURL "ldaps://ldap.ad.utah.edu:636/ou=People,dc=ad,dc=utah,dc=edu?sAMAccountName" SSL
AuthLDAPGroupAttribute cn
AuthLDAPGroupAttributeIsDN off
AuthLDAPBindDN "cn=chpc atlassian,ou=services,ou=administration,dc=ad,dc=utah,dc=edu"
AuthLDAPBindPassword ****
```

#### Keycloak

Here is what Steve did other than listed in the OOD instructions:

they omit the step of running with a
production RDMS.  So the first thing is that, even if you have NO content in the H2 database it ships with,
you have to dump a copy of that schema out and then import it into  the MySQL DB.

First get the Java MySQL connector.  Put in the right place:
```
mkdir /opt/keycloak/modules/system/layers/base/com/mysql/main
cp mysql-connector-java-8.0.15.jar /opt/keycloak/modules/system/layers/base/com/mysql/main/.
touch /opt/keycloak/modules/system/layers/base/com/mysql/main/module.xml
chown -R keycloak. /opt/keycloak/modules/system/layers/base/com/mysql
```
The documentation had a red herring,with this incorrect path:
```
/opt/keycloak/modules/system/layers/keycloak/com/mysql/main/module.xml
```

but the path that actually works is:
```
cat /opt/keycloak/modules/system/layers/base/com/mysql/main/module.xml
```
-----------------------------------------
```
<?xml version="1.0" ?>
<module xmlns="urn:jboss:module:1.5" name="com.mysql">
 <resources>
  <resource-root path="mysql-connector-java-8.0.15.jar" />
 </resources>
 <dependencies>
  <module name="javax.api"/>
  <module name="javax.transaction.api"/>
 </dependencies>
</module>
```
---------------------------------------------------

DB migration
```
 bin/standalone.sh -Dkeycloak.migration.action=export 
-Dkeycloak.migration.provider=dir -Dkeycloak.migration.dir=exported_realms
-Dkeycloak.migration.strategy=OVERWRITE_EXISTING
```
Then you have to add the MySQL connector to the config (leave the H2 connector in there too)
```
vim /opt/keycloak/standalone/configuration/standalone.xml
```

-----------------------------------------------
```
            <datasources>
                <datasource 
jndi-name="java:jboss/datasources/ExampleDS" pool-name="ExampleDS" enabled="true" use-java-context="true">
<connection-url>jdbc:h2:mem:test;DB_CLOSE_DELAY=-1;DB_CLOSE_ON_EXIT=FALSE</connection-url>
                    <driver>h2</driver>
                    <security>
                        <user-name>sa</user-name>
                        <password>sa</password>
                    </security>
                </datasource>
                <datasource 
jndi-name="java:jboss/datasources/KeycloakDS" pool-name="KeycloakDS" enabled="true" use-java-context="true">
<connection-url>jdbc:mysql://localhost:3306/keydb?useSSL=false&amp;characterEncoding=UTF-8</connection-url>
                    <driver>mysql</driver>
                    <pool>
                      <min-pool-size>5</min-pool-size>
<max-pool-size>15</max-pool-size>
                    </pool>
                    <security>
<user-name>keycloak</user-name>
<password>PasswordremovedforDocumentation</password>
                    </security>
                    <validation>
                        <valid-connection-checker 
class-name="org.jboss.jca.adapters.jdbc.extensions.mysql.MySQLValidConnectionChecker"/>
<validate-on-match>true</validate-on-match>
                        <exception-sorter 
class-name="org.jboss.jca.adapters.jdbc.extensions.mysql.MySQLExceptionSorter"/>
                    </validation>
                </datasource>
                <drivers>
                    <driver name="mysql" module="com.mysql">
<driver-class>com.mysql.cj.jdbc.Driver</driver-class>
<xa-datasource-class>com.mysql.cj.jdbc.MysqlXADataSource</xa-datasource-class>
                    </driver>
                    <driver name="h2" module="com.h2database.h2">
<xa-datasource-class>org.h2.jdbcx.JdbcDataSource</xa-datasource-class>
                    </driver>
                </drivers>
            </datasources>
```
-----------------------------
```
bin/standalone.sh -Dkeycloak.migration.action=import -Dkeycloak.migration.provider=dir
-Dkeycloak.migration.dir=exported_realms -Dkeycloak.migration.strate
gy=OVERWRITE_EXISTING
```
The documentation for adding in the MySQL jar driver was really bad, and I had to piece a working version
together from 3 or 4 examples.

Another HUGE gotcha, that stumped me for way too long is the new "tightened up" security in the java runtime
and the connector throws a hissy fit about the timezone not being specified.  To fix it just add this in your
```[mysqld]``` section of ```/etc/my.cnf```
```
default_time_zone='-07:00'
```

Keycloak config

(I presume done through the Keycloak web interface) - this is local to us so other institutions will need their own AD servers, groups, etc.
```
Edit Mode: READ_ONLY
Username LDAP Attribute: sAMAccountName
RDN LDAP Attribute: cn
UUID LDAP attribute: objectGUID
connection URL: ldaps://ldap.ad.utah.edu:636 ldaps://ring.ad.utah.edu:636
Users DN: ou=People,DC=ad,DC=utah,DC=edu
Auth type: simple
Bind DN: cn=chpc atlassian,ou=services,ou=administration,dc=ad,dc=utah,dc=edu
Bind password: notbloodylikely
Custom User LDAP Filter: (&(sAMAccountName=*)(memberOf=CN=chpc-users,OU=Groups,OU=CHPC,OU=Department
OUs,DC=ad,DC=utah,DC=edu))
Search scope: Subtree
```
Everything else default
Under user Federation > Ldap > LDAP Mappers I had to switch username to map to sAMAccountName

Note: The default Java memory on the Keycloak service is fairly low, our machine got wedged presumably because of that, so we bumped up the memory settings for Java from xms64m xm512m to xms1024m xmx2048m.

#### CAS

Campus authentication which in our case includes DUO.

First request CAS access from IAM for the new OOD server:
[https://uofu.service-now.com/it?id=uu_catalog_item&sys_id=40338e0d945991007c6da33495dbb00c](https://uofu.service-now.com/it?id=uu_catalog_item&sys_id=40338e0d945991007c6da33495dbb00c)

If upgrading from previous authentication, `/etc/httpd points` to `/opt/rh/httpd24/root/etc/httpd`. First
```
cd /etc/
rm httpd
```

```
yum -y install epel-release
```
this is likely already in place, but just be sure you have epel as thats where mod_auth_cas comes from
```
yum -y install mod_auth_cas
```
(this pulls in an unnecessary dependency of httpd, because OOD uses httpd24-httpd, just make sure httpd stays disabled)

verify httpd is disabled in systemd. 

Move away the httpd installed as the mod_auth_cas dependencyi and establish the right links to httpd24:
```
mv httpd/ httpd-old-httpd
ln -s /opt/rh/httpd24/root/etc/httpd /etc/httpd
mkdir -p /var/cache/httpd/mod_auth_cas
ln -s /var/cache/httpd/mod_auth_cas /opt/rh/httpd24/root/var/cache/httpd/mod_auth_cas
chmod a+rx /opt/rh/httpd24/root/var/cache/httpd/mod_auth_cas
ln -s /usr/lib64/httpd/modules/mod_auth_cas.so /opt/rh/httpd24/root/etc/httpd/modules/mod_auth_cas.so
```

The configuration files:
```
$ cat /opt/rh/httpd24/root/etc/httpd/conf.d/auth_cas.conf
CASCookiePath /opt/rh/httpd24/root/var/cache/httpd/mod_auth_cas/
CASLoginURL https://go.utah.edu/cas/login
CASValidateURL https://go.utah.edu/cas/serviceValidate
```
```
$ cat /etc/httpd/conf.modules.d/10-auth_cas.conf
#
# mod_auth_cas is an Apache 2.2/2.4 compliant module that supports the
# CASv1 and CASv2 protocols
#
<IfModule !ssl_module>
    LoadModule ssl_module modules/mod_ssl.so
</IfModule>

LoadModule auth_cas_module modules/mod_auth_cas.so

```
And in `/etc/ood/config/ood_portal.yml:`
```
auth:
- 'AuthType CAS'
- 'Require valid-user'
- 'CASScope /'
- 'RequestHeader unset Authorization'
```

Build and install new Apache configuration
```
sudo /opt/ood/ood-portal-generator/sbin/update_ood_portal
```

Restart Apache:
```
sudo systemctl restart httpd24-httpd
```

### Apache configuration 

The stock Apache config that comes with CentOS is relatively weak. We have learned the hard way when a class of 30 people was unable to have everyone connected at the OnDemand server at the same time.
 
We follow the [recommendations from OSC](https://discourse.osc.edu/t/ood-host-configuration-recommendations/883) on the Apache settings. These settings have made the web server more responsive and allowed to support more connections at the same time. In particular, modify file ```/opt/rh/httpd24/root/etc/httpd/conf.modules.d/00-mpm.conf```:<br>
```
#LoadModule mpm_prefork_module modules/mod_mpm_prefork.so
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

Check Apache config syntax: ```/opt/rh/httpd24/root/sbin/httpd -t```

Then restart Apache as ```systemctl try-restart httpd24-httpd.service httpd24-htcacheclean.service```.

Check that the Server MPM is event: ```/opt/rh/httpd24/root/sbin/httpd -V```

#### Web server monitoring

Monitoring the web server performance is useful to see if the web server configuration and hardware are sufficient for the needs. We installed Apache mod_status module and netdata monitoring tool following [these instructions](https://www.tecmint.com/monitor-apache-performance-using-netdata-on-centos/). Steve also added basic authentication to the netstat web server.

### Cluster configuration files

Follow [OOD docs](https://osc.github.io/ood-documentation/master/installation/add-cluster-config.html), we have one for each cluster, listed in [clusters.d of this repo](https://github.com/CHPC-UofU/OnDemand-info/tree/master/config/clusters.d).

### Job templates

Following the [job composer app docs](https://osc.github.io/ood-documentation/master/applications/job-composer.html#job-composer), we have created a directory with templates in my user space (```/uufs/chpc.utah.edu/common/home/u0101881/ondemand/chpc-myjobs-templates```), which is symlinked to the OODs expected location:
```
$ ln -s /uufs/chpc.utah.edu/common/home/u0101881/ondemand/chpc-myjobs-templates /etc/ood/config/apps/myjobs/templates
```

Our user facing templates are versioned at a [github repo](https://github.com/CHPC-UofU/chpc-myjobs-templates).

### SLURM setup

- mount sys branch for SLURM
- munge setup
```
$ sudo yum install munge-devel munge munge-libs
$ sudo rsync -av kingspeak1:/etc/munge/ /etc/munge/
$ sudo systemctl enable munge
$ sudo systemctl start munge
```

Replace kingspeak1 with your SLURM cluster name.

### Frisco jobs setup

To launch jobs on our interactive "frisco" nodes, we use the [Linux Host Adapter](https://osc.github.io/ood-documentation/release-1.7/installation/resource-manager/linuxhost.html#resource-manager-linuxhost).

We follow the install instructions, in particular create files [```/etc/ood/config/clusters.d/frisco.yml```](https://github.com/CHPC-UofU/OnDemand-info/blob/master/config/clusters.d/frisco.yml) and [```/etc/ood/config/apps/bc_desktop/frisco.yml```](https://github.com/CHPC-UofU/OnDemand-info/blob/master/config/apps/bc_desktop/frisco.yml). We create a [Singularity container](https://github.com/CHPC-UofU/OnDemand-info/tree/master/linux-host) with CentOS7 and place it in the sys branch so that the frisco hosts can read it. 

To make it work, we had to do the following changes:
- set up host based SSH authentication and open firewall on friscos to ondemand.
- modify the ```set_host``` in the ```clusters.d/frisco.yml``` so that the host is hard set to the ```chpc.utah.edu``` network route. Friscos have 3 different network interfaces and we need to make sure that OOD is consistently using the same interface for all its communication.
- currently only allow offload to frisco1, as the OOD defaults to having a round-robin hostname distribution while friscos dont round-robin.
- modify the revese proxy regex in ```/etc/ood/config/ood_portal.yml``` to include the chpc.utah.edu domain.
- modify ```/var/www/ood/apps/sys/bc_desktop/submit.yml.erb``` - we have a custom ```num_cores``` field to request certain number of cores, had to wrapping it in an if statement:
```
    <%- if num_cores != "none" -%>
    - "-n <%= num_cores %>"
    <%- end -%>
```
   while in ```/etc/ood/config/apps/bc_desktop/frisco.yml``` have ```num_cores: none```


### OOD customization

Following OODs [customization](https://osc.github.io/ood-documentation/master/customization.html) guide, see our [config directory of this repo](https://github.com/CHPC-UofU/OnDemand-info/tree/master/config).

We also have some logos in ```/var/www/ood/public``` that get used by the webpage frontend.

#### Local dashboard adjustments

in ```/etc/ood/config/locales/en.yml``` we disable the big logo and adjust file quota message:
```
en:
 dashboard:
  quota_reload_message: "Reload page to see updated quota. Quotas are updated every hour."
  welcome_html: |
```

#### Additional directories (scratch) in Files Explorer

To show scratches, we first need to mount them on the ondemand server, e.g.:
```
$ cat /etc/fstab
...
kpscratch.ipoib.wasatch.peaks:/scratch/kingspeak/serial /scratch/kingspeak/serial nfs timeo=16,retrans=8,tcp,nolock,atime,diratime,hard,intr,nfsvers=3 0 0

$ mkdir -p /scratch/kingspeak/serial
$ mount /scratch/kingspeak/serial
```
Then follow [Add Shortcuts to Files Menu](https://osc.github.io/ood-documentation/master/customization.html#add-shortcuts-to-files-menu) to create ```/etc/ood/config/apps/dashboard/initializers/ood.rb``` as follows:
```
OodFilesApp.candidate_favorite_paths.tap do |paths|
  paths << Pathname.new("/scratch/kingspeak/serial/#{User.new.name}")
end
```
The menu item will only show if the directory exists.

Similarly, for the group space directories, we can loop over all users groups and add the existing paths via:
```
  User.new.groups.each do |group|
    paths.concat Pathname.glob("/uufs/chpc.utah.edu/common/home/#{group.name}-group*")
  end
```

Lustre is a bit more messy since it requires the Lustre client and a kernel driver - though this would be the same kind of setup done on all cluster nodes, so an admin would know what to do (ours did it for us).

Heres the full [```/etc/ood/config/apps/dashboard/initializers/ood.rb```](https://github.com/CHPC-UofU/OnDemand-info/blob/master/config/apps/dashboard/initializers/ood.rb) file.

#### Disk quota warnings

Following [https://osc.github.io/ood-documentation/master/customization.html#disk-quota-warnings-on-dashboard](https://osc.github.io/ood-documentation/master/customization.html#disk-quota-warnings-on-dashboard) with some adjustments based on [https://discourse.osc.edu/t/disk-quota-warnings-page-missing-some-info/716](https://discourse.osc.edu/t/disk-quota-warnings-page-missing-some-info/716).

Each OOD machine needs to have a cron job to pull the json files from the web servers where they get generated to the OOD server. These files are located at
```
https://portal.chpc.utah.edu/monitoring/ondemand/storage_quota.json
https://www.chpc.utah.edu/apps/systems/curl_post/quota.json
```
The first file is for more recent file servers like the VAST, the latter is for legacy file servers like the group spaces.

JSON file with user storage info is produced from the quota logs run hourly, and then in ```/etc/ood/config/apps/dashboard/env```:
```
OOD_QUOTA_PATH="/etc/ood/config/apps/dashboard/quota.json:/etc/ood/config/apps/dashboard/quota_legacy.json"
OOD_QUOTA_THRESHOLD="0.90"
```

For the recent file systems json file, Paul is getting the data from the VAST and stores on the CHPC Django portal, portal.chpc.utah.edu.

For the legacy https curl to work, we had to add the OOD servers to the www.chpc.utah.edu.

To get the legacy json file, our storage admin Sam runs a script on our XFS systems hourly to produce flat files that contain the quota information and sends them to our web server, where our webadmin Chonghuan has a parser that ingests this info into a database. Chonghuan then wrote a script that queries the database and creates the json file. A doctored version of this script, which assumes that one parses the flat file themselves, is here. 

### Interactive desktop

Running a graphical desktop on an interactive node requires VNC and Websockify installed on the compute nodes, and setting up the reverse proxy. This is all described at the [Setup Interactive Apps](https://osc.github.io/ood-documentation/master/app-development/interactive/setup.html) help section. 

For us, this also required installing X and desktops on the interactives:
```
$ sudo yum install gdm
$ sudo yum groupinstall "X Window System"
$ sudo yum groupinstall "Mate Desktop"
```

then, we install the websockify and TurboVNC to our application file server as non-root (special user ```hpcapps```):
```
$ cd /uufs/chpc.utah.edu/sys/installdir
$ cd turbovnc
$ wget http://downloads.sourceforge.net/project/turbovnc/2.1/turbovnc-2.1.x86_64.rpm
$ rpm2cpio turbovnc-2.1.x86_64.rpm | cpio -idmv
mv to appropriate version location
$ cd .../websockify
$ wget wget ftp://mirror.switch.ch/pool/4/mirror/centos/7.3.1611/virt/x86_64/ovirt-4.1/python-websockify-0.8.0-1.el7.noarch.rpm
$ rpm2cpio python-websockify-0.8.0-1.el7.noarch.rpm | cpio -idmv
mv to appropriate version location
```
then the appropriate vnc sections in the cluster definition files would be as (the whole batch_connect section)
```
  batch_connect:
    basic:
      set_host: "host=$(hostname -A | awk '{print $2}')"
    vnc:
      script_wrapper: |
        export PATH="/uufs/chpc.utah.edu/sys/installdir/turbovnc/std/opt/TurboVNC/bin:$PATH"
        export WEBSOCKIFY_CMD="/uufs/chpc.utah.edu/sys/installdir/websockify/0.8.0/bin/websockify"
        %s
      set_host: "host=$(hostname -A | awk '{print $2}')"
```

In our CentOS 7 Mate dconf gives out warning that makes jobs output.log huge, to fix that:
* open ```/var/www/ood/apps/sys/bc_desktop/template/script.sh.erb```
* add ```export XDG_RUNTIME_DIR="/tmp/${UID}"``` or ```unset XDG_RUNTIME_DIR```

To automatically start XFCE terminal when the remote desktop session starts, add the following to `template/desktops/xfce.sh`:
```
# this causes Terminal to automatically start in the desktop
cp /usr/share/applications/xfce4-terminal.desktop "${AUTOSTART}"
```

To put an XFCE tiled wall paper onto the desktop, add this to `template/desktops/xfce.sh`::
```
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorVNC-0/workspace0/last-image -s /uufs/chpc.utah.edu/sys/ondemand/chpc-class/R25_neurostats/template/desktops/MainLogo_blk_fullcolor.tif
# set tiled image style
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorVNC-0/workspace0/image-style -s 2
```

### Other interactive apps

Its the best to first stage the interactive apps in users space using the [app development option](https://osc.github.io/ood-documentation/master/app-development/enabling-development-mode.html). To set that up:
```
mkdir /var/www/ood/apps/dev/u0101881
ln -s /uufs/chpc.utah.edu/common/home/u0101881/ondemand/dev gateway
```
then restart the web server via the OODs Help - Restart Web Server menu.
It is important to have the ```/var/www/ood/apps/dev/u0101881/gateway``` directory - thats what OOD looks for to show the Develop menu tab. ```u0101881``` is my user name - make sure to put yours there and also your correct home dir location.

I usually fork the OSCs interactive app templates, then clone them to ```/uufs/chpc.utah.edu/common/home/u0101881/ondemand/dev```, modify to our needs, and push back to the fork. When the app is ready to deploy, put it to ```/var/www/ood/apps/sys```. That is:
```
$ cd /uufs/chpc.utah.edu/common/home/u0101881/ondemand/dev
$ git clone https://github.com/CHPC-UofU/bc_osc_comsol.git
$ mv bc_osc_comsol comsol_app_np
$ cd comsol_app_np
```
now modify ```form.yml```, ```submit.yml.erb``` and ```template/script.sh.erb```. Then test on your OnDemand server. If all works well:
```
$ sudo cp -r /uufs/chpc.utah.edu/common/home/u0101881/ondemand/dev/comsol_app_np /var/www/ood/apps/sys
```

Heres a list of apps that we have:
* [Jupyter](https://github.com/CHPC-UofU/bc_osc_jupyter)
* [Matlab](https://github.com/CHPC-UofU/bc_osc_matlab)
* [ANSYS Workbench](https://github.com/CHPC-UofU/bc_osc_ansys_workbench)
* [RStudio Server](https://github.com/CHPC-UofU/bc_osc_rstudio_server)
* [COMSOL](https://github.com/CHPC-UofU/bc_osc_comsol)
* [Abaqus](https://github.com/CHPC-UofU/bc_osc_abaqus)
* [R Shiny](https://github.com/CHPC-UofU/bc_osc_example_shiny)

There are a few other apps that OSC has but they either need GPUs which we dont have on our interactive test nodes (VMD, Paraview), or, are licensed with group based licenses for us (COMSOL, Abaqus). We may look in the future to restrict access to these apps to the licensed groups.

### E-mail address input

To have the receive e-mail on session start check box working, we need to supply valid e-mail address. This is done in `submit.yml.erb` of each job app. There does not appear to be an option to set this globally.

One possibility is to feed in the $USER based utah.edu e-mail via SLURMs `--mail-user` argument, 
```
script:
  ...
  native:
    - "--mail-user=<%= ENV["USER"] %>@utah.edu"
```
The other is to get the user e-mail address from our database:
```
<%-
  emailcmd = '/uufs/chpc.utah.edu/sys/bin/CHPCEmailLookup.sh' + ENV["USER"]
  emailaddr = %x[ #{emailcmd}]
-%>
...
script:
  <%#  - "--mail-user=<%= emailaddr %>" %>
```

We currently use the latter approach which allows for non utah.edu e-mail addresses, but relies on up to date user information in our database.

### SLURM partitions in the interactive apps

We have a number of SLURM partitions where an user can run. It can be hard to remember what partitions an user can access. We have a small piece of code that parses available user partitions and offers them as a drop-down menu. This app is at [Jupyter with dynamic partitions repo](https://github.com/CHPC-UofU/bc_jupyter_dynpart). In this repo, the ```static``` versions of the ```form.yml.erb``` and ```submit.yml.erb``` show all available cluster partitions.

### SLURM accounts and partitions available to user, part 1

The following is a first step in the process to make available only accounts/partitions that the user has access to. There is one pull down with the `account:partition` combination, but it's provided for all clusters. Second step should make only partitions for each cluster available, this will require JavaScript `form.js`.

First, we create two arrays, listing the clusters, and accounts:partitions. This is done by modification of [`/etc/ood/config/apps/dashboard/initializers/ood.rb`](https://github.com/CHPC-UofU/OnDemand-info/blob/master/config/apps/dashboard/initializers/ood.rb) and involves:
- having a list of clusters in file `/var/www/ood/apps/templates/cluster.txt` which is read into Ruby array `CustomQueues.clusters`
- running a script, [`/var/www/ood/apps/templates/get_alloc_all.sh`](https://github.com/CHPC-UofU/OOD-apps-v3/blob/master/app-templates/get_alloc_alll.sh). that calls the `myallocations` command and parses the output of all available `account:partition` pairs for all the clusters to be put into Ruby array `CustomAccPart.accpart`.
- note that original approach to save output from the `get_alloc_all.sh` into user's directory and then reading it in `initializers/ood.rb` resulted in occasional failure, so, it is advisable to not rely on files generated to a disk for pre-filling this data.

The `CustomQueues.clusters` and `CustomAccPart.accpart` are then used in the `form.yml.erb` that defines the interactive app's submission form, as this:
```
  cluster:
    widget: select
    options:
      <%- CustomQueues.clusters.each do |g| %>
      - "<%= g %>"
      <%- end %>
    value: "notchpeak"
    cacheable: true
    help: |
      Select the cluster or Frisco node to create this session on.
  custom_accpart:
    label: "Account and partition"
    widget: select
    options:
      <%- CustomAccPart.accpart.each do |g| %>
      - "<%= g %>"
      <%- end %>
    value: "notchpeak-shared-short:notchpeak-shared-short"
    cacheable: true

```
In the `cluster` section here we omit the Frisco definitions.

In the `submit.yml.erb` we also need to parse the `custom_accpart` into the account and queue objects with those that OOD expects:
```
  accounting_id: "<%= custom_accpart.slice(0..(custom_accpart.index(':')-1)) %>"
  queue_name: "<%= custom_accpart.slice((custom_accpart.index(':')+1)..-1) %>"
```

### SLURM accounts and partitions available to user, part 2

This is a future project that should make only partitions for each cluster available, this will require JavaScript `form.js`.

First, we create two arrays, one for the clusters which we already have from step 1, and another which holds the allocation:partition information, but now separate for each cluster. This is done by modification of [`/etc/ood/config/apps/dashboard/initializers/ood.rb`](https://github.com/CHPC-UofU/OnDemand-info/blob/master/config/apps/dashboard/initializers/ood.rb) and involves:
- running an updated script, [`/var/www/ood/apps/templates/get_alloc_by_cluster.sh`](https://github.com/CHPC-UofU/OOD-apps-v3/blob/master/app-templates/get_alloc_by_cluster.sh). that calls the `myallocations` command and parses the output separately for each cluster.
- parsing this script output appropriately in the `initializers/ood.rb` to have separate `CustomAccPart` arrays for each cluster.

### Dynamic partition filtering

Available partitions are automatically filtered when submitting a job based on cluster selection. Filtering is done entirely through [`form.js`](https://github.com/CHPC-UofU/OOD-apps-v3/blob/master/app-templates/form.js), using `notchpeak`, `np`, `kingspeak`, `kp`, `lonepeak`, `lp` as identifiers. 

```
  /**
 * Filters account and partition options based on cluster selection.
 */
function filterAccountPartitionOptions() {
    // Get selected value from cluster dropdown
    const selectedCluster = document.getElementById('batch_connect_session_context_cluster').value;

    // Get account:partition select element
    const accountPartitionSelect = document.getElementById('batch_connect_session_context_custom_accpart');

    // Get all options within account:partition select
    const options = accountPartitionSelect.options;

    // Define mapping for cluster names and acronyms
    const clusterAcronyms = {
        'ash': 'ash',
        'kingspeak': 'kp',
        'lonepeak': 'lp',
        'notchpeak': 'np'
    };

    // Loop over options and hide those that do not match selected cluster
    for (let i = 0; i < options.length; i++) {
        const option = options[i];

        // Determine if the option value should be visible
        const isOptionVisible = option.value.indexOf(selectedCluster) >= 0 ||
            (clusterAcronyms[selectedCluster] && option.value.indexOf(clusterAcronyms[selectedCluster]) >= 0);

        // Set display style based on whether option should be visible
        option.style.display = isOptionVisible ? 'block' : 'none';
    }
    // Reset advanced options for cluster change
    toggleAdvancedOptions();
}
```

### Auto-filling GPU information

GPU information is auto-filled through OOD's [Dynamic Form Widgets](https://osc.github.io/ood-documentation/latest/app-development/interactive/dynamic-form-widgets.html). This requires listing of each of the GPU type and specifying in which cluster to hide that GPU, as shown in our [template](https://github.com/CHPC-UofU/OOD-apps-v3/blob/master/app-templates/job_params_v3) that gets inserted into each `form.yml.erb`. This list is rather long since it requires to manually list each GPU type and what cluster it is NOT on, e.g.:
```
  gpu_type:
    label: "GPU type"
    widget: select
    value: "none" 
    options:
      - [
           'none',
           data-hide-gpu-count: true
        ]
      - [
           'GTX 1080 Ti, SP, general, owner','1080ti',
           data-option-for-cluster-ash: false,
           data-option-for-cluster-kingspeak: false
        ]
      - [
           'GTX Titan X, SP, owner','titanx',
           data-option-for-cluster-ash: false,
           data-option-for-cluster-notchpeak: false,
           data-option-for-cluster-lonepeak: false
        ]
```

This kind of specification requires a separate input field for the GPU count called `gpu_count`.
The default GPU option is `none`, which hides the `gpu_count` field since it's not necessary.

In the `submit.yml.erb` we then tie the `gpu_type` and `gpu_count` together as:
```
    <%- if gpu_type != "none" -%>
    - "--gres=gpu:<%= gpu_type %>:<%= gpu_count %>"
    <%- end -%>
```

### Dynamic GPU filtering

GPU availability is dynamically filtered based on selected partition when submitting a job. GPU information for each partition is pulled via shell script [grabPartitionsGPUs.sh](https://github.com/CHPC-UofU/OOD-apps-v3/blob/master/app-templates/grabPartitionsGPUs.sh). A list of partitions and GPUs available to that partion are are saved in the format of:

```
  notchpeak-shared-short
  1080ti
  t4

  notchpeak-gpu
  2080ti
  3090
  a100
  p40
  v100

  ...
```

Functions CustomGPUPartitions and CustomGPUMappings was added to [`/etc/ood/config/apps/dashboard/initializers/ood.rb`](https://github.com/CHPC-UofU/OnDemand-info/blob/master/config/apps/dashboard/initializers/ood.rb) to create an array of partition:gpu pairs and identifier:gpu pairs respectively. Both of these arrays were intitialized and embedded into HTML via each app's `form.yml.erb`. Arrays were accessed via [`form.js`](https://github.com/CHPC-UofU/OOD-apps-v3/blob/master/app-templates/form.js), and form filtering logic was done directly within the JavaScript:

```
/**
 * Updates GPU options based on the selected partition.
 */
function filterGPUOptions() {
    const selectedPartition = $('#batch_connect_session_context_custom_accpart').val().split(':')[1];
    const partitionString = gpuDataHash["gpu_partitions"].find(partition => partition.startsWith(selectedPartition + ','));

    const gpuSelect = $('#batch_connect_session_context_gpu_type');
    gpuSelect.empty(); // Clear existing options

    // Always add a 'none' option
    gpuSelect.append(new Option('none', 'none'));

    if (partitionString) {
        const availableGPUs = partitionString.split(',').slice(1).map(gpu => gpu.trim());

        if (availableGPUs.length > 0) {
            // Add 'any' option if GPUs are available
            gpuSelect.append(new Option('any', 'any'));

            // Add available GPUs as options
            availableGPUs.forEach(gpu => {
                if (gpuMapping[gpu]) // Check for mapping
                    gpuSelect.append(new Option(gpuMapping[gpu], gpu));
            });
            gpuSelect.parent().show(); // Show GPU selection field
        } else {
            gpuSelect.parent().show(); // Still show field with 'none' option
        }
    } else {
        gpuSelect.parent().show(); // Show field with only 'none' option if partition not found
    }
}
```


### Hiding job input fields when Frisco nodes are selected

The [Dynamic Form Widgets](https://osc.github.io/ood-documentation/latest/app-development/interactive/dynamic-form-widgets.html) also allow to hide fields, like account, walltime, etc, that are not needed for the Frisco jobs. Because the list of fields to hide is long and has to be done for each `frisco`, it's in a separate include file in the templates directory, [friscos_v2](https://github.com/CHPC-UofU/OOD-apps-v3/blob/master/app-templates/friscos_v2). For each Frisco, the entry is:
```
      - [
          'frisco1',
          data-hide-gpu-type: true,
          data-hide-memtask: true,
          data-hide-bc-vnc-resolution: true,
          data-hide-num-cores: true,
          data-hide-bc-num-hours: true,
          data-hide-custom-accpart: true,
          data-hide-bc-email-on-started: true,
        ]
```

And it is included in the `form.yml.erb` in the `cluster` section as:
```
  cluster:
    widget: select
    options:
      <%- CustomQueues.clusters.each do |g| %>
      - "<%= g %>"
      <%- end %>
<% IO.foreach(template_root+"friscos_v2") do |line| %>
<%= line %>
<% end %>
    value: "notchpeak"
    cacheable: true
```
### Google Analytics

It is useful to set up Google Analytics to gather usage data, rather than parsing through the Apache logs. This is somewhat hiddenly explained [here](https://osc.github.io/ood-documentation/master/infrastructure/ood-portal-generator/examples/add-google-analytics.html).

In our case, it involved:
* signing up for an account at analytics.google.com, and noting the account name
* putting this account name to /etc/ood/config/ood_portal.yml, as described in the document above. Our piece is:
```
analytics:
  url: 'http://www.google-analytics.com/collect'
  id: 'UA-xxxxxxxxx-x'
```
* rebuild and reinstall Apache configuration file by running ```sudo /opt/ood/ood-portal-generator/sbin/update_ood_portal```.
* restart Apache, on CentOS 7: ```sudo systemctl try-restart httpd24-httpd.service httpd24-htcacheclean.service```.

#### Change to Google Analytics 4

Discussed at [this](https://discourse.openondemand.org/t/google-analytics-4-support/2464) thread. In particular:
```
mkdir -p /etc/ood/config/apps/dashboard/views/layouts
cp /var/www/ood/apps/sys/dashboard/app/views/layouts/application.html.erb /etc/ood/config/apps/dashboard/views/layouts
```

Edit `/etc/ood/config/apps/dashboard/views/layouts/application.html.erb` and near the top put:
```
<%- tag_id = 'abc123' -%>

<%- unless tag_id.nil? -%>
<!-- Google tag (gtag.js) -->
<script async src="https://www.googletagmanager.com/gtag/js?id=<%= tag_id %>"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());

  gtag('config', '<%= tag_id %>');
</script>
<%- end -%>
```

The “Measurement ID” on GA4 is the “tag_id”.

### Impersonation

Impersonation allows one to log in as yourself but in the OOD portal be another user. This could be useful in troubleshooting OOD problems.

At present we have this functional only on `ondemand-test.chpc.utah.edu`, but, if we do not notice any issues it will be put on the production servers.

We follow instructions from [Yale](https://github.com/ycrc/ood-user-mapping).

In particular, first clone their repository:
```
cd /uufs/chpc.utah.edu/common/home/u0101881/ondemand/repos/
git clone https://github.com/ycrc/ood-user-mapping
```

Then on the OOD server:
```
cd /opt/ood
cp -r /uufs/chpc.utah.edu/common/home/u0101881/ondemand/repos/ood-user-mapping/ycrc_auth_map customized_auth_map
patch -u /opt/ood/ood-portal-generator/templates/ood-portal.conf.erb -i /uufs/chpc.utah.edu/common/home/u0101881/ondemand/repos/ood-user-mapping/ood-portal.conf.erb.patch 
```

Add the following line to ```/etc/ood/config/ood-portal.yml```:
```
user_map_cmd: '/opt/ood/customized_auth_map/bin/ood_auth_map.regex'
```

Regenerate Apache config and restart it:
```
/opt/ood/ood-portal-generator/sbin/update_ood_portal
systemctl try-restart httpd24-httpd.service httpd24-htcacheclean.service
```

Then, to impersonate an user, map the users ID to your ID, in `/etc/ood/config/map_file` that is editable only by root = contact Martin or Steve to do it. The format of the file is:
```
"your_unid" user_unid
```
e.g.
```
"u0012345" u0123456
```

## Update notes

### Update to OOD 3.0

- set maintenance mode:
```
touch /etc/ood/maintenance.enable
```

- Stop PUNs
```
/opt/ood/nginx_stage/sbin/nginx_stage nginx_clean -f
```

- do the update
https://osc.github.io/ood-documentation/latest/release-notes/v3.0-release-notes.html#upgrade-directions

- restart Apache
```
systemctl try-restart httpd
```

- change  `/etc/ood/config/apps/dashboard/initializers/ood.rb` to new syntax
https://osc.github.io/ood-documentation/latest/release-notes/v3.0-release-notes.html#deprecations

- update `/etc/ood/config/apps/dashboard/views/layouts/application.html.erb` for Google Analytics
```
cd /etc/ood/config/apps/dashboard/views/layouts/
cp application.html.erb application.html.erb.2.0
cp /var/www/ood/apps/sys/dashboard/app/views/layouts/application.html.erb .
vi application.html.erb.2.0
```
copy Google Analytics tag
```
vi application.html.erb
```
paste Google Analytics tag

- remove bc_desktop
```
cd /var/www/ood/apps/sys
mv bc_desktop ../sys-2022-05-24/
```

- change websockify version in `/etc/ood/config/clusters.d/*.yml` to 0.10.0

- fix the clusters app
add rexml to dependencies - modify app files as in https://github.com/OSC/osc-systemstatus/commit/203d42a426d67323ef9d7c7d95fadd64b007b4d5
```
scl enable ondemand -- bin/bundle install --path vendor/bundle
scl enable ondemand -- bin/setup
touch tmp/restart.txt
```

Config changes - `/etc/ood/config/ondemand.d/ondemand.yml.erb`

- clean old apps dirs after 30 days:
https://osc.github.io/ood-documentation/latest/reference/files/ondemand-d-ymls.html#bc-clean-old-dirs
```
# clean old interactive app dirs
bc_clean_old_dirs: true
```
- support ticket, https://osc.github.io/ood-documentation/latest/customizations.html#support-ticket-guide
  - auto-filling the e-mail address, but Service Now team will create a completely separate page for ticket submission.
```
support_ticket:
  email:
    from: <%= Etc.getlogin %>@utah.edu
    to: "helpdesk@chpc.utah.edu"
    delivery_method: "smtp"
    delivery_settings:
      address: 'mail.chpc.utah.edu'
      port: 25
      authentication: 'none'
  form:
    - subject
    - session_id
    - session_description
    - attachments
    - description
```

- quick launch apps, https://osc.github.io/ood-documentation/latest/how-tos/app-development/interactive/sub-apps.html#
  - no - would have to include all the form.yml.erb fields that are used in submit.yml.erb and show them on the page.

