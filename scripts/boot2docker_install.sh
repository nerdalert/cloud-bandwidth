#!/bin/bash

RESET='\033[00m'
INFO='\033[01;94mINFO: '${RESET}
WARN='\033[01;33mWARN: '${RESET}
ERROR='\033[01;31mERROR: '${RESET}

# Intall Brew
installBrew(){
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
}

# Install Boot2Docker via Brew
installBoot2Docker(){
    brew install boot2docker
    $(boot2docker shellinit)
    boot2docker init
    boot2docker up
}

# Exit if boot2docker already exists
if [ -x "$(command -v boot2docker)" ]; then
    echo -e  "$WARN -----> boot2docker is already installed. exiting.."
    exit 1
fi
echo -e  "$INFO boot2docker was not found, checking for brew next.."

# Exit if brew already exists
if [ -x "$(command -v brew)" ]; then
    echo -e  "$WARN -----> Brew not found, downloading and installing it now.."
    installBrew
fi

echo -e  "$INFO brew is installed, now installing boot2docker"
echo -e  "$WARN ** When prompted for a password by the installer for [ docker@localhost ] password is [ tcuser ] ** "

# Call the boot2docker install function
installBoot2Docker

# Check for any errors in then install
CMD_RESULT=$?
if [ $CMD_RESULT -ne 0 ]; then
  echo -e  "$ERROR There was a problem installing boot2docker via brew. "
  echo -e  "$ERROR Head to https://docs.docker.com/installation/mac/ and try installing via the installer"
exit 1
fi

echo -e  "$INFO Installation was successful! ----> boot2docker is now installed with version: " `boot2docker version`
