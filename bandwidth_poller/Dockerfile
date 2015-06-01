FROM debian:latest

MAINTAINER Brent Salisbury <brent.salisbury@gmail.com>

# get, install and clean binaries
RUN apt-get update -q \
    && apt-get install -y \
    wget \
    netcat \
    iperf3 \
    && apt-get clean

# IP address of the graphite-api for time series
# data collection of the iperf bandwidth results.
ENV DB_IP MANDATORY_DB_FIELD_MISSING
# plain text port used for feeding data to Carbon/Graphite
ENV DB_PORT 2003
# The ip is retrieved from the command 'docker-machine ip <machine name>'
# That gets the public address of the VM that has a container inside of
# it running iperf and bound to port 5201 the default port that is exposed.
ENV BW_AGENT_IP MANDATORY_IP_FIELD_MISSING
# iperf flags - in this case the are geared to use a small amount of bandwidth
#  Overiding these values (ENV) will give a bit more accurate reading of bandwidth from
# client <-> server. (-t)time in seconds to transmit (10 seconds is the default of iperf)
ENV IPERF_SAMPLE_COUNT 4
# Default driver is boot2docker. Making it obvious if the ENV is not set
# as it should be by the passed values from 'docker run'
#ENV MACHINE_TYPE UNDEFINED

# Expose the default iperf3 port binding
EXPOSE 5201

# Set the container dir
WORKDIR /usr/local/src

# Copy the shell script to the container and run it as the entrypont
COPY entry.sh ./
RUN chmod +x ./entry.sh
ENTRYPOINT ["./entry.sh"]
