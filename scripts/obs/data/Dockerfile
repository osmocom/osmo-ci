FROM	debian:bullseye
ARG	UID

RUN	apt-get update && \
	apt-get upgrade -y && \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		gnupg2 \
		&& \
	apt-get clean

COPY	Release.key /tmp/Release.key
RUN	apt-key add /tmp/Release.key && \
	rm /tmp/Release.key && \
	echo "deb https://downloads.osmocom.org/packages/osmocom:/latest/Debian_11/ ./" \
		> /etc/apt/sources.list.d/osmocom-latest.list

RUN	apt-get update && \
	apt-get upgrade -y && \
	apt-get install -y --no-install-recommends \
		debhelper \
		dh-python \
		dpkg-dev \
		fakeroot \
		git \
		git-review \
		meson \
		osc \
		python3-setuptools \
		rebar3 \
		sed \
		&& \
	apt-get clean

RUN	useradd --uid=${UID} -m user
USER	user
