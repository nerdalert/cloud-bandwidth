package main

import (
	"errors"
	"fmt"
	"io/ioutil"
	"net"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"github.com/sirupsen/logrus"
	"github.com/urfave/cli/v2"
	"gopkg.in/yaml.v2"
)

type Config struct {
	TestDuration   string    `yaml:"test-length"`
	TestInterval   string    `yaml:"test-interval"`
	ServerPort     string    `yaml:"server-port"`
	TsdbServer     string    `yaml:"grafana-address"`
	TsdbPort       string    `yaml:"grafana-port"`
	TsdbDownPrefix string    `yaml:"tsdb-download-prefix"`
	TsdbUpPrefix   string    `yaml:"tsdb-upload-prefix"`
	Entry          []Servers `yaml:"iperf-servers"`
}

type Servers map[string]string

var log = logrus.New()

var cliFlags flags

type flags struct {
	configPath  string
	imageRepo   string
	noContainer bool
	debug       bool
}

func main() {
	// instantiate the cli
	app := cli.NewApp()
	// flags are stored in the global flags variable
	app = &cli.App{
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:        "config",
				Value:       "config.yaml",
				Usage:       "Path to the configuration file -config=path/config.yaml (default \"config.yaml\")",
				Destination: &cliFlags.configPath,
				EnvVars:     []string{"CBANDWIDTH_CONFIG"},
			},
			&cli.StringFlag{
				Name:        "image",
				Value:       "quay.io/networkstatic/iperf3",
				Usage:       "Custom repo to an Iperf3 image (default \"quay.io/networkstatic/iperf3\")",
				Destination: &cliFlags.imageRepo,
				EnvVars:     []string{"CBANDWIDTH_IPERF3_IMAGE"},
			},
			&cli.BoolFlag{
				Name:        "nocontainer",
				Value:       false,
				Usage:       "Do not use docker or podman and run the iperf3 binary by the host (default is containerized)",
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

	app.Name = "tunnel-benchmark"
	app.Usage = "tool used to measure various data plane implementations"
	// clean up any pre-existing interfaces or processes from prior tests
	app.Before = func(c *cli.Context) error {
		if c.IsSet("clean") {
			log.Print("Cleaning up any existing benchmark interfaces")
			// todo: implement a cleanup function
		}
		return nil
	}
	app.Action = func(c *cli.Context) error {
		// call the applications function
		runApp()
		return nil
	}
	app.Run(os.Args)
}

func runApp() {
	var iperfBinary string
	if cliFlags.noContainer {
		iperfBinary = "iperf3"
	} else {
		runtime := checkContainerRuntime()
		iperfBinary = fmt.Sprintf("%s run -i --rm %s", runtime, cliFlags.imageRepo)
	}

	// Read in the yaml configuration from config.yaml
	data, err := ioutil.ReadFile(cliFlags.configPath)
	if err != nil {
		log.Fatalln("There was a problem opening the configuration file. Make sure "+
			"'config.yaml' is located in the same directory as the binary 'cloud-bandwidth' or set"+
			" the location using -config=path/config.yaml [Error]: ", err)
	}
	// read in the config file
	config := Config{}
	if err := yaml.Unmarshal([]byte(data), &config); err != nil {
		log.Fatal(err)
	}

	graphiteSocket := net.JoinHostPort(config.TsdbServer, config.TsdbPort)
	for _, val := range config.Entry {
		for endpointAddress, endpointName := range val {
			if endpointName == "" {
				endpointName = endpointAddress
			}
			// Test the download speed to the iperf endpoint.
			iperfDownResults, err := runCmd(fmt.Sprintf("%s -P 1 -t %s -f K -p %s -c %s | tail -n 3 | head -n1 | awk '{print $7}'",
				iperfBinary,
				config.TestDuration,
				config.ServerPort,
				endpointAddress,
			))

			if strings.Contains(iperfDownResults, "error") {
				log.Errorf("Error testing iperf server at %s:%s", endpointAddress, config.ServerPort)
				log.Errorf("Verify iperf is running and reachable at %s:%s", endpointAddress, config.ServerPort)
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
				msg := fmt.Sprintf("%s.%s %d %d\n", config.TsdbDownPrefix, endpointName, iperfDownResultsBbps, timeDownNow)
				sendGraphite("tcp", graphiteSocket, msg)
			}
			// Test the upload speed to the iperf endpoint
			iperfUpResults, err := runCmd(fmt.Sprintf("%s -P 1 -R -t %s -f K -p %s -c %s | tail -n 3 | head -n1 | awk '{print $7}'",
				iperfBinary,
				config.TestDuration,
				config.ServerPort,
				endpointAddress,
			))
			if strings.Contains(iperfUpResults, "error") {
				log.Errorf("Error testing iperf server at %s:%s", endpointAddress, config.ServerPort)
				log.Errorf("Verify iperf is running and reachable at %s:%s", endpointAddress, config.ServerPort)
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
				msg := fmt.Sprintf("%s.%s %d %d\n", config.TsdbUpPrefix, endpointName, iperfUpResultsBbps, timeUpNow)
				sendGraphite("tcp", graphiteSocket, msg)
			}
		}
	}
	// Polling interval as defined in the config file. The default is 5 minutes.
	t, _ := time.ParseDuration(string(config.TestInterval) + "s")
	time.Sleep(t)
}

// Run the iperf container and return the output and any errors
func runCmd(command string) (string, error) {
	command = strings.TrimSpace(command)
	var cmd string
	var args []string
	cmd = "/bin/bash"
	args = []string{"-c", command}
	// log the shell command being run to stdout if the debug flag is set
	if cliFlags.debug {
		log.Infoln("Running shell command -> ", args)
	}
	output, err := exec.Command(cmd, args...).CombinedOutput()
	return strings.TrimSpace(string(output)), err
}

// Write the results to a graphite socket
func sendGraphite(connType string, socket string, msg string) {
	if cliFlags.debug {
		log.Infof("Sending the following msg to the tsdb: %s", msg)
	}
	conn, err := net.Dial(connType, socket)
	if err != nil {
		log.Errorf("Could not connect to the graphite server -> %s", socket)
		log.Errorf("Verify the graphite server is running and reachable at %s", socket)
	} else {
		defer conn.Close()
		_, err = fmt.Fprintf(conn, msg)
		if err != nil {
			log.Errorf("Error writing to the graphite server at -> %s", socket)
		}
	}
}

// checkContainerRuntime checks for docker or podman
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

// convertKbitsToBits iperf3 no longer supports bps, so convert Kbps to bps for tsdb plotting.
func convertKbitsToBits(kbps string) (int, error) {
	kbpsInt, err := strconv.Atoi(kbps)
	if err != nil {
		return 0, err
	}

	bps := kbpsInt * 1000

	return bps, nil
}
