#!/bin/sh

##################################################
# Script to write test data to graphite for filling
# out sample time series databases for testing.
##################################################

usage() {
   echo "Usage: Examples (any of them work, see then variable definitions for then defaults):"
   echo "===================================================================================="
   echo "generate_test_grafana_data.sh [ DB_IP (required)]  [ DB_PORT (optiona)]  [ NUMBER_OF_LOOPS (optiona)]  [ LOOP_INTERVAL (optiona)]"
   echo "===================================================================================="
   echo "generate_test_grafana_data.sh 192.168.99.100 (required argument: <target IP>)"
   echo "generate_test_grafana_data.sh  192.168.99.100 2003 (optional args)"
   echo "generate_test_grafana_data.sh  192.168.99.100 2003 10 (optional args)"
   echo "generate_test_grafana_data.sh  192.168.99.100 2003 10 15 (optional args)"
}

arg="$1"
if [[ $arg = "-h" || $arg = "--help" || $arg = "help" || $arg = "?" ]]
then
    usage
    exit
fi

DB_IP=${1:-}
DB_PORT=${2:-2003}
NUMBER_OF_LOOPS=${3:-40}
LOOP_INTERVAL=${4:-60}
CONNECTION_TIMEOUT=1


if [ -z $DB_IP ]; then
    usage
    echo "Must pass an IP address at least as an argument"
    exit 1
fi

# verify netcat is installed
if ! [ -x "$(command -v nc)" ]; then
    echo "-----> netcat is required to run this script"
    exit 1
fi

# Lame pinger as then BSD netcat -w timeout on OS X doesnt honor the t/o
echo "verifying the port is reachble and open at ${DB_IP}:${DB_PORT}"
ping -t1 -c1 ${DB_IP} 2>/dev/null 1>/dev/null
if [ "$?" != 0 ]
then
    echo "Was not able to ping the remote host ${DB_IP} check that the IP is right"
    exit 1
fi

# verify you can reach then port running graphite
if nc -v -z -w 1 ${DB_IP} ${DB_PORT} 2>/dev/null 1>/dev/null; then
    echo "Connection to ${DB_IP}:${DB_PORT} was successful, now writing series data"
else
    echo "Connection to ${DB_IP}:${DB_PORT} failed; verify the service/container is running"
    exit 1
fi

for (( i=1; i <= $NUMBER_OF_LOOPS; i++ ))
do
    echo "Writing random test numbers to the target: [ ${DB_IP}:${DB_PORT} ] to the series [ bandwidth.*.* ]"

    echo "bandwidth.download.virtualbox $RANDOM `date +%s`" | nc ${DB_IP} ${DB_PORT}
    echo "bandwidth.upload.virtualbox $RANDOM `date +%s`" | nc ${DB_IP} ${DB_PORT}

    echo "bandwidth.download.amazonec2 $RANDOM `date +%s`" | nc ${DB_IP} ${DB_PORT}
    echo "bandwidth.upload.amazonec2 $RANDOM `date +%s`" | nc ${DB_IP} ${DB_PORT}

    echo "bandwidth.download.azure $RANDOM `date +%s`" | nc ${DB_IP} ${DB_PORT}
    echo "bandwidth.upload.azure $RANDOM `date +%s`" | nc ${DB_IP} ${DB_PORT}

    echo "bandwidth.download.digitalocean $RANDOM `date +%s`" | nc ${DB_IP} ${DB_PORT}
    echo "bandwidth.upload.digitalocean $RANDOM `date +%s`" | nc ${DB_IP} ${DB_PORT}

    echo "bandwidth.download.google $RANDOM `date +%s`" | nc ${DB_IP} ${DB_PORT}
    echo "bandwidth.upload.google $RANDOM `date +%s`" | nc ${DB_IP} ${DB_PORT}

    echo "bandwidth.download.openstack $RANDOM `date +%s`" | nc ${DB_IP} ${DB_PORT}
    echo "bandwidth.upload.openstack $RANDOM `date +%s`" | nc ${DB_IP} ${DB_PORT}

    echo "bandwidth.download.rackspace $RANDOM `date +%s`" | nc ${DB_IP} ${DB_PORT}
    echo "bandwidth.upload.rackspace $RANDOM `date +%s`" | nc ${DB_IP} ${DB_PORT}

    echo "bandwidth.download.softlayer $RANDOM `date +%s`" | nc ${DB_IP} ${DB_PORT}
    echo "bandwidth.upload.softlayer $RANDOM `date +%s`" | nc ${DB_IP} ${DB_PORT}

    echo "bandwidth.download.vmwarefusion $RANDOM `date +%s`" | nc ${DB_IP} ${DB_PORT}
    echo "bandwidth.upload.vmwarefusion $RANDOM `date +%s`" | nc ${DB_IP} ${DB_PORT}

    echo "bandwidth.download.vmwarevcloudair $RANDOM `date +%s`" | nc ${DB_IP} ${DB_PORT}
    echo "bandwidth.upload.vmwarevcloudair $RANDOM `date +%s`" | nc ${DB_IP} ${DB_PORT}

    echo "bandwidth.download.vmwarevsphere $RANDOM `date +%s`" | nc ${DB_IP} ${DB_PORT}
    echo "bandwidth.upload.vmwarevsphere $RANDOM `date +%s`" | nc ${DB_IP} ${DB_PORT}

    sleep ${LOOP_INTERVAL}
done


