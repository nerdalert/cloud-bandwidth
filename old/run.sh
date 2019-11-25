#!/bin/bash

RED='\033[01;31m'
RESET='\033[00m'
GREEN='\033[01;32m'
YELLOW='\033[01;33m'
PURPLE='\033[01;35m'
CYAN='\033[01;96m'
WHITE='\033[01;37m'
BLUE='\033[01;94m'
BOLD='\033[1m'
INFO='\033[01;94m[INFO] '${RESET}
WARN='\033[01;33m[WARN] '${RESET}
ERROR='\033[01;31m[ERROR] '${RESET}

#export POLLER_IMAGE_NAME="${POLLER_IMAGE_NAME:-bandwidth_poller}"
export POLLER_IMAGE_NAME="${POLLER_IMAGE_NAME:-networkstatic/bandwidth-poller}"
export POLLER_NAME="${POLLER_NAME:-bandwidth_poller}"
export CARBON_COLLECTOR_NAME="${CARBON_COLLECTOR_NAME:-cloudbandwidth_carbon_1}"
export BW_AGENT_IMAGE="${BW_AGENT_IMAGE:-networkstatic/iperf3}"
export BW_AGENT_NAME="${BW_AGENT_NAME:-bandwidth_agent}"
export BW_AGENT_IP="${BW_AGENT_IP:-UNDEFINED}"
export BW_AGENT_PORT="${BW_AGENT_PORT:-5201}"
# This is to reduce bandwidth but also accuracy of bandwidth tests.
# Increase for longer measurement times and thus better accuracy.
# The default in Iperf3 is 10 poll/seconds
export IPERF_SAMPLE_COUNT="${IPERF_SAMPLE_COUNT:-3}"
# if the poller is on another machine, set this variable with the name of it.
export CARBON_COLLECTOR_MACHINE="${CARBON_COLLECTOR_MACHINE:-}"


usage="${YELLOW}usage: $0 [-s (interval seconds)] [-p (machine that poller runs on)] [-t (list of target servers)]${RESET}\n\
        ${BLUE}[-s --seconds (seconds between bandwidth tests)] \n\
        [-p -poller_machine (a single machine name for where the poller container will run)]\n\
        [-t -target_machine (list of docker-machine names to run bandwidth tests against)]${RESET}\n\
        ${BLUE}+----------------------------------------------------------------------------------------+${RESET}\n\
        The naming of the machine need to be passed exactly as defined. There is one poller which\n\
        runs and connects to remote iperf containers that are listening for polling connections.\n\
        Once the poller has connected to all of the remote iperf agent, it then writes the results to the\n\
        carbon collector container and  exits. After the specified time (-s argument) expires, it again\n\
        a new client container is started and begins the process of connecting to servers and writing results.\n\
        Example - Run bandwidth tests every 5 minutes against the three docker machines lised:\n\
        ${BLUE}+----------------------------------------------------------------------------------------------------------------+\n\
        ${YELLOW} $0 -s 300 -p virtualbox-machine -t digitalocean-machine rackspace-machine virtualbox-machine ${RESET}\n\
        ${BLUE}+----------------------------------------------------------------------------------------------------------------+${RESET}\n\
        ${YELLOW}+-Troublshooting-+${RESET}\n\
        ${WARN}1. Make sure docker-compose up is running. check docker ps ${RESET}\n\
        ${WARN}2. Ensure this returns an IP 'docker inspect --format \"{{ .NetworkSettings.IPAddress }}\"  cloudbandwidth_carbon_1 ${RESET}\n\
        ${WARN}3. Check that the poller image is built in the bandwidth_poller directory. 'docker build  -t bandwidth_poller .' ${RESET}\n\
        ${WARN}4. Make sure the image networkstatic/iperf3 is downloaded as it should have by run.sh. ${RESET}\n\
        ${WARN}5. Use [ telnet <IP_ADDRESS> <PORT> ] to verify connectivity of machines and containers. ${RESET}\n\
        ${WARN}6. Or, use netcat to check the agent port isnt being filtered by the provider with:[ nc -v -z -w 1 <IP> <PORT> ]  ${RESET}\n\
        "

while getopts s:h:t:p: options; do
    case ${options} in
        s) seconds=$OPTARG ;;
        p) poller_machine=$OPTARG ; shift 1;;
        t) target_machines=$@;;
        h) echo -e ${usage};;
        *) echo -e ${usage}
            exit 1;;
    esac
done

