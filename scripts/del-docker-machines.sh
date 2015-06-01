#!/bin/bash

usage() {
cat <<EOF

Usage: $0 [OPTION]...
Configuration:
  -h, --help              display this help and exit
  -d, driver, --driver            docker-machine driver type to delete

All three examples do the same function, deletes any machines matching the driver type:
Example: ./del-machines.sh -d digitalocean
Example: ./del-machines.sh driver digitalocean
Example: ./del-machines.sh --driver digitalocean

Driver types are as follows:
    amazonec2
    azure
    digitalocean
    google
    openstack
    rackspace
    softlayer
    virtualbox
    vmwarefusion
    vmwarevcloudair
    vmwarevsphere

More about docker-machine at: https://docs.docker.com/machine/
EOF
}

delMachines() {
    echo "Deleting all machines with a driver:[ $driver ]"
    for machines in "$(sudo docker-machine ls 2>&1 | grep ${driver} | awk '{print $1}')"; do
        for m in $machines; do
          echo "docker-machine rm -f $m"
            docker-machine rm -f $m
        done
    done
}

validate() {
case "$driver" in
    softlayer | amazonec2 | azure | digitalocean | google |\
    openstack | rackspace | softlayer | virtualbox |\
    vmwarefusion | vmwarevcloudair | vmwarevsphere )
    delMachines ;;
    *)
    usage
	echo "Error: unkown driver type: [ $driver ]"
	exit 1 ;;
    esac
}

tester(){
    echo $driver
}

for optname do
case "$optname" in
    -d|driver|--driver)
         shift;
        driver=$1
        echo "meh" $driver
        tester
        validate
        exit
        ;;
    -h|--help)
        usage
        exit 0
        ;;
	esac
done

if [[ -z "$1" ]]; then
	usage
	exit 1
fi

exit 0