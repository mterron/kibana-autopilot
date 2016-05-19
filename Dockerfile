FROM alpine:3.3

# Alpine packages
RUN echo http://dl-6.alpinelinux.org/alpine/v3.3/community >> /etc/apk/repositories &&\
	apk upgrade --update &&\
	apk -f -q --no-progress --no-cache add \
		curl \
		bash \
		ca-certificates \
		jq \
		libcap \
		nodejs \
		openssl \
		su-exec \
		tzdata

# We don't need to expose these ports in order for other containers on Triton
# to reach this container in the default networking environment, but if we
# leave this here then we get the ports as well-known environment variables
# for purposes of linking.
EXPOSE 5601

WORKDIR /tmp
# Add Containerpilot and set its configuration path
ENV CONTAINERPILOT_VERSION=2.1.2 \
	CONTAINERPILOT=file:///etc/containerpilot/containerpilot.json
ADD https://github.com/joyent/containerpilot/releases/download/${CONTAINERPILOT_VERSION}/containerpilot-${CONTAINERPILOT_VERSION}.tar.gz /tmp/
ADD	https://github.com/joyent/containerpilot/releases/download/${CONTAINERPILOT_VERSION}/containerpilot-${CONTAINERPILOT_VERSION}.sha1.txt /tmp/
RUN	sha1sum -sc containerpilot-${CONTAINERPILOT_VERSION}.sha1.txt &&\
	mkdir -p /opt/containerpilot &&\
	tar xzf containerpilot-${CONTAINERPILOT_VERSION}.tar.gz -C /opt/containerpilot/ &&\
	rm -f containerpilot-${CONTAINERPILOT_VERSION}.*

# get Kibana release
ENV KIBANA_VERSION=4.5.0
ADD	https://download.elastic.co/kibana/kibana/kibana-${KIBANA_VERSION}-linux-x64.tar.gz /tmp/
RUN mkdir -p /opt && \
	tar xzf /tmp/kibana-${KIBANA_VERSION}-linux-x64.tar.gz &&\
	mv -f kibana-${KIBANA_VERSION}-linux-x64/ /opt/kibana &&\
	rm -f kibana-${KIBANA_VERSION}-linux-x64.tar.gz &&\
	rm -f /opt/kibana/node/bin/node &&\
	ln -sf /usr/bin/node /opt/kibana/node/bin


# Create and take ownership over required directories
# Copy internal CA certificate bundle.
COPY ca.pem /etc/ssl/private/
# Create and take ownership over required directories, update CA
RUN adduser -D -H -g kibana kibana &&\
	adduser kibana kibana &&\
	chown -R kibana:kibana /opt &&\
	mkdir -p /etc/containerpilot &&\
	chmod -R g+w /etc/containerpilot &&\
	chown -R kibana:kibana /etc/containerpilot &&\
	$(cat /etc/ssl/private/ca.pem >> /etc/ssl/certs/ca-certificates.crt;exit 0)

ENV PATH=$PATH:/opt/kibana/bin

# Add our configuration files and scripts
COPY bin/* /usr/local/bin/
COPY containerpilot.json /etc/containerpilot/containerpilot.json

USER kibana
CMD ["/usr/local/bin/startup.sh"]
