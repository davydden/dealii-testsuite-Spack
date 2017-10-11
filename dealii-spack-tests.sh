#!/bin/bash
#
# A bash script to install and test various versions of deal.II via Spack
#
# Can be used with Cron job:
# $crontab -e
# * * */1 * * /path/to/dealii-spack-tests.sh
#     ^^^ run every day
# p.s. check content by: crontab -l

# Path to Spack:
SPACK_ROOT=/home/davydden/spack

# a commit in Spack to use:
SPACK_COMMIT=57643ae84e95d3053d6bb8022b9de0420d151467

# dealii specs (configuration) to test in addition to settings in packages.yaml:
#declare -a SPECS=('dealii+mpi^openmpi^openblas' 'dealii+mpi^openmpi^intel-mkl' 'dealii+mpi^openmpi^atlas' 'dealii+mpi+int64^openmpi^openblas' 'dealii+mpi^mpich^openblas');

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


#
# =======================================================
# DON'T EDIT BELOW
# =======================================================
#

# First, setup path to Spack and environment-module
export PATH=$SPACK_ROOT/bin:$PATH
spack install environment-modules
MODULES_HOME=$(spack location -i environment-modules)
source ${MODULES_HOME}/Modules/init/bash
. $SPACK_ROOT/share/spack/setup-env.sh

# reset Spack to the desired commit:
cd $SPACK_ROOT
# git checkout develop
# git pull
# git reset --hard $SPACK_COMMIT

# Install and load numdiff
spack install numdiff
spack load numdiff
spack install cmake
spack load cmake

# Go through all the specs and test:
for i in "${SPECS[@]}"
do
  # install dependencies
  spack install --only dependencies "$i" || { echo "failed to install $i" ; exit 1; }
  # install dealii and keep the stage folder
  spack install --keep-stage "$i" || { echo "failed to install $i" ; exit 1; }
  # go to the stage
  spack cd -s "$i"
  cd dealii/spack-build
  # setup environement to be exactly the same as during the buld of the spec
  # spack env "$i" bash
  # setup / run / submit unit tests
  make -j8 setup_tests
  ctest -j8
  ctest -j8 -DDESCRIPTION="$i" -V -S ../tests/run_testsuite.cmake
  # exit spack env
  # exit
  cd $SPACK_ROOT
  # remove the current installation so that next time we build from scratch
  # spack uninstall "$i"
  # clean the stage:
  # spack clean -s
done

