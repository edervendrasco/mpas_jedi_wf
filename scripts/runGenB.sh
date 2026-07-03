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
#        ./runGenB.sh EXP RES LABELI LABELF NNODES NTASKSPN 
#
#           o EXP       :   Nome do experimento, ex. TC
#           o RES       :   Resolucao do experimento: ex. 10242 (p/ 240km), 163842 (p/ 60km)
#           o LABELI    :   Data inicial (YYYYMMDDHH), ex. 2021010100
#           o LABELF    :   Tempo de previsao, em horas (ex. 24 [horas])
#           o NNODES    :   Total de nós computacionais, ex. 1
#           o NTASKSPN  :   Total de cores por nó, ex. 64 ou 128
#
# !REVISION HISTORY:
#
# 10 Sept 2024 - Vendrasco, E. P. - Initial Version based on RMS
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
NNODES=${5}
NTASKSPN=${6}

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
WRFBIN=${EXEDIR}

EXPDIR=${RUNDIR}/${EXP}/gB

fhr0=12
fhr1=24
fhr2=48

run_prep_step1="F"
run_prep_step2="F"
run_prep_step3="F"
run_prep_step4="F"
run_prep_step5="F"

run_proc_step0="F"
run_proc_step1="F"
run_proc_step2a="F"
run_proc_step2b="F"
run_proc_step2c="F"
run_proc_step3="F"
run_proc_step4a="F"
run_proc_step4b="F"
run_proc_step5="F"

if [ -e ${EXPDIR} ]; then
  echo "Folder ${EXPDIR} already exist! Warning: It will not be removed."
  else
   echo "Creating folder ${EXPDIR}/{prep,proc}"
   mkdir -p ${EXPDIR}/{prep,proc}
fi

cd ${EXPDIR}/prep

#PREPROCESSING

#Step 1
if [ ${run_prep_step1} == "T" ]; then ${SCRDIR}/GB/prep/1_generate_ESMF_weights.bash ${EXPDIR}/prep ${TBLDIR} ${RES} ; fi

#Step 2
ref_file=${RUNDIR}/${EXP}/${LABELI}/runinit/x1.${RES}.init.nc
if [ ${run_prep_step2} == "T" ]; then ${SCRDIR}/GB/prep/2_generate_template_PTB.bash ${EXPDIR}/prep ${TBLDIR} ${RES} ${ref_file} ; fi

#Step 3
if [ ${run_prep_step3} == "T" ]; then
  ${SCRDIR}/GB/prep/3_convert_uv_to_psichi.bash ${EXPDIR}/prep ${TBLDIR} ${WRFBIN} ${RES} ${LABELI} ${LABELF} ${fhr0} ${fhr1}
  ${SCRDIR}/GB/prep/3_convert_uv_to_psichi.bash ${EXPDIR}/prep ${TBLDIR} ${WRFBIN} ${RES} ${LABELI} ${LABELF} ${fhr0} ${fhr2}
fi

#Step 4
if [ ${run_prep_step4} == "T" ]; then
  ${SCRDIR}/GB/prep/4_add_variables.bash ${EXPDIR}/prep ${WRFBIN} ${LABELI} ${LABELF} ${fhr0} ${fhr1}
  ${SCRDIR}/GB/prep/4_add_variables.bash ${EXPDIR}/prep ${WRFBIN} ${LABELI} ${LABELF} ${fhr0} ${fhr2}
fi

#Step 5
if [ ${run_prep_step5} == "T" ]; then ${SCRDIR}/GB/prep/5_ncdiff.bash ${EXPDIR}/prep ${WRFBIN} ${LABELI} ${LABELF} ${fhr0} ${fhr1} ${fhr2} ; fi

#PROCESSING

#Step 0
if [ ${run_proc_step0} == "T" ]; then ${SCRDIR}/GB/proc/0_link_samples.bash ${EXPDIR} ${WRFBIN} ${LABELI} ${LABELF}  ${fhr0} ${fhr1} ${fhr2}; fi

#Step 1
if [ ${run_proc_step1} == "T" ]; then ${SCRDIR}/GB/proc/1_run_vbal.bash ${EXPDIR}/proc ${NMLDIR} ${TBLDIR} ${EXEDIR} ${WRFBIN} ${LABELI} ${LABELF} ${EXP} ${RES} ${NNODES} ${NTASKSPN} ; fi

#Step 2a
if [ ${run_proc_step2a} == "T" ]; then ${SCRDIR}/GB/proc/2a_run_hdiag_var.bash ${EXPDIR}/proc ${NMLDIR} ${TBLDIR} ${EXEDIR} ${WRFBIN} ${LABELI} ${LABELF} ${EXP} ${RES} ${NNODES} ${NTASKSPN} ; fi

#Step 2b
if [ ${run_proc_step2b} == "T" ]; then ${SCRDIR}/GB/proc/2b_run_hdiag_var.bash ${EXPDIR}/proc ${NMLDIR} ${TBLDIR} ${EXEDIR} ${WRFBIN} ${LABELI} ${LABELF} ${EXP} ${RES} ${NNODES} ${NTASKSPN} ; fi

#Step 2c
if [ ${run_proc_step2c} == "T" ]; then ${SCRDIR}/GB/proc/2c_modify_diagnostics.bash ${EXPDIR}/proc ${SCRDIR}/GB/proc ; fi

#Step 3
if [ ${run_proc_step3} == "T" ]; then ${SCRDIR}/GB/proc/3_run_nicas_split.bash ${EXPDIR}/proc ${NMLDIR} ${TBLDIR} ${EXEDIR} ${WRFBIN} ${LABELI} ${LABELF} ${EXP} ${RES} ${NNODES} ${NTASKSPN} ; fi

#Step 4a
if [ ${run_proc_step4a} == "T" ]; then ${SCRDIR}/GB/proc/4_merge_nicas.bash ${EXPDIR}/proc  ${NNODES}  ${NTASKSPN} ; fi

#Step 4b
if [ ${run_proc_step4b} == "T" ]; then
 if [ -e ${EXPDIR}/B_Matrix_${EXP} ]; then
   rm -rf ${EXPDIR}/B_Matrix_${EXP}
   mkdir  -p ${EXPDIR}/B_Matrix_${EXP}/{bump_nicas,bump_vertical_balance,stddev}
  else
   mkdir  -p ${EXPDIR}/B_Matrix_${EXP}/{bump_nicas,bump_vertical_balance,stddev}
 fi

 cp -v ${EXPDIR}/proc/NICAS.split/merge/*nc  ${EXPDIR}/B_Matrix_${EXP}/bump_nicas
 cp -v ${EXPDIR}/proc/VBAL/mpas_sampling*nc  ${EXPDIR}/B_Matrix_${EXP}/bump_vertical_balance
 cp -v ${EXPDIR}/proc/VBAL/mpas_vbal*nc      ${EXPDIR}/B_Matrix_${EXP}/bump_vertical_balance
 cp -v ${EXPDIR}/proc/HDIAG_VAR/merge/*nc    ${EXPDIR}/B_Matrix_${EXP}/stddev
fi

#Step 5
if [ ${run_proc_step5} == "T" ]; then ${SCRDIR}/GB/proc/5_SO.bash ${EXPDIR}/proc ${NMLDIR} ${TBLDIR} ${EXEDIR} ${WRFBIN} ${LABELI} ${LABELF} ${EXP} ${RES} ${NNODES} ${NTASKSPN} ; fi

