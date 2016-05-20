#!/bin/bash
log() {
    printf "[INFO] preStart: %s\n" "$@"
}
loge() {
    printf "[ERROR] preStart: %s\n" "$@"
}

# update elasticsearch URL configuration
replace() {
    # Point to the correct Elasticsearch endpoint using the default dns search path
    REPLACEMENT=$(printf 's/# elasticsearch\.url: "http:\/\/localhost:9200"/elasticsearch.url: "http:\/\/elasticsearch-data.service.consul:9200"/')
    sed -i "$REPLACEMENT" /opt/kibana/config/kibana.yml
    # Quiet logging
    REPLACEMENT=$(printf 's/# logging\.quiet: false/logging.quiet: true/')
    sed -i "$REPLACEMENT" /opt/kibana/config/kibana.yml    
}

# Wait till Elasticsearch is available
log "Waiting for Elasticsearch data node..."
until (curl -Ls --fail "${CONSUL}/v1/health/service/elasticsearch-data?passing" | jq -e -r '.[0].Service.Address' >/dev/null); do
    sleep 20
done

log "Elasticsearch is now available, configuring Kibana"
# Initialise Logstash index
echo "<30>$(date '+%b %d %H:%M:%S') $HOSTNAME startup: Initialising Logstash" | nc -w 60 logstash-syslog.service.consul 3164
replace
exit 0
