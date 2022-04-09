package main

import (
	"errors"
	"fmt"
	"io/ioutil"
	"net"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/sirupsen/logrus"
	"github.com/urfave/cli/v2"
	"gopkg.in/yaml.v2"
)

type configuration struct {
	TestLength       string    `yaml:"test-length"`
	TestInterval     string    `yaml:"test-interval"`
	ServerPort       string    `yaml:"server-port"`
	TsdbServer       string    `yaml:"grafana-address"`
	TsdbPort         string    `yaml:"grafana-port"`
	TsdbDownPrefix   string    `yaml:"tsdb-download-prefix"`
	TsdbUpPrefix     string    `yaml:"tsdb-upload-prefix"`
	PerfServers      []servers `yaml:"iperf-servers"`
	GraphiteHostPort string
}

type servers map[string]string

const (
	netperfTCP         = "TCP_STREAM"
	netperfUDP         = "UDP_STREAM"
	defaultNetperfRepo = "quay.io/networkstatic/netperf"
	defaultIperfRepo   = "quay.io/networkstatic/iperf3"
	defaultIperfPort   = "5201"
	defaultNetperfPort = "12865"
	defaultCarbonPort  = "2003"
)

var log = logrus.New()

var (
	cliFlags          flags
	configFilePresent = true
	iperfBinary       string
	netperfBinary     string
)

type flags struct {
	configPath     string
	imageRepo      string
	perfServers    string
	grafanaServer  string
	grafanaPort    string
	testInterval   string
	testLength     string
	perfServerPort string
	downloadPrefix string
	uploadPrefix   string
	netperf        bool
	noContainer    bool
	debug          bool
}

func main() {
	// instantiate the cli
	app := cli.NewApp()
	// flags are stored in the global flags variable
	app = &cli.App{
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:        "configuration",
				Value:       "configuration.yaml",
				Usage:       "Path to the configuration file - example: -configuration=path/configuration.yaml",
				Destination: &cliFlags.configPath,
				EnvVars:     []string{"CBANDWIDTH_CONFIG"},
			},
			&cli.StringFlag{
				Name:        "image",
				Value:       defaultIperfRepo,
				Usage:       "Custom repo to an Iperf3 image",
				Destination: &cliFlags.imageRepo,
				EnvVars:     []string{"CBANDWIDTH_PERF_IMAGE"},
			},
			&cli.StringFlag{
				Name:        "perf-servers",
				Value:       "",
				Usage:       "remote host and IP address of the perf server destination(s) seperated by a \":\" if multiple values, can be a host:ip pair or just an address ex. --remote-hosts=192.168.1.100,host2:172.16.100.20",
				Destination: &cliFlags.perfServers,
				EnvVars:     []string{"CBANDWIDTH_PERF_SERVERS"},
			},
			&cli.StringFlag{
				Name:        "grafana-address",
				Value:       "",
				Usage:       "address of the grafana/carbon server",
				Destination: &cliFlags.grafanaServer,
				EnvVars:     []string{"CBANDWIDTH_GRAFANA_ADDRESS"},
			},
			&cli.StringFlag{
				Name:        "grafana-port",
				Value:       defaultCarbonPort,
				Usage:       "address of the grafana/carbon port",
				Destination: &cliFlags.grafanaPort,
				EnvVars:     []string{"CBANDWIDTH_GRAFANA_PORT"},
			},
			&cli.StringFlag{
				Name:        "test-interval",
				Value:       "300",
				Usage:       "the time in seconds between performance polls",
				Destination: &cliFlags.testInterval,
				EnvVars:     []string{"CBANDWIDTH_POLL_INTERVAL"},
			},
			&cli.StringFlag{
				Name:        "test-length",
				Value:       "5",
				Usage:       "the length of time the perf test run for in seconds",
				Destination: &cliFlags.testLength,
				EnvVars:     []string{"CBANDWIDTH_POLL_LENGTH"},
			},
			&cli.StringFlag{
				Name:        "perf-server-port",
				Value:       defaultIperfPort,
				Usage:       "iperf server port",
				Destination: &cliFlags.perfServerPort,
				EnvVars:     []string{"CBANDWIDTH_PERF_SERVER_PORT"},
			},
			&cli.StringFlag{
				Name:        "tsdb-download-prefix",
				Value:       "bandwidth.download",
				Usage:       "the download prefix of the stored tsdb data in graphite",
				Destination: &cliFlags.downloadPrefix,
				EnvVars:     []string{"CBANDWIDTH_DOWNLOAD_PREFIX"},
			},
			&cli.StringFlag{
				Name:        "tsdb-upload-prefix",
				Value:       "bandwidth.upload",
				Usage:       "the upload prefix of the stored tsdb data in graphite, not applicable for netperf",
				Destination: &cliFlags.uploadPrefix,
				EnvVars:     []string{"CBANDWIDTH_UPLOAD_PREFIX"},
			},
			&cli.BoolFlag{
				Name:        "netperf",
				Value:       false,
				Usage:       "use netperf and netserver instead of iperf",
				Destination: &cliFlags.netperf,
				EnvVars:     []string{"CBANDWIDTH_NETPERF"},
			},
			&cli.BoolFlag{
				Name:        "nocontainer",
				Value:       false,
				Usage:       "Do not use docker or podman and run the iperf3 binary by the host - default is containerized",
				Destination: &cliFlags.noContainer,
				EnvVars:     []string{"CBANDWIDTH_NOCONTAINER"},
			},
			&cli.BoolFlag{
				Name:        "debug",
				Value:       false,
				Usage:       "Run in debug mode to display all shell commands being executed",
				Destination: &cliFlags.debug,
				EnvVars:     []string{"CBANDWIDTH_DEBUG"},
			},
		},
	}

	app.Name = "cloud-bandwidth"
	app.Usage = "measure endpoint bandwidth and record the results to a tsdb"
	app.Before = func(c *cli.Context) error {
		return nil
	}
	app.Action = func(c *cli.Context) error {
		// call the applications function
		runApp()
		return nil
	}
	app.Run(os.Args)
}

