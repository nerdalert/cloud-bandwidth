package main

import (
	"flag"
	"fmt"
	"github.com/Sirupsen/logrus"
	"gopkg.in/yaml.v2"
	"io/ioutil"
	"os"
	"os/exec"
	"strings"
	"time"
)

type Config struct {
	TestDuration string    `yaml:"test-length"`
	TestInterval string    `yaml:"test-interval"`
	ServerPort   string    `yaml:"server-port"`
	TsdbServer   string    `yaml:"grafana-address"`
	TsdbPort     string    `yaml:"grafana-port"`
	Entry        []Servers `yaml:"iperf-servers"`
}

type Servers map[string]string

type Endpoint struct {
	ServerIP   string
	Port       string
	ServerName string
}

type Cli struct {
	Debug      bool
	ConfigPath string
	Help       bool
}

var cli *Cli
var iperfImg = "networkstatic/iperf3"
var log = logrus.New()

func SetLogger(l *logrus.Logger) {
	log = l
}

func init() {
	const (
		debugFlag     = false
		debugDescrip  = "Run in debug mode to display all shell commands being executed"
		configPath    = "./config.yml"
		configDescrip = "Path to the configuration file -config=path/config.yml"
		helpFlag      = false
		helpDescrip   = "Print Usage Options"
	)
	cli = &Cli{}
	flag.BoolVar(&cli.Debug, "debug", debugFlag, debugDescrip)
	flag.StringVar(&cli.ConfigPath, "config", configPath, configDescrip)
	flag.BoolVar(&cli.Help, "help", helpFlag, helpDescrip)
}

func main() {
	flag.Parse()
	if cli.Help {
		flag.PrintDefaults()
		os.Exit(1)
	}
	for {
		// Read in the yaml configuration from config.yaml
		data, err := ioutil.ReadFile(cli.ConfigPath)
		if err != nil {
			log.Fatalln("There was a problem opening the configuration file. Make sure "+
				"'config.yml' is located in the same directory as the binary 'cbandwidth' or set"+
				" the location using -config=path/config.yml || Error: ", err)
		}
		config := Config{}
		if err := yaml.Unmarshal([]byte(data), &config); err != nil {
			log.Fatal(err)
		}
		for _, val := range config.Entry {
			for endpointAddress, endpointName := range val {
				if endpointName == "" {
					endpointName = endpointAddress
				}
				// Test the download speed to the iperf endpoint
				iperfDownResults, err := runCmd(fmt.Sprintf("docker run -i --rm %s -P 1 -t %s -f bits "+
					"-p %s -c %s | tail -n 3 | head -n1 | awk '{print $7}'",
					iperfImg,
					config.TestDuration,
					config.ServerPort,
					endpointAddress,
				), cli)
				if strings.Contains(iperfDownResults, "error") {
					log.Errorf("Error testing iperf server at %s:%s", endpointAddress, config.ServerPort)
					log.Errorf("Verify iperf is running and reachable at %s:%s", endpointAddress, config.ServerPort)
					log.Errorln(err, iperfDownResults)
				} else {
					log.Infof("Download results for endpoint %s -> %s bps", endpointAddress, iperfDownResults)
					timestamp := getUxDate()
					grafanaResults, err := runCmd("echo \"bandwidth.download."+endpointName+" "+
						iperfDownResults+" "+timestamp+"\" | nc "+
						config.TsdbServer+" "+config.TsdbPort, cli)
					if err != nil {
						log.Errorf("Error writing to the graphite server at %s:%s", config.TsdbServer, config.TsdbPort)
						log.Errorf("Verify the graphite server is running and reachable at %s:%s",
							config.TsdbServer, config.TsdbPort)
						log.Errorln(err, grafanaResults)
					}
				}
				// Test the upload speed to the iperf endpoint
				iperfUpResults, err := runCmd(fmt.Sprintf("docker run -i --rm %s -P 1 -R -t %s "+
					"-f bits -p %s -c %s | tail -n 3 | head -n1 | awk '{print $7}'",
					iperfImg,
					config.TestDuration,
					config.ServerPort,
					endpointAddress,
				), cli)
				if strings.Contains(iperfUpResults, "error") {
					log.Errorf("Error testing iperf server at %s:%s", endpointAddress, config.ServerPort)
					log.Errorf("Verify iperf is running and reachable at %s:%s", endpointAddress, config.ServerPort)
					log.Errorln(err, iperfUpResults)
				} else {
					log.Infof("Upload results for endpoint %s -> %s bps", endpointAddress, iperfUpResults)
					timestamp := getUxDate()
					grafanaResults, err := runCmd("echo \"bandwidth.upload."+endpointName+" "+iperfUpResults+
						" "+timestamp+"\" | nc "+
						config.TsdbServer+" "+config.TsdbPort, cli)
					if err != nil {
						log.Errorf("Error writing to the graphite server at %s:%s", config.TsdbServer, config.TsdbPort)
						log.Errorf("Verify the graphite server is running and reachable at %s:%s",
							config.TsdbServer, config.TsdbPort)
						log.Errorln(err, grafanaResults)
					}
				}
			}
		}
		// Polling interval as defined in the config file. The default is 5 minutes.
		t, _ := time.ParseDuration(string(config.TestInterval) + "s")
		time.Sleep(t)
	}
}

// Run the iperf cmd and return the output and error
func runCmd(command string, cli *Cli) (string, error) {
	command = strings.TrimSpace(command)
	var cmd string
	var args []string
	cmd = "/bin/bash"
	args = []string{"-c", command}
	// log the shell command being run to stdout if the debug flag is set
	if cli.Debug {
		log.Infoln("Running shell command -> ", args)
	}
	output, err := exec.Command(cmd, args...).CombinedOutput()
	return strings.TrimSpace(string(output)), err
}

// Return Unix date
func getUxDate() string {
	t := time.Now().Unix()
	tsec := strings.Fields(fmt.Sprint(t))
	return tsec[0]
}
