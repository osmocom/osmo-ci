# Change distro in lib/config.py:docker_distro_default
ARG	DISTRO_FROM
FROM	${DISTRO_FROM}
ARG	UID

RUN	apt-get update && \
	apt-get upgrade -y && \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		colordiff \
		debhelper \
		dh-python \
		dpkg-dev \
		fakeroot \
		git \
		git-review \
		gnupg2 \
		libxml2-utils \
		meson \
		osc \
		python3-packaging \
		python3-setuptools \
		rebar3 \
		sed \
		&& \
	apt-get clean

RUN	useradd --uid=${UID} -m user
USER	user
