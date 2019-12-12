# Bandwidth Performance Monitoring with Iperf

### Overview

Network visibility is one of the most important assets in a network engineer's toolkit. This is a tool measuring bandwidth that can be useful for capacity planning, SLAs, troubleshooting or any other scenario that having a realtime and historical measurements of bandwidth is useful. Multiple cloud environments, coupled with data gravity driving clusters of compute at the edge is increasing the network sprawl and piling on the ever-growing challenges for network ops/architecture/engineering.

This project is designed to measure bandwidth to distributed endpoints across networks and clouds. Having visibility to edge and multi-cloud resources can get overly complicated and/or expensive with many solutions. Heavyweight agents can be problematic.

This is a simple method of:
- Setting up iperf servers on your edge/clouds/enterprise as listeners
- Polling the listeners
- Graphing the results into a TSDB 
- Visualizing the results into dashboards with Grafana

I scrapped the old architecture of this for a simpler approach. The `old` directory has the old code, docs and configs in case anyone has forked that or wants to see another approach.

### New Opportunities to Manage Networks

- Building tools has never been easier. Open source software can be leveraged to customize tools for your network or customers network 

- Historical records of network data. Many of the traditional problems with networking and uptime can be significantly reduced with post-mortem reviews with relevant data to determine root causes of events. 

- Rather then using traditional RDBMS approaches, here we are using Time Series Databases (TSDB) that are designed to ingest large amounts of timestamped metrics. That is perfect for collecting all of the different metrics we are interested in as network nerds.

### QuickStart Demo

Start the TSDB and Grafana:

```sh
docker run -d\
 --name go-graphite\
 --restart=always\
 -p 80:80\
 -p 2003-2004:2003-2004\
 gographite/go-graphite
```

This maps the following ports:

