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
		erlang-nox \
		fakeroot \
		git \
		git-review \
		gnupg2 \
		libxml2-utils \
		lsb-release \
		meson \
		osc \
		python3-packaging \
		python3-setuptools \
		quilt \
		sed \
		sphinx-common \
		wget \
		&& \
	apt-get clean

# Install rebar3 as described in https://rebar3.org/docs/getting-started/
# instead of using the Debian package, as the latter pulls in ~600 MB of GUI
# dependencies that we don't need:
# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1083096
RUN	wget https://github.com/erlang/rebar3/releases/download/3.24.0/rebar3 -O /usr/bin/rebar3 && \
	echo "d2d31cfb98904b8e4917300a75f870de12cb5167cd6214d1043e973a56668a54  /usr/bin/rebar3" | sha256sum -c && \
	chmod +x /usr/bin/rebar3 && \
	rebar3 --version

RUN	useradd --uid=${UID} -m user
USER	user
