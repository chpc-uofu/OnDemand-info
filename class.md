# Documentation related to Open OnDemand class instance

## Class specific apps

Most class specific apps hard code the job parameters and the environment in which the interactive app runs. If the app includes the full class code, e.g. ATMOS5340, this app has environment specific for the class.

Some professors created their own app and share it with users via the shared app, e.g. BIOL3515. For that, one has to [enable app sharing](https://osc.github.io/ood-documentation/latest/app-sharing.html#peer-to-peer-executable-sharing) for the professor. 

### ChemEng custom conda environment

wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash ./Miniconda3-latest-Linux-x86_64.sh -b -p /uufs/chpc.utah.edu/common/home/u0101881/software/pkg/miniconda3-cheng -s

conda install numpy scipy pandas matplotlib
conda install jupyter jupyterlab

conda install plotly nbconvert pyyaml cython rise
conda install jupyterlab-plotly-extension plotly_express xlwings jupyter_contrib_nbextensions -c conda-forge
conda install keras

conda install plotly plotly_express jupyterlab-plotly-extension nbconvert pyyaml xlwings cython jupyter_contrib_nbextensions rise

To overcome bug in nbconvert:
chmod 755 /uufs/chpc.utah.edu/common/home/u0101881/software/pkg/miniconda3-cheng/share/jupyter/nbconvert/templates/htm

