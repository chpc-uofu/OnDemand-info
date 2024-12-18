# Adding a new cluster

Quick notes for adding a new cluster to OnDemand, for Granite in the fall of 2024.

- modify script that produces `gpus.txt` to add granite

- in myallocation remove
```
    "granite": ["granite"],
```
and change
```
    "other": ["kingspeak", "notchpeak", "lonepeak", "ash", "granite"],
```

- add granite sys branch to `/etc/fstab`:
```
eth.vast.chpc.utah.edu:/sys/uufs/granite/sys /uufs/granite/sys nfs nolock,nfsvers=3,x-systemd.requires=NetworkManager-wait-online.service,x-systemd.after=network.service 0 0
mkdir -p /uufs/granite/sys
systemctl daemon-reload
mount /uufs/granite/sys
```
- add `granite.yml` from ondemand-test to `/etc/ood/config/clusters.d/`
```
scp u0101881@ondemand-test:/etc/ood/config/clusters.d/granite.yml .
```

- add granite to `/uufs/chpc.utah.edu/sys/ondemand/chpc-apps-v3.4/app-templates/clusters`
- re-make symbolic link on ondemand-test 
```
rm /var/www/ood/apps/templates/cluster.txt
ln -s /uufs/chpc.utah.edu/sys/ondemand/chpc-apps-v3.4/app-templates/clusters /var/www/ood/apps/templates/cluster.txt
```

- get `/etc/ood/config/apps/dashboard/initializers/ood.rb` from ondemand-test

- check that granite-gpu is visible and GPU types are populated (should when `/uufs/chpc.utah.edu/sys/ondemand/chpc-apps/app-templates/cluster.txt` gets granite added)

- modify `/etc/ood/config/apps/shell/env` to add:
```
OOD_SSHHOST_ALLOWLIST="grn[0][0-9][0-9].int.chpc.utah.edu:notch[0-4][0-9][0-9].ipoib.int.chpc.utah.edu:lp[0-2][0-9][0-9].lonepeak.peaks:kp[0-3][0-9][0-9].ipoib.kingspeak.peaks:ash[2-4][0-9][0-9].ipoib.ash.peaks"
```

## Change to the new account:partition:qos scheme

in `/etc/ood/config/apps/dashboard/initializers` instead of
```
       my_cmd = "/var/www/ood/apps/templates/get_alloc_all.sh"
```
do
```
       my_cmd = %q[curl "https://portal.chpc.utah.edu/monitoring/ondemand/slurm_user_params?user=`whoami`&env=chpc"]
```

in app's `submit.yml.erb`:
```
  accounting_id: "<%= custom_accpart.split(":")[0]%>"
  queue_name: "<%= custom_accpart.split(":")[1] %>"
  qos: "<%= custom_accpart.split(":")[2] %>"
```

