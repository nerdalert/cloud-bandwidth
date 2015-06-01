#!/bin/bash

###########
# This script will install docker , docker-compose and docker-machine
# on Mac OS X or Linux distributions using apt-get (adv packaging tool)
# for package managment. The binaries installed are all then latest builds
# from master. Uncomment lines for stable branches.
#
# For OS X it requires boot2docker to be preinstalled. In the same
# directory as this script is an install_boot2docker.sh which requires
# brew to be installed.
##########

RESET='\033[00m'
INFO='\033[01;94m[INFO] '${RESET}
WARN='\033[01;33m[WARN] '${RESET}
ERROR='\033[01;31m[ERROR] '${RESET}

# Boot2Docker RC
BOOT2DOCKER_RC="https://github.com/tianon/boot2docker/releases/download/v1.7.0-rc1/boot2docker.iso"

# Docker Machine v0.3.0-rc1
DARWIN_DMACHINE="https://github.com/docker/machine/releases/download/v0.3.0-rc1/docker-machine_darwin-amd64"
LINUX_DMACHINE="https://github.com/docker/machine/releases/download/v0.3.0-rc1/docker-machine_linux-amd64"

# Uncomment for Docker Machine Nightly Build
# DARWIN_DMACHINE="https://docker-machine-builds.evanhazlett.com/latest/docker-machine_darwin_amd64"
# LINUX_DMACHINE="https://docker-machine-builds.evanhazlett.com/latest/docker-machine_linux_amd64"

# Uncomment for latest stable docker binary
 DARWIN_DOCKER="https://get.docker.com/builds/Darwin/x86_64/docker-latest"
# Uncomment for latest nightly build
# DARWIN_DOCKER="https://master.dockerproject.com/darwin/amd64/docker"
# Mac OS X Docker Client Binary 1.7 RC1
# DARWIN_DOCKER="https://test.docker.com/builds/Darwin/x86_64/docker-1.7.0-rc1"

# Docker Compose RC for both OS X and Linux
XPLAT_DCOMPOSE="https://github.com/docker/compose/releases/download/1.3.0rc1/docker-compose-`uname -s`-`uname -m`"

command_exists () {
    type "$1" &> /dev/null ;
}

SUDO=''
checkPermissions() {
    echo -e -e "$INFO----> Checking permissions"
    if  [ -x "$(command -v sudo)" ]; then
        SUDO='sudo'
    elif [ $(id -u) != 0 ]; then
        echo -e '----> command sudo was not found. Please rerun as root (with care :)' >&2
        exit 1
    fi
}

# Must have boot2docker installed if using Mac OS X
installMachineMac() {
    $SUDO wget --no-check-certificate -O /usr/local/bin/docker-machine https://docker-machine-builds.evanhazlett.com/latest/docker-machine_darwin_amd64
#    $SUDO wget --no-check-certificate -O /usr/local/bin/docker-machine ${DARWIN_DMACHINE}
    $SUDO chmod +x /usr/local/bin/docker-machine
}

installDockerBinMac(){
    $SUDO wget --no-check-certificate -O /usr/local/bin/docker ${DARWIN_DOCKER}
    $SUDO chmod +x /usr/local/bin/docker
}

installCompose(){
    # Ran into weird permissions on OS X so downloading to CWD then moving, hackariffic
    $SUDO wget --no-check-certificate -O ./docker-compose ${XPLAT_DCOMPOSE}
    $SUDO mv docker-compose /usr/local/bin/docker-compose
    $SUDO chmod +x /usr/local/bin/docker-compose
}

linuxDeps(){
    $SUDO apt-get upgrade -y && apt-get update -y && sudo apt-get install -y wget
}

installDockerBinLinux(){
    # Uncomment for latest stable.then Else then latest test will be installed
    # $SUDO wget --no-check-certificate -qO- https://get.docker.com/ | sh
    # Install then latest test Docker binary
    $SUDO wget --no-check-certificate -qO- https://get.docker.com/ | sh
    $SUDO usermod -aG docker `whoami`
}

# Installing case nightly build from a maintainer Evan
installMachineLinux() {
    $SUDO wget --no-check-certificate -O /usr/local/bin/docker-machine ${LINUX_DMACHINE}
    $SUDO chmod +x /usr/local/bin/docker-machine
}

