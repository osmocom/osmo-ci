# Change distro in lib/config.py:docker_distro_default
ARG	DISTRO_FROM
FROM	${DISTRO_FROM}
ARG	UID

# default-libmysqlclient-dev: needed for fetching the source package
# "mysqlclient" with pip that PyHSS depends on. Pip actually compiles the
# package to figure out its dependency tree and aborts if libmysqlclient-dev is
# missing (https://github.com/pypa/pip/issues/1884).
RUN	apt-get update && \
	apt-get upgrade -y && \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		colordiff \
		debhelper \
		default-libmysqlclient-dev \
		dh-python \
		dh-virtualenv \
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
		pkgconf \
		python3-packaging \
		python3-pip \
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
