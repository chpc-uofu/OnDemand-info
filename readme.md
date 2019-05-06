# Notes on Open Ondemand at CHPC

## Useful links

- documentation: [https://osc.github.io/ood-documentation/master/index.html](https://osc.github.io/ood-documentation/master/index.html)
- installation [https://osc.github.io/ood-documentation/master/installation.html](https://osc.github.io/ood-documentation/master/installation.html)
- github repo: [https://github.com/OSC/Open-OnDemand](https://github.com/OSC/Open-OnDemand)

## CHPC setup

CHPC runs OOD on a VM which is mounting cluster file systems (needed to see users files, and SLURM commands). We have two VMs, one called [ondemand.chpc.utah.edu](https://ondemand.chpc.utah.edu) is a production machine which we update only occasionally, the other is a testing VM called [ondemand-test.chpc.utah.edu](https://ondemand-test.chpc.utah.edu), where we experiment. We recommend this approach to prevent prologed downtimes of the production machine - we had one of these where an auto-update broke authentication and it took us a long time to troubleshoot and fix it.

## Installation notes

Follow the [installation instructions](https://osc.github.io/ood-documentation/master/installation.html), which is quite straightforward now with the yum based packaging. The person doing the install needs at least sudo on the ondemand server, and have SSL certificates ready

### Authentication

We had LDAP before, now we have Keycloak. In general, we followed the [authentication](https://osc.github.io/ood-documentation/master/authentication.html) section of the install guide.

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

### Cluster configuration files

Follow [OOD docs](https://osc.github.io/ood-documentation/master/installation/add-cluster-config.html), we have one for each cluster, isted in [clusters.d of this repo](https://github.com/CHPC-UofU/OnDemand-info/tree/master/config/clusters.d).

### Job templates

Following the [job composer app docs](https://osc.github.io/ood-documentation/master/applications/job-composer.html#job-composer), we have created a directory with templates in my user space (```/uufs/chpc.utah.edu/common/home/u0101881/ondemand/chpc-myjobs-templates```), which is symlinked to the OODs expected:
```
$ ln -s /uufs/chpc.utah.edu/common/home/u0101881/ondemand/chpc-myjobs-templates /etc/ood/config/apps/myjobs/templates
```

Our user based templates are versioned at a [github repo](https://github.com/CHPC-UofU/chpc-myjobs-templates).

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

### OOD customization

Following OODs [customization](https://osc.github.io/ood-documentation/master/customization.html) guide, see our [config directory of this repo](https://github.com/CHPC-UofU/OnDemand-info/tree/master/config).

We also have some logos in ```/var/www/ood/public``` that get used by the webpage frontend.

#### Additional directories (scratch) in Files Explorer

To show scratches, we first need to mount them on the ondemand server, e.g.:
```
$ cat /etc/fstab
...
kpscratch.ipoib.wasatch.peaks:/scratch/kingspeak/serial /scratch/kingspeak/serial nfs timeo=16,retrans=8,tcp,nolock,atime,diratime,hard,intr,nfsvers=3 0 0

$ mkdir -p /scratch/kingspeak/serial
$ mount /scratch/kingspeak/serial

Then follow [Add Shortcuts to Files Menu](https://osc.github.io/ood-documentation/master/customization.html#add-shortcuts-to-files-menu) to create ```/etc/ood/config/apps/dashboard/initializers``` as follows:
```
OodFilesApp.candidate_favorite_paths.tap do |paths|
  paths << Pathname.new("/scratch/kingspeak/serial/#{User.new.name}")
end
```
The menu item will only show if the directory exists.

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
* add ```export XDG_RUNTIME_DIR="/tmp/${UID}"``` or ```unsetenv XDG_RUNTIME_DIR=```


### Other interactive apps

Its the best to first stage the interactive apps in users space using the [app development option](https://osc.github.io/ood-documentation/master/app-development/enabling-development-mode.html). To set that up:
```
mkdir /var/www/ood/apps/dev/u0101881
ln -s /uufs/chpc.utah.edu/common/home/u0101881/ondemand/dev gateway
```
then restart the web server via the OODs Help - Restart Web Server menu.
It is important to have the ```/var/www/ood/apps/dev/u0101881/gateway``` directory - thats what OOD looks for to show the Develop menu tab. ```u0101881``` is my user name - make sure to put yours there and also your correct home dir location.

I usually fork the OSCs interactive app templates, then clone them to ```/uufs/chpc.utah.edu/common/home/u0101881/ondemand/dev```, modify to our needs, and push back to the fork. When the app is ready to deploy, put it to ```/var/www/ood/apps/sys```. Heres a list of apps that we have:
* [Jupyter](https://github.com/CHPC-UofU/bc_osc_jupyter)
* [Matlab](https://github.com/CHPC-UofU/bc_osc_matlab)
* [ANSYS Workbench](https://github.com/CHPC-UofU/bc_osc_ansys_workbench)
* [RStudio Server](https://github.com/CHPC-UofU/bc_osc_rstudio_server)

There are a few other apps that OSC has but they either need GPUs which we dont have on our interactive test nodes (VMD, Paraview), or, are licensed with group based licenses for us (COMSOL, Abaqus). We may look in the future to restrict access to these apps to the licensed groups.

### SLURM partitions in the interactive apps

We have a number of SLURM partitions where an user can run. It can be hard to remember what partitions an user can access. We have a small piece of code that parses available user partitions and offers them as a drop-down menu. This app is at [Jupyter with dynamic partitions repo](https://github.com/CHPC-UofU/bc_jupyter_dynpart). In this repo, the ```static``` versions of the ```form.yml.erb``` and ```submit.yml.erb``` show all available cluster partitions.

