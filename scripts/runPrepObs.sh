#!/bin/bash
#-----------------------------------------------------------------------------#
#           Group on Data Assimilation Development - GDAD/CPTEC/INPE          #
#-----------------------------------------------------------------------------#
#BOP
#
# !SCRIPT: JEDI IODA Buffer and PrepBuf observation data convertion to IODA-HDF5 
#
# !DESCRIPTION:
#
# !CALLING SEQUENCE:
#     
#        ./runPrepObs.sh LABELI LABELF (Optional)
#
#           o LABELI  :   Data inicial (YYYYMMDDHH), ex. 2021010100
#           o LABELF  :   Data final (YYYYMMDDHH), ex. 2021010200
#
# !REVISION HISTORY:
#
# 03 Sept 2024 - Aravequia, J. A. - Initial Version based on part 2 of JEDI Tutorial
#                                 - Converting NCEP BUFR obs into IODA-HDF5 format
# 01 Oct 2024 - Vendrasco, E. P. - Major modification on the structure of the script.
# 
# !REMARKS:
#
#EOP
#-----------------------------------------------------------------------------#
#BOC

subwrd() {
   str=$(echo "${@}" | awk '{ for (i=1; i<=NF-1; i++) printf("%s ",$i)}')
   n=$(echo "${@}" | awk '{ print $NF }')
   echo "${str}" | awk -v var=${n} '{print $var}'
}

usage() {
  sed -n '/^#BOP/,/^#EOP/{/^#BOP/d;/^#EOP/d;p}' ${BASH_SOURCE}
}

inth=6

BASEDIR=${HOMEP}/mpas_jedi_wf
RUNDIR=${BASEDIR}/obsdata
CODEDIR=${HOMEP}/Packages/sources/mpas-bundle_3.0.2
BINDIR=${BASEDIR}/bin
TABLEDIR=${BASEDIR}/tables
CRTM3DIR=${BASEDIR}/crtm3

if [ "${arg}" == '-h' -o "${arg}" == 'help' ]; then usage ; exit 0; fi

