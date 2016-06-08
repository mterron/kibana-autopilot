#!/bin/ash
log() {
	printf "[INFO] preStart: %s\n" "$@"
}
loge() {
	printf "[ERR] preStart: %s\n" "$@"
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
# Check that CONSUL_HTTP_ADDR environment variable exists
if [[ -z ${CONSUL_HTTP_ADDR} ]]; then
	loge "Missing CONSUL_HTTP_ADDR environment variable"
	exit 1
fi

# Wait up to 2 minutes for Consul to be available
log "Waiting for Consul availability..."
n=0
until [ $n -ge 120 ]||(curl -E /etc/tls/client_certificate.crt -fsL --connect-timeout 1 "${CONSUL_HTTP_ADDR}/v1/status/leader" &> /dev/null); do
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
log "Waiting for Elasticsearch..."
until (curl -E /etc/tls/client_certificate.crt -Ls --fail "${CONSUL_HTTP_ADDR}/v1/health/service/elasticsearch-data?passing" | jq -e -r '.[0].Service.Address' >/dev/null); do
	sleep 10
done

log "Elasticsearch is now available, configuring Kibana"
# Initialise Logstash index
echo "<30>$(date '+%b %d %H:%M:%S') $HOSTNAME startup: Initialising Logstash" | nc -w 60 syslog.service.consul 3164
replace
exit 0
