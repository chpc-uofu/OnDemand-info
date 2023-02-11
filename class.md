# Documentation related to Open OnDemand class instance

[ondemand-class.chpc.utah.edu](https://ondemand-class.chpc.utah.edu)

## Class specific apps

Most class specific apps hard code the job parameters and the environment in which the interactive app runs. If the app includes the full class code, e.g. ATMOS5340, this app has environment specific for the class.

Some professors created their own app and share it with users via the shared app, e.g. BIOL3515. For that, one has to [enable app sharing](https://osc.github.io/ood-documentation/latest/app-sharing.html#peer-to-peer-executable-sharing) for the professor. 

All class apps are in `/uufs/chpc.utah.edu/sys/ondemand/chpc-class`. This directory is owned by Martin, in order to allow him to push/pull them to the GitHub and GitLab remote repositories. If others create the app here, we will have to figure out permissions for this directory to allow them to write and push/pull as well.

### Creating a class specific OOD app

1. Decide if to use a Remote Desktop, Jupyter, RStudio Server, or a remote desktop based application (Matlab, Ansys, etc). These are the four basic classes of the apps.

2. If Remote Desktop, Jupyter, or RStudio, pick one of the existing class apps, and copy it to a new directory. For the VNC based apps, one would have to create a new class app from the actual app, since we haven't done that yet. For Remote Desktop based app, use e.g. [ASTR5560](https://github.com/CHPC-UofU/OOD-class-apps/tree/master/ASTR5560), for Jupyter use [CHEN_Jupyter](https://github.com/CHPC-UofU/OOD-class-apps/tree/master/CHEN_Jupyter), for RStudio Server use [MIB2020](https://github.com/CHPC-UofU/OOD-class-apps/tree/master/MIB2020).

3. Copy this directory to a new directory with the class name, e.g. for a desktop app,
```
cp -r ASTR5560 ATMOS5120
```

4. Edit the `manifest.yml` to change the class name and department.

5. Edit the `form.yml` to change the `title` to the class name, and adjust the resources that may need adjustment, e.g. `cluster`, `bc_num_hours` = walltime, `my_account` = account and `my_queue` = partition.

6. Additional job parameters can be changed in the `submit.yml.erb`. These correspond to the SLURM job parameters. E.g. to set number of tasks (CPU cores) for the job, in the `script - native` section:
```
    - "-n"
    - 4
```

7. To modify the environment modules or variables, that may be needed for the class, edit `template/script.sh.erb` in the section that has existing modules.

### ChemEng custom conda environment

The following lists the commands needed to install Miniconda for Chemical Engineering classes

```
wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash ./Miniconda3-latest-Linux-x86_64.sh -b -p /uufs/chpc.utah.edu/common/home/u0101881/software/pkg/miniconda3-cheng -s
```
Set up Lmod module as usual and load it. Then install the needed Python modules.
```
conda install numpy scipy pandas matplotlib
conda install jupyter jupyterlab

conda install plotly nbconvert pyyaml cython rise
conda install jupyterlab-plotly-extension plotly_express xlwings jupyter_contrib_nbextensions -c conda-forge
conda install keras

conda install plotly plotly_express jupyterlab-plotly-extension nbconvert pyyaml xlwings cython jupyter_contrib_nbextensions rise
```

To overcome bug in nbconvert:
```
chmod 755 /uufs/chpc.utah.edu/common/home/u0101881/software/pkg/miniconda3-cheng/share/jupyter/nbconvert/templates/htm
```