checkPollerImg(){
    # one-time test to verify docker.sock is g2g
    VERIFY_DOCKER_CMD=$(docker ps)
    CMD_RESULT=$?
    if [ $CMD_RESULT -ne 0 ]; then
      echo -e "${ERROR}Is docker running? If so check that you have your eval command in place "
      echo -e "${ERROR}For Example: ${YELLOW}eval \"\$(docker-machine env virtualbox-machine)\"${RESET}"
    exit 1
    fi
	imageExists=$(docker images | grep ${POLLER_IMAGE_NAME}) > /dev/null 2>&1
	if [[ ${imageExists} == "" ]]; then
	    # Temp build hackery until pushed to dockerhub
	    echo -e "${INFO}The polling container image was not found cached on the poller machine [ ${poller_machine} ]"
	    echo -e "${INFO}pulling the docker image [ ${GREEN}networkstatic/bandwidth-poller${RESET} ] from Docker Hub. Depending on your bandwidth it may take a few minutes."
		echo -e "${INFO}If you want to modify the image, do so and then build with [${GREEN} cd ./bandwidth_poller && docker build -t bandwidth_poller . ${RESET}] That will cache the knew build on your docker machine."

	       docker pull networkstatic/bandwidth-poller
#        cd ${POLLER_NAME} \
#          && docker build -q -t ${POLLER_IMAGE_NAME} . \
#          && cd ..
	fi
}

# destory the client to ensure there is no system float
rmPoller(){
	existingClient=$(docker ps -a | grep ${POLLER_IMAGE_NAME}) &>/dev/null
	if [[ ${existingClient} != "" ]]; then
	    docker stop ${POLLER_NAME} &>/dev/null &
	    docker rm ${POLLER_NAME} &>/dev/null &
	fi
}

# destory the agent if done exists to ensure there is no system float
rmAgent(){
	existingClient=$(docker ps -a | grep ${BW_AGENT_NAME}) 2>/dev/null
	if [[ ${existingClient} != "" ]]; then
	    echo -e "${INFO}Discarding the old agent container named:[ ${BW_AGENT_NAME} ]"
	    docker stop ${BW_AGENT_NAME}  &>/dev/null
	    docker rm ${BW_AGENT_NAME}  &>/dev/null
	    sleep 1
	fi
}