Host | Container | Service
---- | --------- | -------------------------------------------------------------------------------------------------------------------
  80 |        80 | [grafana](http://docs.grafana.org/)
2003 |      2003 | [carbon receiver - plaintext](http://graphite.readthedocs.io/en/latest/feeding-carbon.html#the-plaintext-protocol)
2004 |      2004 | [carbon receiver - pickle](http://graphite.readthedocs.io/en/latest/feeding-carbon.html#the-pickle-protocol)

verify you can reach the grafana/graphite server running by pointing your browser to the container IP. If you're running Docker for desktop on a Mac, [http://localhost](http://localhost). On Linux just point to the host IP since the port is getting mapped with `-p 80:80`. The default login is `username: admin` and `password: admin`

```sh
git clone https://github.com/nerdalert/cloud-bandwidth.git
cd cloud-bandwidth/
```

Now you can run a simple script that will generate some metrics to simulate iperf polls and push them to the graphite/grafana server. I recommend starting here in order to make sure your stack is working properly.

```sh
./scripts/generate_test_grafana_data.sh <insert_ip_address of the server> 2003
```

While some generic data is getting populated, next log into the Grafana server and import a dashboard that will match the sample data the script is pushing.

- Copy the json in [default-grafana.json](./default-grafana.json) and paste it into a new dashboard by clicking the + and then import in the Grafana splash page:

![](http://networkstatic.net/wp-content/uploads/2019/11/grafana-import-sm.png)

- After a couple of minutes you should start seeing data getting populated like so: 

![](http://networkstatic.net/wp-content/uploads/2019/11/grafana-demo.png)

If you do not see data appearing in the graphs, it will possibly be a connectivity issue. Testing the port is a good first step with something like netcat or your favorite tool:

```sh
nc -zv <address_of_graphite/grafana container> 2003
found 0 associations
found 1 connections:
     1:	flags=82<CONNECTED,PREFERRED>
	outif lo0
	src ::1 port 49493
	dst ::1 port 2003
	rank info not available
	TCP aux info available

Connection to localhost port 2003 [tcp/*] succeeded!
```

You can also send any data you want to the Graphite/Grafana/Carbon stack for testing with:

```sh
echo "bandwidth.download.azure $RANDOM `date +%s`" | nc insert_ip_of_the_graphite_server_here 2003
```

It may be helpful in getting started with Grafana to use the template included here with names of the server endpoints you setup, or start from scratch with your endpoints. The name of the endpoint being polled is what will show up in Grafana that you then make a graph for. You can view all endpoints in the time-series database by entering `bandwidth.download.*` or `bandwidth.upload.*` from within the Grafana UI. It's pretty easy to get the hang of by playing around with the demo data and grafana template included that you can import.

## Quickstart with Real Bandwidth

Once you have some test data being feed into the carbon receiver, next let's measure some real bandwidth. First, if you haven't used iperf before, I recommend running it manually to get a feel of what's going on under the hood to get the measurements [nerdalert/iperf3](https://github.com/nerdalert/iperf3). The remote nodes can be simple hardware/VMs/Rasberry Pi's or even network devices that are flexible enough to install software on them with a little CPU allocated.

```sh
git clone https://github.com/nerdalert/cloud-bandwidth.git
cd cloud-bandwidth/
```

On your edge devices that you are measuring bandidth to, start the iperf servers. You can either run them in a container or in the default namespace outside of a container:


```sh
# running the container in daemon mode with `-d` is the best idea but for 
# getting started to view the output for debugging the setup with stdout, I recommend:
docker run -it --restart=always --name=iperf-svr networkstatic/iperf3 -s
```
As you go beyond testing on your localhost, you will also likely want to map the iperf listening port 5201 to be exposed for remote connections like so using the flag `-p 5201:5201`:

```sh
docker run -it --restart=always --name=iperf3-server2 -p 5201:5201  networkstatic/iperf3 -s
```

Just as valid, if you dont feel like using a container, you can simply install iperf3 and run it in the default namespace:

```sh
iperf3 -s
```

At any time you can delete the container with:

```sh
docker stop iperf-svr && docker rm iperf-svr
```

For testing this out, I recommend starting some iperf servers in containers on your desktop to make troubleshooting easier. The poller is a container so there is no need to map ports if you are running your test iperf server on the same machine as where you are running the `cbandwidth` binary.

```yml
---
# the length of the iperf test in seconds
test-length: 5
# the time between polls, defaults to 5 minutes (300 sec)
test-interval: 300
# iperf server port
server-port: 5201
# Address of the graphite/grafana stack running in a container (docker for mac uses localhost).
# For a setup beyond a dev environment, grafana-address will be a routable/reachable address
# that the polling host can connect to in order to run the client/server test.
grafana-address: localhost
grafana-port: 2003
# The prefix of the stored tsdb data in graphite
tsdb-download-prefix: bandwidth.download
tsdb-upload-prefix: bandwidth.upload
iperf-servers: 
  - 172.17.0.3: azure
  - 172.17.0.4: digitalocean
  - 172.17.0.5: some_location
# iperf-servers are the remote iperf servers getting polled
# the key is the address getting polled
# The value (after the colon )is the name that will show up in grafana 
```

Located with the binaries in the [binaries directories](./binaries) is a config.yml file. The config file either needs to be in the same directory as the binary or referenced with a flag.

Now start the poller by dropping into the binaries directory and running the binary for your system. Docker is required to run these binaries. The app provides a sample of the bi-drectional bandwidth by testing both upload and download speeds between the server and poller.

Mac:

```sh
cd ./binaries/macosx/
./cbandwidth -config=./config.yml
```

Linux:

```sh
cd ./binaries/linux/
./cbandwidth -config=./config.yml
```

To view the underlying commands being run such as the iperf polling and the writes to Carbon, simply add the `./cbandwidth -debug` flag.

Here is some example output of the app polling three endpoints:

![](http://networkstatic.net/wp-content/uploads/2019/11/cbandwidth-800.gif)


You can also of course run this using `go run cbandwidth.go` directly. You can also build binaries for your machine type. For other hardware archetectures you can cross-compile in go. I just did the usual Darwin/Linux archs. Supported types can be seen with `go tool dist list` and is as simple as the following example `GOOS=linux GOARCH=amd64 go build -v cbandwidth.go`.

Thats it! Patch, Fork, do whatever you want with it. Thanks to all the various open source projects used for this. Special thanks to [ESnet](http://software.es.net/iperf/) for re-rolling iperf into iperf3. It is really nice how the initialized channel from client -> server is reused for the reverse. It gives you bi-directional measurements without having to expose (or NAT) both endpoints, just the channel initializer. Feel free to open any issues if you run into anything. I will improve things as time permits. Thanks!
