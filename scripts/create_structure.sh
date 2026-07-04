
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
#        ./create_structure.sh
#
#           o STRUCTDIR     :   Caminho completo até o repositório. Ex: /p/projetos/monan_das/${USER}
#           o BUILDDIR      :   Caminho completo até a pasta de compilação. Ex: /p/projetos/monan_das/${USER}/mpas_jedi_build
#
# !REVISION HISTORY:
#
# 03 Jul 2026 - Vendrasco, E. P. - Initial Version
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

STRUCTDIR=${1}
BUILDDIR=${2}
BASEDIR=${STRUCTDIR}/mpas_jedi_wf
CPFROMDIR=/p/projetos/monan_das/ss/mpas_jedi_wf

mkdir -p ${STRUCTDIR}/mpas_jedi_wf/{bedata,bin,crtm3,gfsdata,grids,obsdata,run,sstdata}

#1o B Matrix
ln -sf ${CPFROMDIR}/bedata/B_Matrix_TC  ${STRUCTDIR}/mpas_jedi_wf/bedata

#2o Executables
cp ${BUILDDIR}/bin/{ioda-upgrade-v1-to-v2.x,ioda-upgrade-v2-to-v3.x,mpas_atmosphere,mpas_init_atmosphere,mpasjedi_error_covariance_toolbox.x,mpasjedi_variational.x}  ${STRUCTDIR}/mpas_jedi_wf/bin
cp ${CPFROMDIR}/bin/unMP.exe ${STRUCTDIR}/mpas_jedi_wf/bin
cp $(dirname ${CPFROMDIR})/packages/da_advance_time/da_advance_time.exe ${STRUCTDIR}/mpas_jedi_wf/bin
cp $(dirname ${CPFROMDIR})/packages/obs2ioda_prebuild/src/obs2ioda-v2.x ${STRUCTDIR}/mpas_jedi_wf/bin

#3o CRTM3
sed -e "s,#PATH2BUILD_DIR#,${BUILDDIR},g; \
        s,#PATH2mpas_jedi_wf#,${BASEDIR},g" \
    ./cp_crtm_files.sh > ./cp_crtm_files_tmp.sh
chmod +x ./cp_crtm_files_tmp.sh
./cp_crtm_files_tmp.sh
rm ./cp_crtm_files_tmp.sh

#4o Grids
cp ${CPFROMDIR}/grids/*  ${STRUCTDIR}/mpas_jedi_wf/grids

#5o Tables
cp -r ${CPFROMDIR}/tables/physFiles ${STRUCTDIR}/mpas_jedi_wf/tables
cp -r ${CPFROMDIR}/tables/x1.163842.invariant.nc ${STRUCTDIR}/mpas_jedi_wf/tables

#6o gfsdata e sstdata
ln -s /p/projetos/ioper/data/external/gfs_0p25/2026 ${STRUCTDIR}/mpas_jedi_wf/gfsdata
ln -s /oper/dados/dboper/raw/arch/mod/ncep/sst/2026 ${STRUCTDIR}/mpas_jedi_wf/sstdata

