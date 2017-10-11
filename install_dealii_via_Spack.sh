#!/usr/bin/env bash

# -----------------------------------------------------------------
# DISCLAIMER
# Adapted from http://michal.kosmulski.org/computing/shell-scripts/
# -----------------------------------------------------------------
# This script come without warranty of any kind.
# You use it at your own risk.
# We assume no liability for the accuracy, correctness, completeness, or usefulness of this script, nor for any sort of damages that using it may cause.

# echo status
secho() {
  echo "\033[0;94m==> \033[0m$@"
}

# echo status with 2 arguments
secho2() {
  echo "\033[0;94m==> \033[0m$1 \033[0;32m$2 \033[0m"
}

# echo warning
wecho() {
  echo "\033[4;33mWarning:\033[0m $@"
}

# error
becho() {
  echo "\033[4;31mError:\033[0m $@"
}


# adopted from https://github.com/dealii/candi/blob/master/candi.sh
guess_platform() {
    # Try to guess the name of the platform we're running on
    if [ -f /usr/bin/cygwin1.dll ]; then
        echo cygwin

    elif [ -f /etc/fedora-release ]; then
        local FEDORANAME=`gawk '{if (match($0,/\((.*)\)/,f)) print f[1]}' /etc/fedora-release`
        case ${FEDORANAME} in
            "Schrödinger’s Cat"*) echo fedora19;;
            "Heisenbug"*)         echo fedora20;;
            "Twenty One"*)        echo fedora21;;
            "Twenty Two"*)        echo fedora22;;
            "Twenty Three"*)      echo fedora23;;
            "Twenty Four"*)       echo fedora24;;
            "Twenty Five"*)       echo fedora25;;
        esac

    elif [ -f /etc/redhat-release ]; then
        local RHELNAME=`gawk '{if (match($0,/\((.*)\)/,f)) print f[1]}' /etc/redhat-release`
        case ${RHELNAME} in
            "Tikanga"*) echo rhel5;;
            "Santiago"*) echo rhel6;;
            "Maipo"*) echo rhel7;;
            "Core"*) echo centos7;;
        esac

    elif [ -x /usr/bin/sw_vers ]; then
        local MACOSVER=$(sw_vers -productVersion)
        case ${MACOSVER} in
            10.4*)    echo macos_tiger;;
            10.5*)    echo macos_leopard;;
            10.6*)    echo macos_snowleopard;;
            10.7*)    echo macos_lion;;
            10.8*)    echo macos_mountainlion;;
            10.9*)    echo macos_mavericks;;
            10.10*)   echo macos_yosemite;;
            10.11*)   echo macos_elcapitan;;
            10.12*)   echo macos_sierra;;
        esac

    elif [ -x /usr/bin/lsb_release ]; then
        DISTRO=$(lsb_release -i -s)
        CODENAME=$(lsb_release -c -s)
        DESCRIPTION=$(lsb_release -d -s)
        case ${DISTRO}:${CODENAME}:${DESCRIPTION} in
            *:*:*Ubuntu*\ 12*)     echo ubuntu12;;
            *:*:*Ubuntu*\ 14*)     echo ubuntu14;;
            *:*:*Ubuntu*\ 15*)     echo ubuntu15;;
            *:xenial*:*Ubuntu*)    echo ubuntu16;;
            *:Tikanga*:*)          echo rhel5;;
            *:Santiago*:*)         echo rhel6;;
            Scientific:Carbon*:*)  echo rhel6;;
            *:*:*CentOS*\ 5*)      echo rhel5;;
            *:*:*CentOS*\ 6*)      echo rhel6;;
            *:*:*openSUSE\ 12*)    echo opensuse12;;
            *:*:*openSUSE\ 13*)    echo opensuse13;;
        esac
    fi
}

# --------
# SETTINGS
# --------
PLATFORM=`guess_platform`
case ${PLATFORM} in
  *macos*)      bashfile=~/.bash_profile;;
  *)            bashfile=~/.bashrc;;
esac
SPACK_ROOT=~/spack.tmp

