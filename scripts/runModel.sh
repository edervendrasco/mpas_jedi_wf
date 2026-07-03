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
#        ./runModel.sh EXP RES LABELI LABELF NHCIC FCST FROMDA
#
#           o EXP     :   Nome do experimento, ex. TC
#           o RES     :   Resolucao do experimento: ex. 10242 (p/ 240km), 163842 (p/ 60km)
#           o LABELI  :   Data inicial (YYYYMMDDHH), ex. 2021010100
#           o LABELF  :   Data final (YYYYMMDDHH), ex. 2021010100
#           o NHCIC   :   Número de horas do ciclo (ex. 6 [horas])
#           o FCST    :   Tempo de previsao, em horas (ex. 24 [horas])
#           o FROMDA  :   Se condição inicial vem do Init = 0, se vem da 
#                         assimilação de dados = 1
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

if [ $# -ne 7 ] && [ $# -ne 8 ] ; then
   usage
   exit 1
fi

EXP=${1}
RES=${2}
LABELI=${3}
LABELF=${4}
NHCIC=${5}
FCST=${6}
FROMDA=${7}
pid=${8}

if [ ${FROMDA} -eq 1 ]; then FROMCICL="true" ; else FROMCICL="false" ; fi

#export LD_LIBRARY_PATH=$NETCDF/lib:$HDF5/lib:$GRIB2/lib:$LD_LIBRARY_PATH

BASEDIR=${HOMEP}/mpas_jedi_wf
RUNDIR=${BASEDIR}/run
EXEDIR=${BASEDIR}/bin
TBLDIR=${BASEDIR}/tables
GRIDIR=${BASEDIR}/grids
NMLDIR=${BASEDIR}/namelists
SCRDIR=${BASEDIR}/scripts

LABELII=${LABELI} 
LABELFF=${LABELF} 

while [ ${LABELI} -le ${LABELFF} ]; do

echo -e "\033[34;1m      >>>>  Data da Analise: ${LABELI}  <<<< \033[m"

EXPDIR=${RUNDIR}/${EXP}/${LABELI:0:10}/runmoc
if [ ${FROMDA} -eq 1 ]; then
 EXPDIR=${RUNDIR}/${EXP}/${LABELI:0:10}/runmod
fi

cd ${EXPDIR}

if [ $FROMDA -eq 1 ]; then
  inputfile=mpasin.${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}T${LABELI:8:2}.00.00.nc
 else
  inputfile=x1.${RES}.init.nc
fi

start_date=${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}_${LABELI:8:2}:00:00
LABELF=$(date --date "${LABELI:0:8} ${LABELI:8:4} ${FCST} hours" +%Y%m%d%H%M%S)
diffdate $LABELI'0000' $LABELF 
run_duration=${dddias}_${ddhoras}:${ddminutos}:${ddsegundos}

sed -e "s,#RUN_DURATION#,${run_duration},g; \
        s,#RES#,${RES},g; \
        s,#START_DATE#,${start_date},g; \
        s,#FROMCICL#,${FROMCICL},g" \
    ${NMLDIR}/namelist.atmosphere_${EXP} > ${EXPDIR}/namelist.atmosphere

ln -fs ${TBLDIR}/physFiles/* ${EXPDIR}
cp ${NMLDIR}/stream_list* ${EXPDIR}

sed -e "s,#RES#,${RES},g; \
        s,#INPUTFILE#,${inputfile},g" \
    ${NMLDIR}/streams.atmosphere_${EXP} > ${EXPDIR}/streams.atmosphere

if [ $FROMDA -eq 0 ]; then
 sed -i '/initial_only/{ s/initial_only/none/;:a;n;ba }' ${EXPDIR}/streams.atmosphere
fi

NNODES=1
NTASKSPN=256
(( NTASKS = NTASKSPN * NNODES ))
ln -sf ${TBLDIR}/x1.${RES}.graph.info.part.${NTASKS}     ${EXPDIR}
JNAME=model_MONAN
QUEUE=pesqmidi

cat > model.pbs <<EOF0
#!/bin/bash

#PBS -j oe
#PBS -o ${EXPDIR}/logs/log.model
#PBS -l select=${NNODES}:ncpus=${NTASKSPN}
#PBS -l place=scatter:excl 
#PBS -l walltime=01:00:00
#PBS -N ${JNAME}
#PBS -q ${QUEUE}

export OMP_NUM_THREADS=1
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}

module load cray-libpals/1.6.1
module load cray-pals/1.6.1

ulimit -s unlimited

cd ${EXPDIR}

if [ $FROMDA -eq 1 ]; then
  cp $(dirname ${EXPDIR})/runda/an.${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}T${LABELI:8:2}.00.00.nc   ${EXPDIR}/mpasin.${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}T${LABELI:8:2}.00.00.nc
  cp ${TBLDIR}/x1.${RES}.invariant.nc                                                                 ${EXPDIR}
  inputfile=mpasin.${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}T${LABELI:8:2}.00.00.nc
 else
  cp $(dirname ${EXPDIR})/runinit/x1.${RES}.init.nc                                                   ${EXPDIR}
  cp ${TBLDIR}/x1.${RES}.invariant.nc                                                                 ${EXPDIR}
  cp $(dirname ${EXPDIR})/runinit/x1.${RES}.sfc_update.nc                                             ${EXPDIR}
  inputfile=x1.${RES}.init.nc
fi

echo  "STARTING AT \`date\` "
Start=\`date +%s.%N\`
echo \$Start >  ${EXPDIR}/logs/Timing.model

date
time mpirun -np ${NTASKS} ${EXEDIR}/mpas_atmosphere &> ${EXPDIR}/logs/logrun.model
wait

End=\`date +%s.%N\`
echo  "FINISHED AT \`date\` "
echo \$End   >> ${EXPDIR}/logs/Timing.model
echo \$Start \$End | awk '{print \$2 - \$1" sec"}' >>  ${EXPDIR}/logs/Timing.model

date

if test -s log.atmosphere.0000.out; then errorcode=\$(cat log.atmosphere.0000.out | tail -4 | head -1 | awk '{print \$4}'); fi

echo "ERRORCODE: \$errorcode"

if [ \$errorcode -eq 0 ]; then
 echo "Model Run Successfully"
 #mv diag.*.nc history.*.nc mpasout.*.nc mpasin.*.nc stream_list.* streams.atmosphere namelist.atmosphere runmod
 #mv log.atmosphere.0000.out logs
 #mv model.slurm scripts
 rm x1.10242.init.nc x1.10242.sfc_update.nc x1.10242.invariant.nc
  else
 echo ">>>>> Error in Model Run <<<<<"

fi

exit 0
EOF0

chmod +x model.pbs

if [ 'x'$pid == 'x' ]; then
  qsub ./model.pbs
 else
  qsub -W depend=afterok:${pid} ./model.pbs
fi

LABELI=$(date --date "${LABELI:0:8} ${LABELI:8:4} $NHCIC hours" +%Y%m%d%H)

done

#EOC
