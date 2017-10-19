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
SPACK_ROOT=$HOME/spack

# a commit in Spack to use:
SPACK_COMMIT=3e67b98e29579ae8203f308f9e14e2f1de8f7b77

BASE_SPEC=dealii@develop+adol-c+nanoflann+sundials+assimp+mpi+python

# dealii specs (configuration) to test in addition to BASE_SPEC:
declare -a SPECS=(
'^openmpi^openblas'
#'^openmpi^intel-mkl'
#'^openmpi^atlas'
#'+int64^openmpi^openblas'
#'^mpich^openblas'
'+optflags^openmpi^openblas'
);

# =======================================================
# DON'T EDIT BELOW
# =======================================================

# echo status
secho() {
  echo -e "\033[0;94m==> \033[0m$@"
}

# error
becho() {
  echo -e "\033[4;31mError:\033[0m $@"
}

# Get number of cores:
if [ -x /usr/bin/sw_vers ]; then
  NP=$(sysctl -n hw.ncpu)
else
  NP=$(nproc --all)
fi

secho "Will use $NP processes"

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

# Go through all the specs and test:
for i in "${SPECS[@]}"
do
  # current spec:
  s="$BASE_SPEC$i"
  secho "Testing: $s"
  # clean the stage:
  spack clean -s
  # install dependencies
  spack install --only dependencies "$s" || { becho "Failed to install $s" ; exit 1; }
  # install dealii and keep the stage folder
  spack install --keep-stage "$s" || { becho "Failed to install $s" ; exit 1; }
  # go to the stage
  spack cd -s "$s"
  cd dealii/spack-build
  # setup environement to be exactly the same as during the buld of the spec.
  # then setup / run / submit unit tests via here document
  spack env "$s" bash << EOF
ctest -j"$NP" -DDESCRIPTION="$i" -V -S ../tests/run_testsuite.cmake
EOF
  secho "Finished testing: $s"
  cd $SPACK_ROOT
  # remove the current installation so that next time we build from scratch
  spack uninstall -a -y "$s"
  # clean the stage:
  spack clean -s
done
