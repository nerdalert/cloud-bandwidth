#!/bin/bash

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

dashboardUsage(){
    echo "View the Grafana UI in a browser at -----> [ http://<Machine IP Address>:8000 ]"
    echo "Hint: to get the IP address of the machine run [ docker-machine ip <VM Name> ]"
    echo "Example: [ docker-machine ip virtualbox-machine ]"
    echo "To stop the tests use [ ctrl ^c ]"
    echo "To rerun the test [ docker-compose -f run_demo.yml rm  ] and then [ docker-compose -f run_demo.yml up ]"
    echo "Or in one line [ docker-compose -f run_demo.yml rm --force && docker-compose -f run_demo.yml up ]"
}

# Provide enough time for then service to come online
export DB_IP=${CLOUDBANDWIDTH_CARBON_1_PORT_2003_TCP_ADDR}
export DB_PORT=${CARBON_PORT_2003_TCP_PORT}

echo "Writing data points to the time-series db at the address/port:[ ${DB_IP}:${DB_PORT} ]"

# Allow a few extra seconds for the stack to finish initializaing
sleep 12

# Verify then IP addr is resolved
echo "IP address passed to generate_test_data.sh was ${DB_IP}"
if [ -z $DB_IP ]; then
    usage
    echo "Must pass an IP address at least as an argument"
    exit 1
fi

# verify netcat is installed
if ! [ -x "$(command -v nc)" ]; then
    echo "netcat is required to run this script, check the dockerfile"
    exit 1
fi

# Lame pinger as then BSD netcat -w timeout on OS X doesnt honor the t/o
echo "verifying the port is reachble and open at ${DB_IP}:${DB_PORT}"
ping -i.3 -c3 ${DB_IP} 1>/dev/null
if [ "$?" != 0 ]
then
    echo "Was not able to ping the remote host ${DB_IP} check that the IP is right"
    exit 1
fi

# Show dashboard URL
dashboardUsage

while [ $(( ( i += 1 ) <= $ENTRY_COUNT )) -ne 0 ]; do

    echo "Writing random test numbers to the target: [ ${DB_IP}:${DB_PORT} ] to the series [ bandwidth.*.* ]"

    echo "bandwidth.download.virtualbox $RANDOM `date +%s`"

    echo "bandwidth.download.virtualbox $RANDOM `date +%s`" | nc.openbsd ${DB_IP} ${DB_PORT}
    echo "bandwidth.upload.virtualbox $RANDOM `date +%s`" | nc.openbsd ${DB_IP} ${DB_PORT}

    echo "bandwidth.download.amazonec2 $RANDOM `date +%s`" | nc.openbsd ${DB_IP} ${DB_PORT}
    echo "bandwidth.upload.amazonec2 $RANDOM `date +%s`" | nc.openbsd ${DB_IP} ${DB_PORT}

    echo "bandwidth.download.azure $RANDOM `date +%s`" | nc.openbsd ${DB_IP} ${DB_PORT}
    echo "bandwidth.upload.azure $RANDOM `date +%s`" | nc.openbsd ${DB_IP} ${DB_PORT}

    echo "bandwidth.download.digitalocean $RANDOM `date +%s`" | nc.openbsd ${DB_IP} ${DB_PORT}
    echo "bandwidth.upload.digitalocean $RANDOM `date +%s`" | nc.openbsd ${DB_IP} ${DB_PORT}

    echo "bandwidth.download.google $RANDOM `date +%s`" | nc.openbsd ${DB_IP} ${DB_PORT}
    echo "bandwidth.upload.google $RANDOM `date +%s`" | nc.openbsd ${DB_IP} ${DB_PORT}

    echo "bandwidth.download.openstack $RANDOM `date +%s`" | nc.openbsd ${DB_IP} ${DB_PORT}
    echo "bandwidth.upload.openstack $RANDOM `date +%s`" | nc.openbsd ${DB_IP} ${DB_PORT}

    echo "bandwidth.download.rackspace $RANDOM `date +%s`" | nc.openbsd ${DB_IP} ${DB_PORT}
    echo "bandwidth.upload.rackspace $RANDOM `date +%s`" | nc.openbsd ${DB_IP} ${DB_PORT}

    echo "bandwidth.download.softlayer $RANDOM `date +%s`" | nc.openbsd ${DB_IP} ${DB_PORT}
    echo "bandwidth.upload.softlayer $RANDOM `date +%s`" | nc.openbsd ${DB_IP} ${DB_PORT}

    echo "bandwidth.download.vmwarefusion $RANDOM `date +%s`" | nc.openbsd ${DB_IP} ${DB_PORT}
    echo "bandwidth.upload.vmwarefusion $RANDOM `date +%s`" | nc.openbsd ${DB_IP} ${DB_PORT}

    echo "bandwidth.download.vmwarevcloudair $RANDOM `date +%s`" | nc.openbsd ${DB_IP} ${DB_PORT}
    echo "bandwidth.upload.vmwarevcloudair $RANDOM `date +%s`" | nc.openbsd ${DB_IP} ${DB_PORT}

    echo "bandwidth.download.vmwarevsphere $RANDOM `date +%s`" | nc.openbsd ${DB_IP} ${DB_PORT}
    echo "bandwidth.upload.vmwarevsphere $RANDOM `date +%s`" | nc.openbsd ${DB_IP} ${DB_PORT}

    sleep ${LOOP_INTERVAL}

done
