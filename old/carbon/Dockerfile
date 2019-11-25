FROM debian:jessie

ENV VERSION 0.9.x
ENV WHISPER_VERSION 0.9.13

RUN apt-get update -q \
    && apt-get install -y python python-dev python-pip git-core \
    && apt-get clean

# Use pip to build whisper for a tsdb
RUN pip install -U pip
RUN pip install git+https://github.com/graphite-project/carbon.git@${VERSION}#egg=carbon whisper==${WHISPER_VERSION}

# Define working dir
WORKDIR /opt/graphite

RUN cp conf/carbon.conf.example conf/carbon.conf && \
    cp conf/storage-schemas.conf.example conf/storage-schemas.conf && \
    cp conf/storage-aggregation.conf.example conf/storage-aggregation.conf

EXPOSE 2003
EXPOSE 2004

# Mount persistent storage volume
VOLUME /opt/graphite/storage

CMD ["./bin/carbon-cache.py", "--nodaemon", "start"]