if [ ${#} -ne 1 -a ${#} -ne 2 ]; then usage ; exit; fi

labeli=$1
labelf=$1
if [ ${#} -eq 2 ]; then 
  labelf=$2
fi

ymdh=$labeli
echo $ymdh
while [ $ymdh -le $labelf ]; do

echo "Processing "$ymdh

if test ! -s ${RUNDIR}/$ymdh ; then mkdir ${RUNDIR}/$ymdh ; fi
cd ${RUNDIR}/$ymdh

ncep_ext=/p/projetos/ioper/data/external/ncep

yy=${ymdh:0:4}
mm=${ymdh:4:2}
dd=${ymdh:6:2}
hh=${ymdh:8:2}

ln -sf $ncep_ext/$yy/$mm/$dd/$hh/gdas.t${hh}z.prepbufr.nr.$yy$mm$dd prepbufr.bufr
ln -sf $ncep_ext/$yy/$mm/$dd/$hh/gdas.t${hh}z.gpsipw.tm00.bufr_d.nr.$yy$mm$dd gpsipw.bufr  

declare -a inpbuf=("1bamua" "satwnd" "gpsro" )
declare -a lnkbuf=("amsua"  "satwnd" "gnssro" )

# get length of an array
arraylength=${#inpbuf[@]}

# use for loop to read all values and indexes
for (( i=0; i<${arraylength}; i++ ));
do
  echo "index: $i, value: ${inpbuf[$i]}"
  inpname=${inpbuf[$i]}
  lnkname=${lnkbuf[$i]}
  ln -sfv $ncep_ext/$yy/$mm/$dd/$hh/gdas.t${hh}z.${inpname}.tm00.bufr_d.$yy$mm$dd ./${lnkname}.bufr
  if [ ${lnkname} != "satwnd" -a ${lnkname} != "hrs4" -a ${lnkname} != "gnssro" ]; then
   ln -sf ${CRTM3DIR}/*${lnkname}* .
  fi
  if [ ${lnkname} != "hrs4" ]; then
   ln -sf ${CRTM3DIR}/*hirs* .
  fi 
 
done

rm ./${lnkname}.bufr
ln -s ../gdas.t18z.gpsro.tm00.bufr_d.nr ./${lnkname}.bufr

echo " "

ln -fsv ${CODEDIR}/ioda/share/ioda/yaml/validation/ObsSpace.yaml .
cp -v ${TABLEDIR}/obs_errtable .

echo
time ${BINDIR}/obs2ioda-v2.x
echo

#
#  Radiances doesn´t need to convert ioda v1-to-v2
mkdir -p iodav2
mv  amsua_*obs*.h5  iodav2
mv gnssro_*obs*.h5  iodav2

cp ${BINDIR}/ioda-upgrade-v1-to-v2.x .
cp ${BINDIR}/ioda-upgrade-v2-to-v3.x .

# So, for aircraft/satwind/satwnd/sfc/sondes, we need run upgrade executable ioda-upgrade-v1-to-v2.x

./ioda-upgrade-v1-to-v2.x satwind_obs_${ymdh}.h5  iodav2/satwind_obs_${ymdh}.h5
./ioda-upgrade-v1-to-v2.x satwnd_obs_${ymdh}.h5   iodav2/satwnd_obs_${ymdh}.h5
./ioda-upgrade-v1-to-v2.x sfc_obs_${ymdh}.h5      iodav2/sfc_obs_${ymdh}.h5
./ioda-upgrade-v1-to-v2.x aircraft_obs_${ymdh}.h5 iodav2/aircraft_obs_${ymdh}.h5
./ioda-upgrade-v1-to-v2.x sondes_obs_${ymdh}.h5   iodav2/sondes_obs_${ymdh}.h5
./ioda-upgrade-v1-to-v2.x ascat_obs_${ymdh}.h5    iodav2/ascat_obs_${ymdh}.h5

#
# 2.4 Generate IODAv3
#
rm ./aircraft_obs_${ymdh}.h5 
rm ./ascat_obs_${ymdh}.h5
rm ./satwind_obs_${ymdh}.h5 
rm ./satwnd_obs_${ymdh}.h5 
rm ./sfc_obs_${ymdh}.h5 
rm ./sondes_obs_${ymdh}.h5

#Conventional
./ioda-upgrade-v2-to-v3.x iodav2/gnssro_obs_${ymdh}.h5          ./gnssro_obs_${ymdh}.h5 ObsSpace.yaml
./ioda-upgrade-v2-to-v3.x iodav2/satwnd_obs_${ymdh}.h5          ./satwnd_obs_${ymdh}.h5 ObsSpace.yaml
#Conventional - Prepbufr
./ioda-upgrade-v2-to-v3.x iodav2/satwind_obs_${ymdh}.h5         ./satwind_obs_${ymdh}.h5 ObsSpace.yaml
./ioda-upgrade-v2-to-v3.x iodav2/aircraft_obs_${ymdh}.h5        ./aircraft_obs_${ymdh}.h5 ObsSpace.yaml
./ioda-upgrade-v2-to-v3.x iodav2/sfc_obs_${ymdh}.h5             ./sfc_obs_${ymdh}.h5 ObsSpace.yaml
./ioda-upgrade-v2-to-v3.x iodav2/sondes_obs_${ymdh}.h5          ./sondes_obs_${ymdh}.h5 ObsSpace.yaml
./ioda-upgrade-v2-to-v3.x iodav2/ascat_obs_${ymdh}.h5           ./ascat_obs_${ymdh}.h5 ObsSpace.yaml
#Radiances
./ioda-upgrade-v2-to-v3.x iodav2/amsua_metop-b_obs_${ymdh}.h5   ./amsua_metop-b_obs_${ymdh}.h5 ObsSpace.yaml
./ioda-upgrade-v2-to-v3.x iodav2/amsua_metop-c_obs_${ymdh}.h5   ./amsua_metop-c_obs_${ymdh}.h5 ObsSpace.yaml

ymdh=$(date --date "${ymdh:0:8} ${ymdh:8:9}00 ${inth} hours" +%Y%m%d%H)

done

exit

#EOC
