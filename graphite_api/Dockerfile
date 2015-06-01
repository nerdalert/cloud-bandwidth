FROM debian:jessie

# SW versioning todo: bump to 2.x
ENV GRAPHITE_API_VERSION 1.0.1
ENV GRAFANA_VERSION 1.9.1

VOLUME /srv/graphite

RUN apt-get update -q \
    && apt-get install -y \
    wget \
    build-essential \
    libffi-dev \
    libcairo2-dev\
    python-dev \
    python-pip \
    && apt-get clean
RUN pip install -U pip
RUN pip install uwsgi graphite-api[sentry]==${GRAPHITE_API_VERSION}

RUN wget -qO- http://grafanarel.s3.amazonaws.com/grafana-${GRAFANA_VERSION}.tar.gz | tar xvzf - \
    && mv grafana-${GRAFANA_VERSION} grafana

# Add predefined config files
ADD grafana-config.js /grafana/config.js
ADD graphite-api.yaml /etc/graphite-api.yaml
ADD default.json /grafana/app/dashboards/default.json

# Expose the grafana web port
EXPOSE 8000

CMD ["uwsgi", "--module=graphite_api.app:app",\
            "--master", \
            "--http=:8000", \
            "--processes=2" ,\
            "--thunder-lock", \
            "--enable-threads",\
            "--offload-threads=4",\
            "--check-static=/grafana", \
            "--static-index=index.html"]