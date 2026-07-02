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
#        ./runGeo.sh EXP RES
#
#           o EXP     :   Nome do experimento, ex. TC
#           o RES     :   Resolucao do experimento: ex. 10242 (p/ 240km), 163842 (p/ 60km)
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

if [ $# -ne 2 ]; then
   usage
   exit 1
fi

EXP=${1}
RES=${2}

BASEDIR=${HOMEP}/mpas_jedi
RUNDIR=${BASEDIR}/run
EXEDIR=${BASEDIR}/bin
TBLDIR=${BASEDIR}/tables
GRIDIR=${BASEDIR}/grids
NMLDIR=${BASEDIR}/namelists
SCRDIR=${BASEDIR}/scripts
GEODIR=${BASEDIR}/geog
EXPDIR=${RUNDIR}/${EXP}/static

echo ${EXPDIR}

if [ ! -d ${EXPDIR} ]; then
   mkdir -p ${EXPDIR}/logs
   else
   rm -rf ${EXPDIR}
   mkdir -p ${EXPDIR}/logs
fi

cd ${EXPDIR}

ln -s ${GRIDIR}/x1.${RES}.grid.nc .

static_interp="true"
native_gwd_static="true"
vertical_grid="false"
met_interp="false"
input_sst="false"
frac_seaice="false"

start_date=${LABELI:0:4}-${LABELI:4:2}-${LABELI:6:2}_${LABELI:8:2}:00:00

sed -e "s,#STATIC_INTERP#,${static_interp},g; \
        s,#NATIVE_GWD_STATIC#,${native_gwd_static},g; \
        s,#VERTICAL_GRID#,${vertical_grid},g; \
        s,#MET_INTERP#,${met_interp},g; \
        s,#INPUT_SST#,${input_sst},g; \
        s,#FRAC_SEAICE#,${frac_seaice},g; \
        s,#RES#,${RES},g; \
        /START_DATE/d" \
    ${NMLDIR}/namelist.init_atmosphere_${EXP} > ${EXPDIR}/namelist.init_atmosphere
        
filename_templatei="x1."${RES}".grid.nc"
filename_templateo="x1."${RES}".static.nc"

sed -e "s,#filename_templatei#,${filename_templatei},g; \
        s,#filename_templateo#,${filename_templateo},g" \
    ${NMLDIR}/streams.init_atmosphere_${EXP} > ${EXPDIR}/streams.init_atmosphere

NNODES=1
NTASKSPN=256
(( NTASKS = NTASKSPN * NNODES ))
ln -sf ${TBLDIR}/x1.${RES}.graph.info.part.${NTASKS}     .
JNAME=Geo_MONAN
QUEUE=pesqmini

cat > geo.pbs <<EOF0
#!/bin/bash

#PBS -j oe
#PBS -o ${EXPDIR}/logs/log.geo
#PBS -l select=${NNODES}:ncpus=${NTASKSPN}
#PBS -l place=scatter:excl 
#PBS -l walltime=00:30:00
#PBS -N ${JNAME}
#PBS -q ${QUEUE}

export OMP_NUM_THREADS=1
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}

module load cray-libpals/1.6.1
module load cray-pals

ulimit -s unlimited

cd ${EXPDIR}

echo  "STARTING AT \`date\` "
Start=\`date +%s.%N\`
echo \$Start >  ${EXPDIR}/logs/Timing.geo

date

time mpirun -np ${NTASKS} ${EXEDIR}/mpas_init_atmosphere &> ${EXPDIR}/logs/logrun.geo
wait

End=\`date +%s.%N\`
echo  "FINISHED AT \`date\` "
echo \$End   >> ${EXPDIR}/logs/Timing.geo
echo \$Start \$End | awk '{print \$2 - \$1" sec"}' >>  ${EXPDIR}/logs/Timing.geo

date
exit 0
EOF0

chmod +x geo.pbs

qsub ./geo.pbs

#EOC
