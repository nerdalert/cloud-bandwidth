# Cloud Bandwidth Performance Monitoring with Docker

I will be doing a network app of the month series of blog posts. For some it will be someone else's cool project I see on [Github](https://github.com/search/advanced) and [Docker Hub Registry](https://registry.hub.docker.com), other times like this one I will stitch together an app to share. In this example we will use Docker Machine, Docker Compose and Docker Engine to bring up bandwidth measurements of both inside your data center and to the Internet. 

What I like about this example networking use case is folks can start thinking about immutable infrastructures. In this example we will spin up a poller and agents to be polled. After each polling round, the poller and agent containers are deleted. As the next polling cycle comes along we simply start new containers. So the beauty is I no longer have to worry about the state of the long running service. 

The longer an application runs the greater the odds of its state getting screwed up and eventually fail. Now when I write the code to interact with distributed systems, the odds are much better that I will avoid any issues with the process doing its event since I only have to worry about it running for the amount of time to process the workload rather then running without issue indefinitely/infinitely. There is a reason Google can boast about going through 2billion containers a week, when you treat build a throw away infra it is inherent to the philosophy to recreate the environment to the exact pristine state you desire for each new workload. Its getting a new car every time you drive to the store.

### New Opportunities to Manage Networks


- Network Engineers having easy access to compute cycles without having to concern themselves with any care and feeding of the underlying OS (patch management, licensing etc).

- Have compute in diverse geographical locations. This allows for a diverse view of bandwidth and to better triangulate potential bottlenecks.

- Historical records of network data. Many of the traditional problems with networking and uptime can be significantly reduced with post-mortem reviews with relevant data to determine root causes of events. 

- The data generated when truly collecting the amount of data necessary to provide next to perfect uptime can be enormous and will compare will likely be on par with your organizations digital information classified as big data . Rather then using traditional RDBMS approaches, using Time Series Databases (TSDB) that are designed to ingest large amounts of timestamped metrics.

- If you haven't used Docker before check out the [docs](https://docs.docker.com)  and this cool [tutorial](https://www.docker.com/tryit/).

### Cloud Bandwidth QuickStart