if [ $# -eq 0 ]; then
  secho "Using default installation and file paths."
fi

# http://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
while [ -n "$1" ]; do
  key="$1"

  case $key in
    -p|--prefix)
      SPACK_ROOT="$2"
      shift # past argument
    ;;
    -b|--bashfile)
      bashfile="$2"
      shift # past argument
    ;;
    *)
      becho "Unknown option. Exiting..."
      exit 1
    ;;
  esac

  shift # past argument or value
done

secho2 "Spack installation path:" "$SPACK_ROOT"
secho2 "Bash file:" "$bashfile"

# -------------------------
# REQUIRES USER INTERACTION
# -------------------------

echo "Do you want to add Spack and deal.II paths to $bashfile? [Y/n]:"
read addtobash

# -----------------------------
# PREREQUISITE SYSTEM LIBRARIES
# -----------------------------

secho "Prerequisite system libraries"
echo "You are about to be asked for your password so that "
echo "essential system libraries can be installed."
echo "After this, the rest of the build should be automatic."

case ${PLATFORM} in
  *ubuntu*)
    sudo apt-get install curl git csh subversion gcc g++ gfortran > /dev/null
    sudo -k
    ;;
  *opensuse*)
    su -c 'zypper -n in Modules gcc-fortran subversion git'
    ;;
  *macos*)
    echo "Skipping on macOS"
    ;;
esac

# ----------
# SPACK BASE
# ----------
if [ ! -d $SPACK_ROOT ]; then
  git clone https://github.com/llnl/spack.git $SPACK_ROOT
  cd $SPACK_ROOT
  # tested on 11.03.2017 on Ubuntu16.04
  # 12.03.2017 on macOS Sierra
  git reset --hard e3101808ae077a3d352d8740cc39d877ed355b86
fi

export PATH="$SPACK_ROOT/bin:$PATH"

# -------------
# DEAL.II SUITE
# -------------

# install environment-modules for platforms which don't have it
case ${PLATFORM} in
  *opensuse*)
    ;;
  *)
    spack install environment-modules
    ;;
esac

# install gcc for macs
case ${PLATFORM} in
  *macos*)
    secho2 "make sure command line tools are installed:" "xcode-select --install"
    secho  "if that is the case, hit enter to continue"
    read
    spack install gcc
    GCC_PATH=`spack location -i gcc`
    export PATH="$GCC_PATH/bin:$PATH"
    spack compiler remove clang
    spack compiler find
    ;;
  *)
    ;;
esac

# install deal.II
spack install dealii

# ----
# BASH
# ----

DEAL_II_DIR=`spack location -i dealii`

if [ -e $bashfile ]; then
  if [ "${addtobash}" = "y" ] || [ "${addtobash}" = "Y" ] || [ "${addtobash}" = "Yes" ] || [ "${addtobash}" = "yes" ]; then
    secho2 "Adding Spack paths to" "$bashfile"

    case ${PLATFORM} in
      *opensuse*)
        MODULES_HOME='FIXME';;
      *)
        MODULES_HOME=`spack location -i environment-modules`;;
    esac

    echo "" >> $bashfile
    echo "## === Spack ===" >> $bashfile
    echo "SPACK_ROOT=$SPACK_ROOT" >> $bashfile
    echo "PATH=\"\$SPACK_ROOT/bin:\$PATH\"" >> $bashfile
    echo "MODULES_HOME=$MODULES_HOME" >> $bashfile
    echo "source \$MODULES_HOME/Modules/init/bash" >> $bashfile
    echo ". \$SPACK_ROOT/share/spack/setup-env.sh" >> $bashfile
    echo "DEAL_II_DIR=$DEAL_II_DIR" >> $bashfile
  else
    wecho ""
    echo "To use deal.II you must pass the following flag to CMake when configuring your problems:"
    echo "\033[1;37m-DDEAL_II_DIR=$DEAL_II_DIR\033[0m"
  fi
else
  becho "Bash file does not exist. Could not add paths as requested."
fi
