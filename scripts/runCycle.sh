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
#        ./runCycle.sh EXP RES LABELI LABELF NHCIC FCST CIC
#
#           o EXP     :   Nome do experimento, ex. TC
#           o RES     :   Resolucao do experimento: ex. 10242 (p/ 240km), 163842 (p/ 60km)
#           o LABELI  :   Data inicial (YYYYMMDDHH), ex. 2021010100
#           o LABELF  :   Data final (YYYYMMDDHH), ex. 2021010200
#           o NHCIC   :   Número de horas do ciclo (ex. 6 [horas])
#           o FCST    :   Tempo de previsao, em horas (ex. 24 [horas])
#           o CIC     :   Inicio do ciclo (Cold Start: 0 - Warm Start: 1)
#
# !REVISION HISTORY:
#
# 18 Sept 2025 - Vendrasco, E. P. - Initial Version based on RMS
# 
# !REMARKS:
#
#EOP
#-----------------------------------------------------------------------------#
#BOC

function usage(){
   sed -n '/^#BOP/,/^#EOP/{/^#BOP/d;/^#EOP/d;p}' ${BASH_SOURCE}
}

if [ $# -ne 7 ]; then
   usage
   exit 1
fi

EXP=${1}
RES=${2}
LABELI=${3}
LABELF=${4}
NHCIC=${5}
FCST=${6}
CIC=${7}

GFSTRES=3

FROMCIC=1
FROMDA=1
WINDOW=180

BASEDIR=${HOMEP}/mpas_jedi
RUNDIR=${BASEDIR}/run
GFSDIR=${BASEDIR}/gfsdata
SSTDIR=${BASEDIR}/sstdata
EXEDIR=${BASEDIR}/bin
TBLDIR=${BASEDIR}/tables
GRIDIR=${BASEDIR}/grids
NMLDIR=${BASEDIR}/namelists
SCRDIR=${BASEDIR}/scripts
GEODIR=${BASEDIR}/geog

LABELII=${LABELI} 

while [ ${LABELI} -le ${LABELF} ]; do

echo
echo -e "\033[34;1m      >>>>  Data da Analise: ${LABELI}  (Ciclo: $CIC) <<<< \033[m"

EXPDIR=${RUNDIR}/${EXP}/${LABELI:0:10}

if [ ${CIC} -eq 0 ]; then

  out=$(${SCRDIR}/runInit.sh ${EXP} ${RES} ${LABELI} ${LABELI} ${NHCIC} ${FCST})
  pid=$(echo "$out" | awk '{print $NF}' | tail  -1)
  echo "rodando init: pid >> $pid"
  out=$(${SCRDIR}/runModel.sh ${EXP} ${RES} ${LABELI} ${LABELI} ${NHCIC} ${GFSTRES} 0 ${pid}) 
  pid=$(echo "$out" | awk '{print $NF}' | tail  -1)
  echo "rodando model: pid >> $pid"
  out=$(${SCRDIR}/runDA.sh    ${EXP} ${RES} ${LABELI} ${NHCIC} ${FCST} 0 ${WINDOW} ${pid})
  pid=$(echo "$out" | awk '{print $NF}' | tail  -1)
  echo "rodando da:    pid >> $pid"
  out=$(${SCRDIR}/runModel.sh ${EXP} ${RES} ${LABELI} ${LABELI} ${NHCIC} ${FCST} ${FROMDA} ${pid}) 
  pid=$(echo "$out" | awk '{print $NF}' | tail  -1)
  echo "rodando model: pid >> $pid"
  
  LABELI=$(date --date "${LABELI:0:8} ${LABELI:8:4} $NHCIC hours" +%Y%m%d%H)

  let CIC++

 else

  out=$(${SCRDIR}/runDA.sh    ${EXP} ${RES} ${LABELI} ${NHCIC} ${FCST} ${FROMCIC} ${WINDOW} ${pid})
  pid=$(echo "$out" | awk '{print $NF}' | tail  -1)
  echo "rodando da:    pid >> $pid"
  out=$(${SCRDIR}/runModel.sh ${EXP} ${RES} ${LABELI} ${LABELI} ${NHCIC} ${FCST} ${FROMDA} ${pid}) 
  pid=$(echo "$out" | awk '{print $NF}' | tail  -1)
  echo "rodando model: pid >> $pid"
  
  LABELI=$(date --date "${LABELI:0:8} ${LABELI:8:4} $NHCIC hours" +%Y%m%d%H)

  let CIC++

fi

done

#EOC
