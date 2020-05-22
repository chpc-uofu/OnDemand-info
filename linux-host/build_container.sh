imgname=lmod
osname=centos7
rm -f ${osname}_${imgname}.img
# final version of container, read only (singularity shell -w will not work)
sudo /uufs/chpc.utah.edu/sys/installdir/singularity3/3.5.2/bin/singularity build ${osname}_${imgname}.sif Singularity
# sandbox image, allows container modification
#sudo /uufs/chpc.utah.edu/sys/installdir/singularity3/3.5.2/bin/singularity build -s ${osname}_${imgname} Singularity


