FROM java:8

ENV ES_PKG_NAME elasticsearch-1.4.0

# Define working directory.
WORKDIR /

# Install Elasticsearch todo: change to library version
RUN wget https://download.elasticsearch.org/elasticsearch/elasticsearch/$ES_PKG_NAME.tar.gz && \
    tar xvzf $ES_PKG_NAME.tar.gz && \
    rm -f $ES_PKG_NAME.tar.gz && \
    mv /$ES_PKG_NAME /elasticsearch

# Define mountpoint data
VOLUME ["/data"]

# Mount config elasticsearch.yml
ADD config/elasticsearch.yml /elasticsearch/config/elasticsearch.yml

# Re-define working directory.
WORKDIR /data

# Expose ports.
#   - 9200: HTTP
EXPOSE 9200
#   - 9300: transport
EXPOSE 9300

# Define default command.
CMD ["/elasticsearch/bin/elasticsearch"]

