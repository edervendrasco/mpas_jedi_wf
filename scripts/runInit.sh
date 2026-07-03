#!/bin/bash
#
#-----------------------------------------------------------------------------#
#           Group on Data Assimilation Development - GDAD/CPTEC/INPE          #
#-----------------------------------------------------------------------------#
#
#BOP
#
# !SCRIPT:  
#
# !DESCRIPTION:
#
# !CALLING SEQUENCE:
#     
#        ./runInit.sh EXP RES LABELI LABELF NHCIC FCST
#
#           o EXP     :   Nome do experimento, ex. TC
#           o RES     :   Resolucao do experimento: ex. 10242 (p/ 240km), 163842 (p/ 60km)
#           o LABELI  :   Data inicial (YYYYMMDDHH), ex. 2021010100
#           o LABELF  :   Data final (YYYYMMDDHH), ex. 2021010200
#           o NHCIC   :   Número de horas do ciclo (ex. 6 [horas])
#           o FCST    :   Tempo de previsao, em horas (ex. 24 [horas])
#
# !REVISION HISTORY:
#
# 03 Sept 2024 - Vendrasco, E. P. - Initial Version based on RMS
# 
# !REMARKS:
#
#EOP
#-----------------------------------------------------------------------------#
#BOC

function usage(){
   sed -n '/^#BOP/,/^#EOP/{/^#BOP/d;/^#EOP/d;p}' ${BASH_SOURCE}
}

if [ $# -ne 6 ]; then
   usage
   exit 1
fi

EXP=${1}
RES=${2}
LABELI=${3}
LABELF=${4}
NHCIC=${5}
FCST=${6}
pid=${7}

BASEDIR=${HOMEP}/mpas_jedi_wf
RUNDIR=${BASEDIR}/run
GFSDIR=${BASEDIR}/gfsdata
SSTDIR=${BASEDIR}/sstdata
EXEDIR=${BASEDIR}/bin
TBLDIR=${BASEDIR}/tables
GRIDIR=${BASEDIR}/grids
NMLDIR=${BASEDIR}/namelists
SCRDIR=${BASEDIR}/scripts
GEODIR=${BASEDIR}/geog

GFSRES="0p25"
LABELII=${LABELI} 

while [ ${LABELI} -le ${LABELF} ]; do

echo -e "\033[34;1m      >>>>  Data da Analise: ${LABELI}  <<<< \033[m"

EXPDIR=${RUNDIR}/${EXP}/${LABELI:0:10}

if [ -e ${EXPDIR} ]; then
  rm -rf ${EXPDIR}
fi
mkdir -p ${EXPDIR}/{runinit/logs,runda/logs,runmoc/logs,runmod/logs}

EXPDIR=${RUNDIR}/${EXP}/${LABELI:0:10}/runinit
cd ${EXPDIR}

ln -sf ${RUNDIR}/${EXP}/static/x1.${RES}.static.nc       ${EXPDIR}

gfsfile=$(date --date "${LABELI:0:8} ${LABELI:8:4} 0 hours ago" +gfs.t%Hz.pgrb2.${GFSRES}.f000.${LABELI:0:10}.grib2)
sstfile=$(date --date "${LABELI:0:8} ${LABELI:8:4} 0 hours ago" +rtgssthr_grb_0.083.grib2.${LABELI:0:8})

ln -sf ${GFSDIR}/${LABELI:0:4}/${LABELI:4:2}/${LABELI:6:2}/${LABELI:8:2}/$gfsfile ${EXPDIR}/GRIBFILE.AAA

static_interp="false"
native_gwd_static="false"
vertical_grid="true"
met_interp="true"
input_sst="false"
frac_seaice="true"

start_date=${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}_${LABELI:8:2}:00:00
start_datesst=${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}_00:00:00
stop_date=$(date --date "${LABELI:0:8} ${LABELI:8:4} ${FCST} hours" +%Y-%m-%d_%H:%M:%S)

sed -e "s,#STATIC_INTERP#,${static_interp},g; \
        s,#NATIVE_GWD_STATIC#,${native_gwd_static},g; \
        s,#VERTICAL_GRID#,${vertical_grid},g; \
        s,#MET_INTERP#,${met_interp},g; \
        s,#INPUT_SST#,${input_sst},g; \
        s,#FRAC_SEAICE#,${frac_seaice},g; \
        s,#RES#,${RES},g; \
        s,#START_DATE#,${start_date},g" \
    ${NMLDIR}/namelist.init_atmosphere_${EXP} > ${EXPDIR}/namelist.init_atmosphere

static_interp="false"
native_gwd_static="false"
vertical_grid="false"
met_interp="false"
input_sst="true"
frac_seaice="true"

sed -e "/config_init_case/s,7,8,g; \
        s,#STATIC_INTERP#,${static_interp},g; \
        s,#NATIVE_GWD_STATIC#,${native_gwd_static},g; \
        s,#VERTICAL_GRID#,${vertical_grid},g; \
        s,#MET_INTERP#,${met_interp},g; \
        s,#INPUT_SST#,${input_sst},g; \
        s,#FRAC_SEAICE#,${frac_seaice},g; \
        s,#RES#,${RES},g; \
        s,#START_DATE#,${start_date},g; \
        /start_time/{p;s/.*/    config_stop_time = '${stop_date}'/;}" \
    ${NMLDIR}/namelist.init_atmosphere_${EXP} > ${EXPDIR}/namelist.init_atmosphere_sst
        
filename_templatei="x1."${RES}".static.nc"
filename_templateo="x1."${RES}".init.nc"
filename_templates="x1."${RES}".sfc_update.nc"

sed -e "s,#filename_templatei#,${filename_templatei},g; \
        s,#filename_templateo#,${filename_templateo},g; \
        s,#filename_templates#,${filename_templates},g" \
    ${NMLDIR}/streams.init_atmosphere_${EXP} > ${EXPDIR}/streams.init_atmosphere

cp ${TBLDIR}/Vtable.GFS ${EXPDIR}/Vtable
sed -e "s,#START_DATE#,${start_date},g" \
    ${NMLDIR}/namelist.ungrib > ${EXPDIR}/namelist.wps

${EXEDIR}/unMP.exe

rm ${EXPDIR}/GRIBFILE.AAA

#ln -sf ${SSTDIR}/${LABELI:0:4}/${LABELI:4:2}/${LABELI:6:2}/00/$sstfile ${EXPDIR}/GRIBFILE.AAA
ln -si /p/projetos/ioper/data/external/ncep/2022/05/13/00/NCEP/$sstfile ${EXPDIR}/GRIBFILE.AAA

sed -e "s,#START_DATE#,${start_datesst},g; \
        /prefix/s,GFS,SST,g"               \
       ${NMLDIR}/namelist.ungrib > ${EXPDIR}/namelist.wps

${EXEDIR}/unMP.exe

if [ ${LABELI:8:2} != "00" ]; then
 mv SST:${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}_00 SST:${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}_${LABELI:8:2} 
fi 

#GAMBI#
LI=${LABELI} ; LF=$(date --date "${LABELI:0:8} ${LABELI:8:4} $FCST hours" +%Y%m%d%H)
inc=24
echo ""
while [ $LI -lt ${LF} ]; do
 SFILE=$(date --date "${LI:0:8} ${LI:8:4} $inc hours" +SST:%Y-%m-%d_%H)
 cp -v SST:${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}_${LABELI:8:2} ${SFILE}
 LI=$(date --date "${LI:0:8} ${LI:8:4} $inc hours" +%Y%m%d%H)
done
echo ""
#GAMBI#

NNODES=1
NTASKSPN=256
(( NTASKS = NTASKSPN * NNODES ))
ln -sf ${TBLDIR}/x1.${RES}.graph.info.part.${NTASKS}     ${EXPDIR}
JNAME=Init_MONAN
QUEUE=pesqmidi

cat > init.pbs <<EOF0
#!/bin/bash

#PBS -j oe
#PBS -o ${EXPDIR}/logs/log.init
#PBS -l select=${NNODES}:ncpus=${NTASKSPN}
#PBS -l place=scatter:excl 
#PBS -l walltime=00:30:00
#PBS -N ${JNAME}
#PBS -q ${QUEUE}

ulimit -s unlimited

export OMP_NUM_THREADS=1
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}

