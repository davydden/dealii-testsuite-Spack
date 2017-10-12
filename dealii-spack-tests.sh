#!/bin/bash
#
# A bash script to install and test various versions of deal.II via Spack
#
# Can be used with Cron job:
# $crontab -e
# 0 0 * * * /path/to/dealii-spack-tests.sh
# ^^^ run every day at midnight
# p.s. check content by: crontab -l

# Path to Spack:
SPACK_ROOT=/home/davydden/spack

# a commit in Spack to use:
SPACK_COMMIT=e8073970743e80e375d804b626ec64eaacd4da20

BASE_SPEC=dealii@develop+adol-c+nanoflann+sundials+assimp+mpi+python

# dealii specs (configuration) to test in addition to BASE_SPEC:
declare -a SPECS=(
'^openmpi^openblas'
'^openmpi^intel-mkl'
'^openmpi^atlas'
'+int64^openmpi^openblas'
'^mpich^openblas'
'+optflags^openmpi^openblas');

# =======================================================
# DON'T EDIT BELOW
# =======================================================

# Get number of cores:
NP=$(nproc --all)

# First, setup path to Spack and environment-module
export PATH=$SPACK_ROOT/bin:$PATH
spack install environment-modules
MODULES_HOME=$(spack location -i environment-modules)
source ${MODULES_HOME}/Modules/init/bash
. $SPACK_ROOT/share/spack/setup-env.sh

# reset Spack to the desired commit:
cd $SPACK_ROOT
git checkout develop
git pull
git reset --hard $SPACK_COMMIT

# Install and load numdiff
spack install numdiff
spack load numdiff
# FIXME: remove when spack env can be called from bash
spack install cmake
spack load cmake

# Go through all the specs and test:
for i in "${SPECS[@]}"
do
  # current spec:
  s="$BASE_SPEC$i"
  # install dependencies
  spack install --only dependencies "$s" || { echo "failed to install $s" ; exit 1; }
  # install dealii and keep the stage folder
  spack install --keep-stage "$s" || { echo "failed to install $s" ; exit 1; }
  # go to the stage
  spack cd -s "$s"
  cd dealii/spack-build
  # setup environement to be exactly the same as during the buld of the spec
  # spack env "$s" bash
  # setup / run / submit unit tests
  make -j"$NP" setup_tests
  ctest -j"$NP"
  ctest -j"$NP" -DDESCRIPTION="$i" -V -S ../tests/run_testsuite.cmake
  # exit spack env
  # exit
  cd $SPACK_ROOT
  # remove the current installation so that next time we build from scratch
  spack uninstall -y "$s"
  # clean the stage:
  spack clean -s
done

