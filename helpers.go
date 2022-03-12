package main

import (
	"fmt"
	"math"
	"net"
	"strconv"
	"strings"
)

// validateIP ensures a valid IP4/IP6 address is provided.
func validateIP(ip string) error {
	if ip := net.ParseIP(ip); ip != nil {
		return nil
	}
	return fmt.Errorf("%s is not a valid v4 or v6 IP", ip)
}

func splitPerfPair(tunnelDestInput string) []string {
	return strings.Split(tunnelDestInput, ":")
}

// convertKbitsToBits iperf3 no longer supports bps, so convert Kbps to bps for tsdb plotting.
func convertKbitsToBits(kbps string) (int, error) {
	// round the number to remove any decimals.
	float, err := strconv.ParseFloat(kbps, 32)
	if err != nil {
		return 0, err
	}
	kbpsInt := int(math.Round(float))
	bps := kbpsInt * 1000

	return bps, nil
}

// printPerfServers concatenate the perf server pairs to make readable for a debug print.
func printPerfServers(perfServers []servers) {
	var endpointList []string

	for _, serverPair := range perfServers {
		for k, v := range serverPair {
			endPointAddressPair := fmt.Sprintf("%s:%s", k, v)
			endpointList = append(endpointList, endPointAddressPair)
			log.Debugf("[Config] Perf Server = %s", endPointAddressPair)
		}
	}
}
