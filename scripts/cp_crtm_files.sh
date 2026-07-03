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
#        ./cp_crtm_files.sh 
#
# !REVISION HISTORY:
#
# 01 Apr 2026 - Vendrasco, E. P. - Initial Version
# 
# !REMARKS:
#
#EOP
#-----------------------------------------------------------------------------#
#BOC


DIR=#PATH2BUILD_DIR#/test_data/3.1.1/fix_REL-3.1.1.2/fix
DIROUT=#PATH2mpas_jedi_wf#/crtm3
ENDIAN="Little_Endian"

rm -rf ${DIROUT}/*

declare -a path=("ACCoeff" "AerosolCoeff" "BeCoeff" "CloudCoeff" "NLTECoeff" "SpcCoeff" "TauCoeff/ODPS")
arraylength=${#path[@]}

for (( i=0; i<${arraylength}; i++ )); do
if [ ${path[$i]} != "ACCoeff" -a ${path[$i]} != "NLTECoeff" -a ${path[$i]} != "BeCoeff" ]; then
 ln -sf ${DIR}/${path[$i]}/${ENDIAN}/*      ${DIROUT}
fi 
 ln -sf ${DIR}/${path[i]}/netCDF/*         ${DIROUT}
done



declare -a path=(EmisCoeff/IR_Ice/SEcategory  EmisCoeff/IR_Land/SEcategory  EmisCoeff/IR_Snow/SEcategory  EmisCoeff/IR_Water  EmisCoeff/MW_Water  EmisCoeff/VIS_Ice/SEcategory  EmisCoeff/VIS_Land/SEcategory  EmisCoeff/VIS_Snow/SEcategory  EmisCoeff/VIS_Water/SEcategory)
arraylength=${#path[@]}

for (( i=0; i<${arraylength}; i++ )); do
 ln -sf ${DIR}/${path[i]}/${ENDIAN}/*      ${DIROUT}
 ln -sf ${DIR}/${path[i]}/netCDF/*         ${DIROUT}
done

#EOC

