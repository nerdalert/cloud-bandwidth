#!/bin/sh

# Note: if you remove then -t (--time) flag, then you want to change then awk 'print $8' to 'print $7'
# E.g. sudo /usr/bin/iperf -P 1 -t 5 -f bits -c ${BW_AGENT_IP} | tail -n 1 | awk '{print $7}'
# If no ENV variables are passed at runtime (docker run) then the default comand is:
# /usr/bin/iperf -s -P 1 -t 0
# -P (n) number of threads. I pass 1 to force an exit after the client test ends

DB_PORT=$DB_PORT
IPERF_SAMPLE_COUNT=$IPERF_SAMPLE_COUNT
BW_AGENT_PORT="${BW_AGENT_PORT:-5201}"

# Term colors for funzies
RESET='\033[00m'
INFO='\033[01;94m[INFO]: '${RESET}
WARN='\033[01;33m[WARN]: '${RESET}
ERROR='\033[01;31m[ERROR]: '${RESET}

# Measure the download bandwidth from server to client
# Setting then default time measurement to 5 seconds to
# avoid accessive bandwidth usage for those paying per gig.
# Override time at runtime by passing --env=IPERF_SAMPLE_COUNT=<seconds>
runIperfIngress(){
    BW_RESULT=$(/usr/bin/iperf3 -P 1 -R -t ${IPERF_SAMPLE_COUNT} -f bits -c ${BW_AGENT_IP} | tail -n 3 | head -n1 | awk '{print $7}')
    CMD_RESULT=$?
    if [ $CMD_RESULT -eq 0 ]; then
      echo "${INFO}Successfully connected to the remote iperf3 server container [ ${BW_AGENT_IP} ]"
      writeStatIngress
    else
        echo "${ERROR}Was unable to connect to the remote iperf server [ ${BW_AGENT_IP} ], is the container running? Use 'docker ps'"
      exit 1
    fi
}

# Measure the upload bandwidth from server to client
# Setting then default time measurement to 5 seconds to
# avoid accessive bandwidth usage for those paying per gig.
# Override time at runtime by passing --env=IPERF_SAMPLE_COUNT=<seconds>
runIperfEgress(){
    BW_RESULT=$(/usr/bin/iperf3 -t ${IPERF_SAMPLE_COUNT} -f bits -c ${BW_AGENT_IP} | tail -n 3 | head -n1 | awk '{print $7}')
    writeStatEgress
}

writeStatIngress() {
    if [ -z ${BW_RESULT} ]; then
    echo "${ERROR}there was a problem connecting to the iperf server"
    exit 1
    fi
    echo "${INFO}Writing driver type: [ ${MACHINE_TYPE} with a download speed: [ ${BW_RESULT}b/ps ] to the DB at: [ ${DB_IP} ]"
    # Write to Graphite using then plain text API
    echo "bandwidth.download.${MACHINE_TYPE} $BW_RESULT `date +%s`" |  nc ${DB_IP} ${DB_PORT} &
    echo "${INFO}Ingress Write Complete"
    sleep 1
}

writeStatEgress() {
    if [ -z ${BW_RESULT} ]; then
    echo "${ERROR}there was a problem connecting to the iperf server"
    exit 1
    fi
    echo "${INFO}Writing driver type: [ ${MACHINE_TYPE} with an upload speed: [ ${BW_RESULT}b/ps ] to the DB at: [ ${DB_IP} ]"
   # Write to Graphite using then plain text API
    echo "bandwidth.upload.${MACHINE_TYPE} $BW_RESULT `date +%s`" | nc ${DB_IP} ${DB_PORT} &
    echo "${INFO}Egress BW Write Complete"
    sleep 1
}

checkAgent() {
    # verify you can reach then port running graphite
    if nc -v -z -w 2 ${BW_AGENT_IP} ${BW_AGENT_PORT} 2>/dev/null 1>/dev/null; then
        echo "${INFO}Connection to ${BW_AGENT_IP}:${BW_AGENT_PORT} was successful, now running bandwidth tests"
    else
        echo "${ERROR}Connection to ${BW_AGENT_IP}:${BW_AGENT_PORT} failed; verify the service/container \
        is running and the port is not blocked by a firewall."
        echo "${ERROR}Test with [ nc -v -z -w 2 ${BW_AGENT_IP} ${BW_AGENT_PORT} ] OR [ telnet ${BW_AGENT_IP} ${BW_AGENT_PORT} ]"
        exit 1
    fi
}

