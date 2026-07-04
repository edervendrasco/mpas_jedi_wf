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
#        ./runDA.sh EXP RES LABELI NHCIC FCST FROMCIC WINDOW 
#
#           o EXP     :   Nome do experimento, ex. TC
#           o RES     :   Resolucao do experimento: ex. 10242 (p/ 240km), 163842 (p/ 60km)
#           o LABELI  :   Data inicial (YYYYMMDDHH), ex. 2021010100
#           o NHCIC   :   Número de horas do ciclo (ex. 6 [horas])
#           o FCST    :   Tempo de previsao, em horas (ex. 24 [horas])
#           o FROMCIC :   O Background vem do ciclo: sim: 1; não: 0
#           o WINDOW  :   Janela de assimilação (ex. 180 [minutos])
#
# !REVISION HISTORY:
#
# 05 Sept 2024 - Vendrasco, E. P. - Initial Version based on RMS
# 
# !REMARKS:
#
#EOP
#-----------------------------------------------------------------------------#
#BOC

function usage(){
  sed -n '/^#BOP/,/^#EOP/{/^#BOP/d;/^#EOP/d;p}' ${BASH_SOURCE}
}

function diffdate(){

 di=${1}
 df=${2}

 si=$(date --date "${di:0:8} ${di:8:2}:${di:10:2}:${di:12:2}" +%s)
 sf=$(date --date "${df:0:8} ${df:8:2}:${df:10:2}:${df:12:2}" +%s)

 (( dddias =     (  sf - si )/86400 ))
 (( ddhoras =    ( (sf - si ) - dddias*86400 )/3600))
 (( ddminutos =  ( (sf - si ) - dddias*86400 - ddhoras*3600 )/60 ))
 (( ddsegundos = (  sf - si ) - dddias*86400 - ddhoras*3600 - ddminutos*60 ))

 dddias=$(printf "%0*d" 2 $dddias)
 ddhoras=$(printf "%0*d" 2 $ddhoras)
 ddminutos=$(printf "%0*d" 2 $ddminutos)
 ddsegundos=$(printf "%0*d" 2 $ddsegundos)
 
}