// runApp parses the configuration and runs the tests
func runApp() {
	logrus.SetLevel(logrus.DebugLevel)
	logrus.SetFormatter(&logrus.TextFormatter{})

	if cliFlags.debug {
		log.Level = logrus.DebugLevel
	}

	// read in the yaml configuration from configuration.yaml
	configFileData, err := ioutil.ReadFile(cliFlags.configPath)
	if err != nil {
		log.Info("no configuration file found, defaulting to command line arguments")
		configFilePresent = false
	}

	config := configuration{}
	// read in the configuration file if one exists
	if configFilePresent {
		if err := yaml.Unmarshal([]byte(configFileData), &config); err != nil {
			log.Fatal(err)
		}
	}

	// check the configuration file first for the configuration files values, fallback to the CLI values otherwise
	if configFilePresent {
		if cliFlags.grafanaServer != "" {
			config.GraphiteHostPort = net.JoinHostPort(cliFlags.grafanaServer, cliFlags.grafanaPort)
		} else {
			if configFilePresent {
				config.GraphiteHostPort = net.JoinHostPort(config.TsdbServer, config.TsdbPort)
			} else {
				log.Fatal("no grafana/carbon server and/or port were passed")
			}
		}
		if config.TestInterval != "" {
			cliFlags.testInterval = config.TestInterval
		}
		if config.TestLength != "" {
			cliFlags.testLength = config.TestLength
		}
		if config.TsdbUpPrefix != "" {
			cliFlags.uploadPrefix = config.TsdbUpPrefix
		}
		if config.TsdbDownPrefix != "" {
			cliFlags.downloadPrefix = config.TsdbDownPrefix
		}
	}

	// assign the grafana server from the CLI
	if config.GraphiteHostPort == "" {
		if cliFlags.grafanaServer == "" {
			log.Warn("No Grafana server was passed to the app, tests will still run, but will not be able to write to a grafana server")
		} else {
			config.GraphiteHostPort = net.JoinHostPort(cliFlags.grafanaServer, cliFlags.grafanaPort)
		}
	}

	// merge the CLI with the configuration files if both exist
	if cliFlags.perfServers != "" {
		tunnelDestList := strings.Split(cliFlags.perfServers, ",")
		for _, tunnelDest := range tunnelDestList {
			perfServerMap := mapPerfDest(tunnelDest)
			config.PerfServers = append(config.PerfServers, perfServerMap)
		}
	}
	// Log configuration parameters for debugging
	log.Debug("Configuration as follows:")
	log.Debugf("[Config] Grafana Server = %s", config.GraphiteHostPort)
	log.Debugf("[Config] Test Interval = %ssec", cliFlags.testInterval)
	log.Debugf("[Config] Test Length = %ssec", cliFlags.testLength)
	log.Debugf("[Config] TSDB download prefix = %s", cliFlags.downloadPrefix)
	log.Debugf("[Config] TSDB upload prefix = %s", cliFlags.uploadPrefix)
	printPerfServers(config.PerfServers)

	if cliFlags.netperf {
		netperfRun(config)
	} else {
		iperfRun(config)
	}
}