module load cray-libpals/1.6.1
module load cray-pals/1.6.1

cd ${EXPDIR}

echo  "STARTING AT \`date\` "
Start=\`date +%s.%N\`
echo \$Start >  ${EXPDIR}/logs/Timing.init

date

time mpirun -np ${NTASKS} ${EXEDIR}/mpas_init_atmosphere &> ${EXPDIR}/logs/logrun1.init
wait
cp ${EXPDIR}/namelist.init_atmosphere ${EXPDIR}/namelist.init_atmosphere_gfs 
cp ${EXPDIR}/namelist.init_atmosphere_sst ${EXPDIR}/namelist.init_atmosphere 
time mpirun -np ${NTASKS} ${EXEDIR}/mpas_init_atmosphere &> ${EXPDIR}/logs/logrun2.init
wait

End=\`date +%s.%N\`
echo  "FINISHED AT \`date\` "
echo \$End   >> ${EXPDIR}/logs/Timing.init
echo \$Start \$End | awk '{print \$2 - \$1" sec"}' >>  ${EXPDIR}/logs/Timing.init

date

if test -s log.init_atmosphere.0000.out ; then errorcode=\$(cat log.init_atmosphere.0000.out | tail -4 | head -1 | awk '{print \$4}') ; fi

echo "ERRORCODE: \$errorcode"

if [ 'x'\$errorcode == x0 ]; then
 echo "INIT Run Successfully"
 python ${SCRDIR}/change_xtime.py
 #mv x1.${RES}.init.nc x1.${RES}.sfc_update.nc streams.init_atmosphere namelist.wps namelist.init_atmosphere namelist.init_atmosphere_sst runinit
 #mv Vtable GFS:????-??-??_?? SST:????-??-??_?? runinit
 #mv log.init_atmosphere.0000.out ungrib.log logs
 #mv init.slurm scripts
 rm GRIBFILE.??? x1.${RES}.graph.info.part.${NTASKS}  x1.${RES}.static.nc
 else
 echo ">>>>> Error in Init Run <<<<<"
fi

exit 0
EOF0

chmod +x init.pbs
echo $(pwd)
if [ 'x'$pid == 'x' ]; then
	qsub ./init.pbs
 else
  qsub -W depend=afterok:${pid} ./init.pbs
fi

LABELI=$(date --date "${LABELI:0:8} ${LABELI:8:4} $NHCIC hours" +%Y%m%d%H)

done

#EOC