runPoller(){
    echo -e "${INFO}Running the polling container named:[ ${POLLER_NAME} ] on machine:[ ${poller_machine} ] against the agent machine on:[ ${target_machine} ]"
    # Ensure previous operations are cleaned up

#	if [ -z ${POLLER_NAME} ]; then
	if [ ${POLLER_NAME} != "native" ]; then
	    eval "$(docker-machine env ${poller_machine})"
    else
        unsetEnv
    fi
    envs=$(env | grep DOCKER)
    echo -e "${INFO}Docker ENVs are:" ${envs}
    echo -e "${INFO}Deleting and re-creating the poller container named:[ ${POLLER_NAME} ] with the image: [ ${POLLER_IMAGE_NAME} ]"
    rmPoller
	#######################################################
	# Note --env=DB_IP variable is if then graphite API is
	# running on the SAME host as the iperf3 client which
	# is then process that connects to each of then remote
	# listeners to test bandwidth between.
	######################################################
	# If then carbon/graphite service is running on a
	# DIFFERENT machine then then client then you want
	# to use use 'docker-machine ip <machine-name>'
	# to get then IP address of the bandwidth perf results.
	# --env=DB_IP=$(docker-machine ip <MACHINE_NAME>)
	######################################################
	# Some Examples being:
	# --env=DB_IP=$(docker-machine ip virtualbox-machine)
	# --env=DB_IP=$(docker-machine ip google-machine)
	# --env=DB_IP=$(docker-machine ip azure-machine)
	######################################################
	# You can uncomment the following if carbon is on a
	# seperate machine. There is also a reahability test
	# that checks the IP:PORT is reachable each time the
	# $POLLER_IMAGE_NAME container runs. That enables the
	#  client to reach then exposed port rather then
	#  the local docker host non-NAT/PAT port of service.
	######################################################
		# If the Carbon container isnt on the same host as the poller (run.sh), use the following line to define $DB_IP
    # export DB_IP=$(docker-machine ip virtualbox-machine)

    dbExists=$(docker ps | grep ${CARBON_COLLECTOR_NAME}) > /dev/null 2>&1
	if [[ ${dbExists} != "" ]]; then
	    # Temp build hackery until pushed to dockerhub
	    export DB_IP=$(docker inspect --format "{{ .NetworkSettings.IPAddress }}" ${CARBON_COLLECTOR_NAME})
    elif [ -z ${CARBON_COLLECTOR_MACHINE} ]; then
        echo -e "$INFO Setting the DB IP address to the user specified machine named ${CARBON_COLLECTOR_MACHINE}"
	    export DB_IP=$(docker-machine ip ${CARBON_COLLECTOR_MACHINE})
	else
	    echo -e "${ERROR}No container named ${CARBON_COLLECTOR_NAME} was found running."
        echo -e "${ERROR}The time series database address [ DB_IP ] env not found. Is [ docker-compose up ] running?"
        echo -e "${ERROR}Run [ docker ps ] to verify. If it is not running then try:"
        echo -e "${ERROR}${GREEN} [ docker-compose stop && docker-compose rm -f  && docker-compose up ] ${RESET} \
            to recreate the stack form the [ cloud_bandwidth ] directory (TSDB data is preserved)."
	    exit 1
	fi

    if [ -z "${DB_IP}" ]; then
        echo -e ${usage}
        echo -e "${ERROR}The time series database address [ DB_IP ] env not found. Is the service running? Run [ docker ps ] to check"
        echo -e "${ERROR}cloudbandwidth_carbon_1 not found, ensure graphite is running with [ docker-compose up ]"
        exit 1
    fi

    if [[ ${target_machine} = *"virtualbox"* || ${target_machine} = *"fusion"*  ]]; then
        BW_AGENT_IP=$(docker inspect --format "{{ .NetworkSettings.IPAddress }}" ${BW_AGENT_NAME})
        echo -e "${INFO}The target agent appears local and uses an IP of - BW_AGENT_IP:[ ${BW_AGENT_IP} ]";
    else
        BW_AGENT_IP=$(docker-machine ip ${target_machine})
        echo -e "${INFO}The target bandwidth agent appears remote with an IP of - BW_AGENT_IP:[ ${BW_AGENT_IP} ]";
    fi


    MACH_TYPE=$(echo -e ${target_machine} | awk -F '-' '{print $1}')
    echo -e "${WARN}${GREEN}Starting the poller container the following parameters:${RESET}"
    echo -e "${WARN} -- container name:[${GREEN} ${POLLER_NAME} ${RESET}]"
    echo -e "${WARN} -- carbon ip:[${GREEN} ${DB_IP} ${RESET}]"
    echo -e "${WARN} -- target machine type:[${GREEN} ${MACH_TYPE} ${RESET}]"
    echo -e "${WARN} -- bandwidth target agent IP:[${GREEN} ${BW_AGENT_IP} ${RESET}]"
    echo -e "${WARN} -- sample count:[${GREEN} ${IPERF_SAMPLE_COUNT} ${RESET}]"
    echo -e "${WARN} -- image name:[${GREEN} ${POLLER_IMAGE_NAME} ${RESET}]"
    # start the poller
    docker run -i --rm \
        --name=${POLLER_NAME} \
        --env=DB_IP=${DB_IP} \
        --env=BW_AGENT_IP=${BW_AGENT_IP} \
        --env=MACHINE_TYPE=${MACH_TYPE} \
        --env=IPERF_SAMPLE_COUNT=${IPERF_SAMPLE_COUNT} \
        ${POLLER_IMAGE_NAME}
    echo -e ${INFO}"Measuring the bi-directional bandwidth between machines:"
    echo -e ${INFO}"${GREEN}[ (source poller) $poller_machine ] ${YELLOW}<============>${GREEN} [ $target_machine (target agent) ]${RESET}"
#    CMD_RESULT=$?
#    if [ $CMD_RESULT -ne 0 ]; then
#      echo -e "${ERROR}Does the target server specified exist? or is it stopped?"
#    exit 1
#    fi
    sleep 1
    rmPoller
}



# Run the remote agent that listens for then poller to attach
runAgent(){
	eval "$(docker-machine env ${target_machine})"
    rmAgent
    # Block until the server starts, if it is the first time and needs to pull then agent image
    docker run -d --name=${BW_AGENT_NAME} \
        -p ${BW_AGENT_PORT}:${BW_AGENT_PORT} \
        ${BW_AGENT_IMAGE} -s 2>/dev/null

    sleep 3
    echo -e "${INFO}Machine started"
    # Unset then docker-machine env explicitly
	unsetEnv
}

# Unset the current ENV variables to nil
unsetEnv(){
	eval "$(docker-machine env -u)"
}

dm(){
	docker-machine $@
}

if [  $# -eq 0 ]; then
    echo -e ${usage}
    echo -e "${ERROR}No machine names were passed in the machines argument"
    exit 1
fi

time=$(($seconds))
if [ ${time} -lt 2 ]; then
    echo -e ${usage}
	exit 1
fi

# Verify the poller image exist on the polling host
checkPollerImg
#sleep $time
while [ 0 -eq 0 ]; do
    echo -e "${INFO}Interval timer between bandwidth tests is set for: ${time} seconds"
    echo -e "${YELLOW}To stop this process use ctrl^c ${RESET}"
    shift $((OPTIND-1))
    for target_machine in $@; do
        runAgent
	    runPoller
    done
	sleep ${time}
done

exit 0