func iperfRun(config configuration) {
	if cliFlags.noContainer {
		iperfBinary = "iperf3"
	} else {
		runtime := checkContainerRuntime()
		iperfBinary = fmt.Sprintf("%s run -i --rm %s", runtime, cliFlags.imageRepo)
	}
	log.Debugf("[Config] Perf Binary = %s", cliFlags.perfServerPort)

	// assign the perf server port from config first, then cli, lastly defaults
	if config.ServerPort != "" {
		cliFlags.perfServerPort = config.ServerPort
	}
	log.Debugf("[Config] Perf Server Port = %s", cliFlags.perfServerPort)

	// begin the program loop
	for {
		for _, v := range config.PerfServers {
			for endpointAddress, endpointName := range v {
				if endpointName == "" {
					endpointName = endpointAddress
				}
				// Test the download speed to the iperf endpoint.
				iperfDownResults, err := runCmd(fmt.Sprintf("%s -P 1 -t %s -f k -p %s -c %s | tail -n 3 | head -n1 | awk '{print $7}'",
					iperfBinary,
					cliFlags.testLength,
					cliFlags.perfServerPort,
					endpointAddress,
				))

				if strings.Contains(iperfDownResults, "error") {
					log.Errorf("Error testing to the target server at %s:%s", endpointAddress, cliFlags.perfServerPort)
					log.Errorf("Verify iperf is running and reachable at %s:%s", endpointAddress, cliFlags.perfServerPort)
					log.Errorln(err, iperfDownResults)
				} else {
					// verify the results are a valid integer and convert to bps for plotting.
					iperfDownResultsBbps, err := convertKbitsToBits(iperfDownResults)
					if err != nil {
						log.Errorf("no valid integer returned from the iperf test, please run with --debug for details")
					}

					// Write the download results to the tsdb.
					log.Infof("Download results for endpoint %s [%s] -> %d bps", endpointAddress, endpointName, iperfDownResultsBbps)
					timeDownNow := time.Now().Unix()
					msg := fmt.Sprintf("%s.%s %d %d\n", cliFlags.downloadPrefix, endpointName, iperfDownResultsBbps, timeDownNow)
					sendGraphite("tcp", config.GraphiteHostPort, msg)
				}

				// Test the upload speed to the iperf endpoint.
				iperfUpResults, err := runCmd(fmt.Sprintf("%s -P 1 -R -t %s -f k -p %s -c %s | tail -n 3 | head -n1 | awk '{print $7}'",
					iperfBinary,
					cliFlags.testLength,
					cliFlags.perfServerPort,
					endpointAddress,
				))

				if strings.Contains(iperfUpResults, "error") {
					log.Errorf("Error testing to the target server at %s:%s", endpointAddress, cliFlags.perfServerPort)
					log.Errorf("Verify iperf is running and reachable at %s:%s", endpointAddress, cliFlags.perfServerPort)
					log.Errorln(err, iperfUpResults)
				} else {
					// verify the results are a valid integer and convert to bps for plotting.
					iperfUpResultsBbps, err := convertKbitsToBits(iperfUpResults)
					if err != nil {
						log.Errorf("no valid integer returned from the iperf test, please run with --debug for details")
					}

					// Write the upload results to the tsdb.
					log.Infof("Upload results for endpoint %s [%s] -> %d bps", endpointAddress, endpointName, iperfUpResultsBbps)
					timeUpNow := time.Now().Unix()
					msg := fmt.Sprintf("%s.%s %d %d\n", cliFlags.uploadPrefix, endpointName, iperfUpResultsBbps, timeUpNow)
					sendGraphite("tcp", config.GraphiteHostPort, msg)
				}
			}
		}
		// polling interval as defined in the configuration file or cli args
		t, _ := time.ParseDuration(string(cliFlags.testInterval) + "s")
		time.Sleep(t)
	}
}

