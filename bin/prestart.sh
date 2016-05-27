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
#------------------------------------------------------------------------------
# Check that CONSUL environment variable exists
if [[ -z ${CONSUL} ]]; then
    loge "Missing CONSUL environment variable"
    exit 1
fi

# Wait up to 2 minutes for Consul to be available
log "Waiting for Consul availability..."
n=0
until [ $n -ge 120 ]||(curl -fsL --connect-timeout 1 "${CONSUL}/v1/status/leader" &> /dev/null); do
    sleep 2
    n=$((n+2))
done
if [ $n -ge 120 ]; then {
    loge "Consul unavailable, aborting"
    exit 1
}
fi

log "Consul is now available [${n}s], starting up Kibana"
# Wait till Logstash is available
log "Waiting for Logstash..."
until (curl -Ls --fail "${CONSUL}/v1/health/service/logstash?passing" | jq -e -r '.[0].Service.Address' >/dev/null); do
    sleep 10
done

log "Logstash is now available, configuring Kibana"
# Initialise Logstash index
echo "<30>$(date '+%b %d %H:%M:%S') $HOSTNAME startup: Initialising Logstash" | nc -w 60 syslog.service.consul 3164
replace
exit 0
