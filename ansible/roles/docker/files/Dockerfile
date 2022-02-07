ARG	REGISTRY=docker.io
FROM	${REGISTRY}/alpine:3.15
ARG	DOCKER_GID

RUN	apk add \
		cargo \
		docker-cli

# Create user and docker group with same group-id as on host system, create
# /opt/docuum dir owned by user
RUN	set -x && \
	delgroup $(getent group "${DOCKER_GID}" | cut -d: -f1) && \
	addgroup -g "${DOCKER_GID}" docker && \
	adduser -D -u 1000 -G docker user && \
	mkdir /opt/docuum && \
	chown user /opt/docuum

USER	user

ARG	DOCUUM_VER=0.20.4

RUN	set -x && \
	cd /opt/docuum && \
	wget https://github.com/stepchowfun/docuum/archive/refs/tags/v${DOCUUM_VER}.tar.gz \
		-O docuum.tar.gz && \
	tar -xf docuum.tar.gz && \
	cd docuum-${DOCUUM_VER} && \
	cargo build --release && \
	cd .. && \
	mv docuum-${DOCUUM_VER}/target/release/docuum . && \
	rm -rf ~/.cargo docuum-${DOCUUM_VER} docuum.tar.gz
