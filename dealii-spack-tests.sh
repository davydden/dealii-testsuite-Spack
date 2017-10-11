#!/bin/bash
#
# A bash script to install and test various versions of deal.II via Spack
#
# Can be used with Cron job:
# $crontab -e
# * */2 * * * /path/to/dealii-auxiliary-scripts.sh
#   ^^^ run every 2 hours
# p.s. check content by: crontab -l

# a commit in Spack to use:
SPACK_COMMIT=57643ae84e95d3053d6bb8022b9de0420d151467

# dealii specs (configuration) to test:
#declare -a SPECS=('dealii%gcc@5.4.0+mpi^openmpi^openblas' 'dealii%gcc@5.4.0+mpi^openmpi^intel-mkl' 'dealii%gcc@5.4.0+mpi^openmpi^atlas' 'dealii%gcc@5.4.0+mpi+int64^openmpi^openblas' 'dealii%gcc@5.4.0+mpi^mpich^openblas');

declare -a SPECS=('dealii+mpi^openmpi^openblas');

# Prerequisites:
# 1) ~/.spack/packages.yaml :
# packages:
#  dealii:
#    version: [develop]
#    variants: +optflags+adol-c+nanoflann+sundials+assimp
# 2) ~/.spack/config.yaml :
# config:
#  build_stage:
#    - $spack/var/spack/stage
# 3) environment-modules must be setup in .bashrc:
# MODULES_HOME=$(spack location -i environment-modules)
# source ${MODULES_HOME}/Modules/init/bash
# . $SPACK_ROOT/share/spack/setup-env.sh


cd $SPACK_ROOT
# git checkout develop
# git pull
# git reset --hard $SPACK_COMMIT

spack install numdiff
spack load numdiff

for i in "${SPECS[@]}"
do
  cd $SPACK_ROOT
  # install dependencies
  spack install --only dependencies "$i" || { echo 'failed to install $i' ; exit 1; }
  # install dealii and keep the stage folder
  spack install --keep-stage "$i" || { echo 'failed to install $i' ; exit 1; }
  # go to the stage
  spack cd -s "$i"
  # setup environement
  spack env "$i" bash
  # setup / run / submit unit tests
  make -j8 setup_tests
  ctest -j8
  ctest -j8 -DDESCRIPTION="$i" -V -S ../tests/run_testsuite.cmake
  # exit spack env
  exit
done