For my fellow hack first read later peoples here is the quick up and running instructions. To setup your environment take a look at the [Docker Docs](https://docs.docker.com/machine/) and check out some install scripts [here](https://github.com/nerdalert/docker-devoops-scripts). I haven't tested the bash wrapper on anything other then a Mac as I ran out of weekend.

**- QuickStart Demo**

```
git clone https://github.com/nerdalert/cloud-bandwidth.git
cd cloud-bandwidth/
docker-compose -f run_demo.yml up
```

Then point a browser to `http://<DOCKER_IP>:8000`

To stop and remove the demo containers running with compose simply run the following in the same directory as the .yml file:

```
docker-compose -f run_demo.yml kill
docker-compose -f run_demo.yml rm -f
```

**- Quick start real bandwidth**

```
git clone https://github.com/nerdalert/cloud-bandwidth.git
docker-compose up
```

In a new terminal, your docker machine should have at least a virtualbox machine defined

```
 docker-machine ls
NAME                   ACTIVE   DRIVER         STATE     URL                         SWARM
virtualbox-machine     *        virtualbox     Running   tcp://192.168.99.101:2376

```
Then run the bash wrapper with:

```
cd cloud-bandwidth
chmod +x ./run.sh
./run.sh  -s 45 -p virtualbox-machine -t virtualbox-machine 
```

Then point a browser to `http://<DOCKER_IP>:8000`

### Clone the repo

```
git clone https://github.com/nerdalert/cloud-bandwidth.git
cd cloud-bandwidth
```

### Create a Docker Machine

```
docker-machine create --driver virtualbox virtualbox-machine
eval "$(docker-machine env virtualbox-machine)"

docker-machine ls
# NAME                   ACTIVE   DRIVER         STATE     URL                         SWARM
# virtualbox-machine     *        virtualbox     Running   tcp://192.168.99.101:2376
```

### Run the demo

Pass `-f` and the demo yml file to docker-compose which tells it to use `run_demo.yml` configurations rather then the default `docker-compose.yml` that is in the same directory. Again, the `-f run_demo.yml` is **only** for running the demo. Later when running with real data you simply use the defaults with `docker-compose up`

```
docker-compose -f run_demo.yml up
```

You will see something like:

```
carbon_1        | 30/05/2015 10:47:18 :: [listener] MetricLineReceiver connection with 172.17.0.96:54617 established
carbon_1        | 30/05/2015 10:47:18 :: [listener] MetricLineReceiver connection with 172.17.0.96:54617 closed cleanly
```


That means mock values are being written to to whisper via carbon collector and graphed by Grafana. That is a piece that can be consolidated into Influxdb and Grafana to reduce moving parts, though compose does make it much easier.

When stopping and starting the docker-compose stack I recommend doing the following to

### View The Grafana Dashboard

Now point your browser to the grafana UI and see the data being graphed. Get the ip address with:

```
docker-machine ip virtualbox-machine
# 192.168.99.101

# or docker-machine ls and see the API ip:port '192.168.99.101:2376'

docker-machine ls
# NAME                   ACTIVE   DRIVER         STATE     URL                         SWARM
# virtualbox-machine     *        virtualbox     Running   tcp://192.168.99.101:2376
```

The docker-compose and dockerfile instruct grafana to use port 8000 `8000`

`http://<MACHINE_IP>:8000`

You will begin to see the following be generated:

![](http://networkstatic.net/wp-content/uploads/2015/06/Cloud-Bandwidth.jpg)


To reiterate these are mock values being written to the TSDB using `docker-compose -f run_demo.yml up`. 

Once done with the demo stop and recreate the containers using the default yml file.

```
docker-compose -f run_demo.yml kill
docker-compose -f run_demo.yml rm -f
```

### Measuring Real Bandwidth

The pre-requisite is to have the docker-machines up and running that you plan on running measurements against. Here is an example of a docker-machine setup. **Note**: tokens/credentials for each host are stored in `~/.docker/machines` 

Here is an example of a populated `docker-machine ps` *(all done with trial accounts btw, kudos to the evagilist at those CSPs)*.

```
docker-machine ls
NAME                   ACTIVE   DRIVER         STATE     URL                         SWARM
aws-machine                     amazonec2      Running   tcp://54.85.219.54:2376
digitalocean-machine            digitalocean   Stopped   tcp://45.55.146.243:2376
google-machine                  google         Running   tcp://146.148.61.62:2376
virtualbox-machine     *        virtualbox     Running   tcp://192.168.99.101:2376

ls ~/.docker/machine/machines/
virtualbox-machine/   google-machine/       digitalocean-machine/ aws-machine/
```

Start the **non-demo** compose build with the following:

```
docker-compose up
```

Make sure the TSDB stack is up and running with `docker ps` or checking connectivity to the TCP ports for tshooting.

To run in the background as a daemon process pass the `-d` parameter:

There are two required parameters and one optional:

1. The `-t` target machine(s) you are running as iperf agent.
2. The `-p` the poller that will connect to the iperf agent.
3. The `-s` interval in seconds between polling intervals. The default is 300 seconds which means the poller will run a measurement every 5 minutes againts the target listeners.

>usage: ./run.sh [-s (interval seconds)] [-p (machine that poller runs on)] [-t (list of target servers)]

Make sure the docker-compose stack is still up and running.

First run against the local virtual-box machine as both the client and server to make sure everything works. The iperf image will be downloaded the first time you run listeners on a new VM/Machine.

**Note**: The polling interval is set pretty low at 60 seconds here for testing purposes. 180-600 seconds (3-10 minutes) seems like reasonable polling boundaries for production.
```
chmod +x ./run.sh
./run.sh  -s 60 -p virtualbox-machine -t virtualbox-machine 
```

### Next Add a Cloud Provider to Measure the Inets

Next test using a different driver. In this case I am using the `digitalocean` driver. I really like the Digital Ocean driver for testing for 2 reason. 

1. It only requires the token from Digital Ocean to start. While there are lots of parameter you can set, there are very common sense defaults.
2. It is also dead simple to setup. They have a free trial and their containers are really cheap. 

Rackspace is another really simple one to setup, no mandatory firewall permits etc. AWS and GCE both will block incoming port 5201 connection attempts unless you open it with a rule.

See the more detailed doc in the project for more on creating machines.

Test the port before you start `run.sh` by telnetting to port 5201 and testing. Since we are running iperf3 using TCP for transport you will get a socket:

```
docker-machine ip <machine name>
telnet  <IP_address> 5201
telnet $(docker-machine ip digitalocean-machine) 5201
```

Now add a cloud provider, in this case I am using digital ocean. Make sure docker-machine sees all of the machines you are going to use in a healthy status:

```
docker-machine ls
NAME                   ACTIVE   DRIVER         STATE     URL                         SWARM
digitalocean-machine            digitalocean   Running   tcp://45.55.146.243:2376
virtualbox-machine     *        virtualbox     Running   tcp://192.168.99.101:2376
```
Then simply add the new machine after virtualbox-machine

```
./run.sh  -s 180 -p virtualbox-machine -t digitalocean-machine virtualbox-machine google-machine 
```

Thats it! Patch, Fork, do whatever you want with it. Thanks to all the various open source projects used for this. Building a throw away infrastrucure is incredibly fun. Special thanks to [ESnet](http://software.es.net/iperf/) for re-rolling iperf into iperf3. It is really nice how the initialized channel from client -> server is reused for the reverse. It gives you bi-directional measurements without having to expose (or NAT) both endpoints, just the channel intiator. And [Grafana](http://grafana.org), well its just awesome. That should be a networkers best friend for pumping data into for data vis.

### Modifying on the Poller Agent

If you want to modify the bandwidth poller, you can build it locally and it will cache it in your images with the following:
```
cd bandwidth-poller
docker build -t networkstatic/bandwidth-poller .
```

### Notes on Creating Docker Machines

Here is an image of why I love docker machine. In the context of this App, the poller resides on the host running docker-machine and the bandwidth agent runs on the endpoints:

![](https://cloud.githubusercontent.com/assets/1711674/7408653/ffad6dbe-eeec-11e4-85b2-9fef61d02818.gif)

I noticed AWS and GCE didnt expose port 5201 by default. I havent check whats up there yet. [Digital Ocean](http://networkstatic.net/running-docker-machine-on-digital-ocean/) is very easy to start with. There are also some miscelaneous scripts in, you guessed it, the scripts directory.


```
docker-machine create \
      --driver rackspace \
      --rackspace-username ${RACKSPACE_USERNAME} \
      --rackspace-api-key ${RACKSPACE_KEY} \
      --rackspace-region ${RACKSPACE_ZONE} \
      --rackspace-flavor-id 2 \
      rackspace-machine

docker-machine create -d azure \
    --azure-subscription-id ${AZURE_SUB_ID} \
    --azure-subscription-cert=${AZURE_CERT} \
    azure-machine

docker-machine create \
     --driver digitalocean \
     --digitalocean-access-token ${DIGITAL_OCEAN_TOKEN} \
     digitalocean-machine

docker-machine create \
    --driver google \
    --google-project ${GOOGLE_PROJECT} \
    --google-zone ${GOOGLE_ZONE} \
    google-machine
```