checkPermissions
UNAME=$(uname)
if [ "$UNAME" = "Darwin" ]; then
    # Mac OS X platform
    echo -e "$INFO-----> Mac OS X detected, checking dependencies"
    if ! [ -x "$(command -v boot2docker)" ]; then
        echo -e "$ERROR-----> Did not find boot2docker in  /usr/local/bin/boot2docker, "
        echo -e "$INFO-----> go to https://docs.docker.com/installation/mac/ for instructions."
        echo -e "$INFO-----> Also checkout Kitematic while you are there, it pretty kewl."
        echo -e "$INFO-----> Alternatively there is a script in this directory [ install_boot2docker.sh ]"
        echo -e "$INFO-----> that you can also use to install boot2docker and brew if it isnt already installed."
        exit 1
    fi
    # If 'upgrade' was passed as a parameter it will refresh everything.
    # Existing binaries will be deleted and replaced.
    if [ $1 == 'upgrade' ]; then
        echo -e "${WARN} Checking for boot2docker upgrades and refreshing all docker binaries."
        echo -e "${WARN} You have 10 seconds to hit ctrl ^c to exit before existing binaries are removed"
        sleep 10
        $SUDO boot2docker upgrade --iso-url=${BOOT2DOCKER_RC}
        $SUDO rm -f /usr/local/bin/docker 2> /dev/null
        $SUDO rm -f /usr/local/bin/docker-compose 2> /dev/null
        $SUDO rm -f /usr/local/bin/docker-machine 2> /dev/null
        echo -e "${INFO} Installing:"
        echo -e "${INFO}"${XPLAT_DCOMPOSE}
        echo -e "${INFO}"${LINUX_DMACHINE}
        echo -e "${INFO}"${DARWIN_DOCKER}
    fi
    echo -e "Boot2docker is installed, now checking docker binaries"
    if ! [ -x "$(command -v docker)" ]; then
        echo -e "$INFO-----> Downloading Docker Binary CLI"
        installDockerBinMac
    fi
    if ! [ -x "$(command -v docker-machine)" ]; then
        echo -e "$INFO-----> Downloading Docker Machine CLI..."
        installMachineMac
    fi
    if ! [ -x "$(command -v docker-compose)" ]; then
        echo -e "$INFO-----> Downloading Docker Compose..."
        installCompose
    fi
elif [ "$UNAME" = "Linux" ]; then
    if [ $1 == 'upgrade' ]; then
        echo -e "${WARN} Refreshing all docker binaries with the following versions:"
        echo -e "${INFO}"${XPLAT_DCOMPOSE}
        echo -e "${INFO}"${LINUX_DMACHINE}
        echo -e "${INFO}"${DARWIN_DOCKER}
        echo -e "${WARN} You have 10 seconds to hit ctrl ^c to exit before existing binaries are removed"
        sleep 10
        $SUDO rm -f /usr/local/bin/docker 2> /dev/null
        $SUDO rm -f /usr/local/bin/docker-compose 2> /dev/null
        $SUDO rm -f /usr/local/bin/docker-machine 2> /dev/null
    fi
    # Linux platform
    echo -e "$WARN----> Linux detected, checking dependencies"
    if ! [ -x "$(command -v wget)" ]; then
        echo -e "$INFO-----> Install the dependency wget..."
        linuxDeps
    fi
    echo -e "-----> Dependencies meet, now pulling Linux binaries"
    if ! [ -x "$(command -v docker)" ]; then
        echo -e "$WARN-----> Docker binary was not found, installing docker binary now..."
        installDockerBinLinux
    fi
    if ! [ -x "$(command -v docker-machine)" ]; then
        echo -e "$INFO-----> Downloading Docker Machine CLI..."
        installMachineLinux
    fi
    if ! [ -x "$(command -v docker-compose)" ]; then
        echo -e "$INFO-----> Downloading Docker Compose..."
        installCompose
    fi
else
  echo -e "$ERROR-----> Unsupported OS:[ $UNAME ] this script only supports ubuntu, debian or OS X"
  exit 1
fi

echo -e "Verify you see a version for each binary below (docker, machine, compose)"
echo -e "Compose and Machine are development HEAD builds with latest patches/features"
if ! [ -x "$(command -v docker)" ]; then
    echo -e "$ERROR-----> Failed to install docker, please see https://docs.docker.com/installation/"
else
    echo -e "$INFO Installed Docker version -----> " $(docker -v)
fi
if ! [ -x "$(command -v docker-compose)" ]; then
    echo -e "$ERROR -----> Failed to install docker compose, please see https://docs.docker.com/compose/install/"
else
    echo -e "$INFO Installed Docker Machine version -----> " $(docker-compose --version)
fi
if ! [ -x "$(command -v docker-machine)" ]; then
    echo -e "$ERROR-----> Failed to install docker machine, https://docs.docker.com/machine/"
else
    echo -e "$INFO Installed Docker Compose version -----> " $(docker-machine --version)
fi