if [ $# -ne 7 ] && [ $# -ne 8 ]; then
   usage
   exit 1
fi

EXP=${1}
RES=${2}
LABELI=${3}
NHCIC=${4}
FCST=${5}
FROMCIC=${6}
WINDOW=${7}
pid=${8}

if [ ${FROMCIC} -eq 1 ]; then FROMCICL="true" ; else FROMCICL="false" ; fi

radaronly="F"

LABELIprev=`date -d "${LABELI:0:8} ${LABELI:8:2} ${NHCIC} hours ago" '+%Y%m%d%H'`

BASEDIR=${HOMEP}/mpas_jedi_wf
RUNDIR=${BASEDIR}/run
EXEDIR=${BASEDIR}/bin
TBLDIR=${BASEDIR}/tables
GRIDIR=${BASEDIR}/grids
NMLDIR=${BASEDIR}/namelists
SCRDIR=${BASEDIR}/scripts
OBSDIR=${BASEDIR}/obsdata
BEMDIR=${BASEDIR}/bedata

EXPDIR=${RUNDIR}/${EXP}/${LABELI:0:10}/runda

if [ ! -e ${RUNDIR}/${EXP}/${LABELI:0:10} ]; then
 mkdir -p ${RUNDIR}/${EXP}/${LABELI:0:10}/{runinit/logs,runmoc/logs,runmod/logs}
fi

if [ -e ${EXPDIR} ]; then
  rm -rf ${EXPDIR}
  mkdir -p ${EXPDIR}/logs
 else
  mkdir -p ${EXPDIR}/logs
fi

cd ${EXPDIR}

start_date=${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}_${LABELI:8:2}:00:00
LABELF=$(date --date "${LABELI:0:8} ${LABELI:8:4} ${FCST} hours" +%Y%m%d%H%M%S)
diffdate $LABELI'0000' $LABELF 
run_duration=${dddias}_${ddhoras}:${ddminutos}:${ddsegundos}

ANADATE=$(date    --date "${LABELI:0:8} ${LABELI:8:4}         0 minutes     " +%Y-%m-%dT%H:%M:00)
ANADATEp=$(date    --date "${LABELI:0:8} ${LABELI:8:4}        0 minutes     " +%Y-%m-%dT%H.%M.00)
WINDATE=$(date --date "${LABELI:0:8} ${LABELI:8:4} $WINDOW   minutes ago    " +%Y-%m-%dT%H:%M:00)

ln -fs ${TBLDIR}/physFiles/*                       ${EXPDIR}
ln -fs ${NMLDIR}/stream_list.atmosphere.analysis   ${EXPDIR}
ln -fs ${NMLDIR}/stream_list.atmosphere.background ${EXPDIR}
ln -fs ${NMLDIR}/stream_list.atmosphere.control    ${EXPDIR}
ln -fs ${NMLDIR}/stream_list.atmosphere.ensemble   ${EXPDIR}
ln -fs ${BEMDIR}/B_Matrix_${EXP}                   ${EXPDIR}/B_Matrix

sed -e "s,#RUN_DURATION#,${run_duration},g; \
        s,#RES#,${RES},g; \
        s,#START_DATE#,${start_date},g; \
        s,#FROMCICL#,${FROMCICL},g" \
    ${NMLDIR}/namelist.atmosphere_${EXP} > ${EXPDIR}/namelist.atmosphere

inputfile=mpasin.${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}T${LABELI:8:2}.00.00.nc   

sed -e "s,#RES#,${RES},g; \
        s,#INPUTFILE#,${inputfile},g; \
        /stream_list.atmosphere.output/d; \
        /stream_list.atmosphere.diagnostics/d; \
        /stream_list.atmosphere.surface/d" \
    ${NMLDIR}/streams.atmosphere_${EXP} > ${EXPDIR}/streams.atmosphere
 
if [ $radaronly == "T" ]; then
  ln -fs ${OBSDIR}/${LABELI}/obs_radar_mrms_${LABELI}00.h5  ${EXPDIR}/obs_radar_mrms_${ANADATE}00.h5
 else
  ln -fs ${OBSDIR}/${LABELI}/aircraft_obs_${LABELI}.h5         ${EXPDIR}/aircraft_obs_${ANADATE}.h5
  ln -fs ${OBSDIR}/${LABELI}/gnssro_obs_${LABELI}.h5           ${EXPDIR}/gnssro_obs_${ANADATE}.h5 
  ln -fs ${OBSDIR}/${LABELI}/satwind_obs_${LABELI}.h5          ${EXPDIR}/satwind_obs_${ANADATE}.h5
  ln -fs ${OBSDIR}/${LABELI}/satwnd_obs_${LABELI}.h5           ${EXPDIR}/satwnd_obs_${ANADATE}.h5
  ln -fs ${OBSDIR}/${LABELI}/sfc_obs_${LABELI}.h5              ${EXPDIR}/sfc_obs_${ANADATE}.h5
  ln -fs ${OBSDIR}/${LABELI}/sondes_obs_${LABELI}.h5           ${EXPDIR}/sondes_obs_${ANADATE}.h5 
  ln -fs ${OBSDIR}/${LABELI}/amsua_metop-c_obs_${LABELI}.h5    ${EXPDIR}/amsua_metop-c_obs_${ANADATE}.h5
  ln -fs ${OBSDIR}/${LABELI}/amsua_metop-b_obs_${LABELI}.h5    ${EXPDIR}/amsua_metop-b_obs_${ANADATE}.h5
  ln -fs ${OBSDIR}/${LABELI}/ascat_obs_${LABELI}.h5            ${EXPDIR}/ascat_obs_${ANADATE}.h5
  if test -s  ${OBSDIR}/${LABELI}/obs_radar_cptec_${LABELI}00.h5; then 
  ln -fs ${OBSDIR}/${LABELI}/obs_radar_cptec_${LABELI}00.h5    ${EXPDIR}/obs_radar_cptec_${ANADATE}00.h5
  fi
fi

cp ${NMLDIR}/obsop_name_map.yaml        ${EXPDIR}

ln -fs ${TBLDIR}/x1.${RES}.invariant.nc ${EXPDIR}

ln -fs ${NMLDIR}/geovars.yaml           ${EXPDIR}
ln -fs ${NMLDIR}/keptvars.yaml          ${EXPDIR}
ln -fs ${NMLDIR}/obsop_name_map.yaml    ${EXPDIR}
ln -fs ${BASEDIR}/crtm3                 ${EXPDIR}

if [ $radaronly == "T" ]; then
  sed -e "s,#WINDATE#,${WINDATE},g; \
          s,#ANADATE#,${ANADATE},g; \
          s,#ANADATEp#,${ANADATEp},g" \
        ${NMLDIR}/3dvar_radar.yaml > ${EXPDIR}/3dvar.yaml
else
  sed -e "s,#WINDATE#,${WINDATE},g; \
          s,#ANADATE#,${ANADATE},g; \
          s,#ANADATEp#,${ANADATEp},g" \
        ${NMLDIR}/3dvar.yaml > ${EXPDIR}/3dvar.yaml
fi

NNODES=1
NTASKSPN=256
(( NTASKS = NTASKSPN * NNODES ))
ln -sf ${TBLDIR}/x1.${RES}.graph.info.part.${NTASKS}     ${EXPDIR}
JNAME=model_JEDI
QUEUE=pesqmidi
debug=0

cat > jedi.pbs <<EOF0
#!/bin/bash

#PBS -j oe
#PBS -o ${EXPDIR}/logs/log.jedi
#PBS -l select=${NNODES}:ncpus=${NTASKSPN}
#PBS -l place=scatter:excl 
#PBS -l walltime=00:30:00
#PBS -N ${JNAME}
#PBS -q ${QUEUE}

export OMP_NUM_THREADS=1
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}

if [ ${debug} -eq 1 ]; then
 export OOPS_TRACE=-1
 export OOPS_DEBUG=-1
fi

module load cray-libpals/1.6.1
module load cray-pals

ulimit -s unlimited
export GFORTRAN_CONVERT_UNIT='big_endian:101-200'

cd ${EXPDIR}

if [ $FROMCIC -eq 1 ]; then
  ln -fs ${RUNDIR}/${EXP}/${LABELIprev:0:10}/runmod/mpasout.${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}T${LABELI:8:2}.00.00.nc ${EXPDIR}/bg.${ANADATEp}.nc
  cp     ${RUNDIR}/${EXP}/${LABELIprev:0:10}/runmod/mpasout.${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}T${LABELI:8:2}.00.00.nc ${EXPDIR}/an.${ANADATEp}.nc
  ln -fs ${RUNDIR}/${EXP}/${LABELIprev:0:10}/runmod/mpasout.${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}T${LABELI:8:2}.00.00.nc ${EXPDIR}/${inputfile}

 else
  ln -fs ${RUNDIR}/${EXP}/${LABELI:0:10}/runmoc/mpasout.${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}T${LABELI:8:2}.00.00.nc ${EXPDIR}/bg.${ANADATEp}.nc
  cp     ${RUNDIR}/${EXP}/${LABELI:0:10}/runmoc/mpasout.${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}T${LABELI:8:2}.00.00.nc ${EXPDIR}/an.${ANADATEp}.nc
  ln -fs ${RUNDIR}/${EXP}/${LABELI:0:10}/runmoc/mpasout.${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}T${LABELI:8:2}.00.00.nc ${EXPDIR}/${inputfile}
fi

echo  "STARTING AT \`date\` "
Start=\`date +%s.%N\`
echo \$Start >  ${EXPDIR}/logs/Timing.jedi

date

time mpirun -np ${NTASKS} ${EXEDIR}/mpasjedi_variational.x ${EXPDIR}/3dvar.yaml ${EXPDIR}/3dvar.log &> ${EXPDIR}/logs/logrun.jedi
wait

End=\`date +%s.%N\`
echo  "FINISHED AT \`date\` "
echo \$End   >> ${EXPDIR}/logs/Timing.jedi
echo \$Start \$End | awk '{print \$2 - \$1" sec"}' >>  ${EXPDIR}/logs/Timing.jedi

date

if test -s 3dvar.log ; then errorcode=\$(cat 3dvar.log | tail -2 | head -1 | awk '{print \$11}') ; fi

echo "ERRORCODE: \$errorcode"

if [ 'x'\$errorcode == x0 ]; then
 echo "Data Assimilation Run Successfully"
 mkdir 3dvarlog
 mv 3dvar.log* 3dvarlog
 mkdir geovalout
 mv geoval_out_*nc geovalout
 else
 echo ">>>>> Error in Data Assimilation <<<<<"
fi

exit 0
EOF0

chmod +x jedi.pbs

if [ 'x'$pid == 'x' ]; then
  qsub ./jedi.pbs
 else
  qsub -W depend=afterok:${pid} ./jedi.pbs
fi

#EOC