# Script Begins Here

echo "${INFO}Testing bandwidth to an iperf3 service at the IP:[ ${BW_AGENT_IP} ] and machine driver type:[ ${MACHINE_TYPE} ]"

if [ -z ${DB_IP} ]; then
    echo "Data storage server DB_IP is undefined. Is the docker-compose stack running with Graphite and Grafana "
    exit 1
fi

# Lame service check pinger
ping -i.5 -c3 ${DB_IP} 2>/dev/null 1>/dev/null
if [ "$?" != 0 ]
then
    echo "Was not able to ping the remote host ${DB_IP} check that the IP is right"
    exit 1
fi

# verify netcat is installed
if ! [ -x "$(command -v nc)" ]; then
    echo "-----> netcat was not found and required to test DB up status"
    exit 1
fi

if [ -z "${BW_AGENT_IP}" ]; then
	echo >&2 'error: missing required BW_AGENT_IP environment variable'
	echo >&2 '  Did you forget to pass -e BW_AGENT_IP=<Iperf Server IP Address>'
	echo >&2
	echo >&2 ${ERROR}' Example usage:
    docker run -i --rm \
        --name=${POLLER_IMAGE_NAME} \
        --env=DB_IP=${DB_IP} \
        --env=BW_AGENT_IP=${BW_AGENT_IP} \
        --env=MACHINE_TYPE=${MACH_TYPE} \
        --env=IPERF_SAMPLE_COUNT=${IPERF_SAMPLE_COUNT} \
        ${POLLER_IMAGE_NAME}'
	exit 1
fi

echo "${WARN}Starting the poller with the following parameters (these should align with the logs above ^):"
echo "${WARN}  agent machine type:[ ${MACHINE_TYPE} ]"
echo "${WARN}  carbon ip:[ ${DB_IP} ]"
echo "${WARN}  docker machine type:[ ${MACHINE_TYPE} ]"
echo "${WARN}  bandwidth target agent IP:[ ${BW_AGENT_IP} ]"
echo "${WARN}  sample count:[ ${IPERF_SAMPLE_COUNT} ]"
echo "${INFO}Verifying the target agent ip:port are reachable at:[ ${BW_AGENT_IP}:${BW_AGENT_PORT} ] "
checkAgent

case  ${MACHINE_TYPE}  in
    amazonec2)
        echo "${INFO}Driver type is: amazonec2"
        runIperfIngress
        runIperfEgress
        ;;
    azure)
        echo "${INFO}Driver type is: azure"
        runIperfIngress
        runIperfEgress
        ;;
    digitalocean)
        echo "${INFO}Driver type is: digitalocean"
        runIperfIngress
        runIperfEgress
        sleep 1
        exit 1
        ;;
    google)
        echo "${INFO}Driver type is: google"
        runIperfIngress
        runIperfEgress
        ;;
    openstack)
        echo "${INFO}Driver type is: openstack"
        runIperfIngress
        runIperfEgress
        ;;
    rackspace)
        echo "${INFO}Driver type is: rackspace"
        runIperfIngress
        runIperfEgress
        ;;
    softlayer)
        echo "${INFO}Driver type is: softlayer"
        runIperfIngress
        runIperfEgress
        ;;
    virtualbox)
        echo "${INFO}Driver type is: virtualbox"
        runIperfIngress
        runIperfEgress
        ;;
    vmwarefusion)
        echo "${INFO}Driver type is: vmwarefusion"
        runIperfIngress
        runIperfEgress
        ;;
    vmwarevcloudair)
        echo "${INFO}Driver type is: vmwarevcloudair"
        runIperfIngress
        runIperfEgress
        ;;
    vmwarevsphere)
        echo "${INFO}Driver type is: vmwarevsphere"
        runIperfIngress
        runIperfEgress
        ;;
    *)
    echo >&2 'error: missing required BW_AGENT_IP environment variable'
	echo >&2 '  Did you forget to pass -e BW_AGENT_IP=<Iperf Server IP Address>'
	echo >&2
	echo >&2 ' Example usage:
    docker run -i --rm \
        --name=net_poller \
        --env=DB_IP=$(docker inspect --format "{{ .NetworkSettings.IPAddress }}" cloudbandwidth_carbon_1) \
        --env=BW_AGENT_IP=$(docker-machine ip digitalocean-machine) \
        --env=MACHINE_TYPE=digitalocean \
        --env=IPERF_SAMPLE_COUNT=4 \
        net_poller'
    exit 0
esac

exit 0