func netperfRun(config configuration) {

	if cliFlags.noContainer {
		netperfBinary = "netperf"
	} else {
		if cliFlags.imageRepo == defaultIperfRepo {

			cliFlags.imageRepo = defaultNetperfRepo
			log.Debugf("WTF [Config] Perf Binary = %s", cliFlags.imageRepo)

		}
		runtime := checkContainerRuntime()
		netperfBinary = fmt.Sprintf("%s run -i --rm %s", runtime, cliFlags.imageRepo)
	}
	log.Debugf("[Config] Perf Binary = %s", netperfBinary)

	// assign the perf server port from config first, then cli, lastly defaults
	// TODO: make sure this assignment works in all scenarios
	if config.ServerPort != "" {
		cliFlags.perfServerPort = config.ServerPort
	} else {
		cliFlags.perfServerPort = defaultNetperfPort
	}

	log.Debugf("[Config] Perf Server Port = %s", cliFlags.perfServerPort)

	// begin the program loop
	for {
		for _, v := range config.PerfServers {
			for endpointAddress, endpointName := range v {
				if endpointName == "" {
					endpointName = endpointAddress
				}
				// test the speed to the netserver endpoint, ignoring the err as netserver STDERR is not great.
				iperfDownResults, _ := runCmd(fmt.Sprintf("%s -P 0 -t %s -f k -l %s -p %s -H %s | awk '{print $5}'",
					netperfBinary,
					netperfTCP,
					cliFlags.testLength,
					cliFlags.perfServerPort,
					endpointAddress,
				))
				// the error reporting is not great for netperf so we are basically looking for a word in the STDERR
				if strings.Contains(iperfDownResults, "sure") {
					log.Errorf("Error testing to the target server at %s:%s", endpointAddress, cliFlags.perfServerPort)
					log.Errorf("Verify netserver is running and reachable at %s:%s", endpointAddress, cliFlags.perfServerPort)
				} else {
					// verify the results are a valid integer and convert to bps for plotting.
					iperfDownResultsBbps, err := convertKbitsToBits(iperfDownResults)
					if err != nil {
						log.Errorf("no valid integer returned from the netperf test, please run with --debug for details: %v", err)
					}
					// Write the download results to the tsdb.
					log.Infof("Download results for endpoint %s [%s] -> %d bps", endpointAddress, endpointName, iperfDownResultsBbps)
					timeDownNow := time.Now().Unix()
					msg := fmt.Sprintf("%s.%s %d %d\n", cliFlags.downloadPrefix, endpointName, iperfDownResultsBbps, timeDownNow)
					sendGraphite("tcp", config.GraphiteHostPort, msg)
				}
			}
		}

		// polling interval as defined in the configuration file or cli args
		t, _ := time.ParseDuration(string(cliFlags.testInterval) + "s")
		time.Sleep(t)
	}
}

// runCmd Run the iperf container and return the output and any errors.
func runCmd(command string) (string, error) {
	command = strings.TrimSpace(command)
	var cmd string
	var args []string
	cmd = "/bin/bash"
	args = []string{"-c", command}

	// log the shell command being run if the debug flag is set.
	log.Debugf("[CMD] Running Command -> %s", args)

	output, err := exec.Command(cmd, args...).CombinedOutput()
	return strings.TrimSpace(string(output)), err
}

// sendGraphite write the results to a graphite socket.
func sendGraphite(connType string, socket string, msg string) {
	if cliFlags.debug {
		log.Infof("Sending the following msg to the tsdb: %s", msg)
	}
	conn, err := net.Dial(connType, socket)
	if err != nil {
		log.Errorf("Could not connect to the graphite server -> [%s]", socket)
		log.Errorf("Verify the graphite server is running and reachable at %s", socket)
	} else {
		defer conn.Close()
		_, err = fmt.Fprintf(conn, msg)
		if err != nil {
			log.Errorf("Error writing to the graphite server at -> [%s]", socket)
		}
	}
}

// checkContainerRuntime checks for docker or podman.
func checkContainerRuntime() string {
	cmd := exec.Command("docker", "--version")
	_, err := cmd.Output()
	if err == nil {
		return "docker"
	}
	cmd = exec.Command("podman", "--version")
	_, err = cmd.Output()
	if err == nil {
		return "podman"
	}
	if err != nil {
		log.Fatal(errors.New("docker or podman is required for container mode, use the flag \"--nocontainer\" to not use containers"))
	}

	return ""
}

// mapPerfDest creates a k/v pair of node address and node name.
func mapPerfDest(tunnelDestPair string) map[string]string {
	tunnelDestMap := make(map[string]string)
	hostAddressPair := splitPerfPair(tunnelDestPair)

	if len(hostAddressPair) > 1 {
		tunnelDestMap[hostAddressPair[0]] = hostAddressPair[1]
		return tunnelDestMap
	}

	if len(hostAddressPair) > 0 {
		tunnelDestMap[hostAddressPair[0]] = ""
		return tunnelDestMap
	}

	return tunnelDestMap
}
