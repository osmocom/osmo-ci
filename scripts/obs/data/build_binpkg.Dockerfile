ARG	DISTRO_FROM
FROM	${DISTRO_FROM}
ARG	DISTRO
ARG	FEED
ARG	UID

COPY	Release.key /usr/share/keyrings/osmocom.asc

RUN	set -x && \
	if id "${UID}" >/dev/null 2>&1; then \
		userdel "$(getent passwd "${UID}" | cut -d: -f1)"; \
	fi && \
	useradd --uid=${UID} -m user

# Only install build-essential here, and what's needed to add the Osmocom
# repository. Everything else must be defined as dependency in the package
# build recipe. For rpm-based distributions, there is no build-essential or
# similar package. Instead add relevant packages from prjconf, e.g.:
# https://build.opensuse.org/projects/CentOS:CentOS-8/prjconf
# For debian, make sure we don't have man pages as otherwise it takes some time
# to regenerate the manuals database when installing build dependencies.
# SYS#5818: using almalinux:8 instead of centos:8
RUN	case "$DISTRO" in \
	debian*|ubuntu*) \
		echo "path-exclude=/usr/share/man/*" \
			> /etc/dpkg/dpkg.cfg.d/exclude-man-pages && \
		rm -rf /usr/share/man/ && \
		mkdir -p /usr/share/man/man1/ && \
		apt-get update && \
		apt-get install -y --no-install-recommends \
			build-essential \
			ca-certificates \
			fakeroot \
			git \
			gnupg2 \
			iproute2 \
			&& \
		apt-get clean \
		;; \
	almalinux*) \
		dnf -y install \
			autoconf \
			automake \
			binutils \
			dnf-utils \
			gcc \
			gcc-c++ \
			glibc-devel \
			iproute \
			libtool \
			make \
			redhat-rpm-config \
			rpm-build \
			rpmdevtools \
			wget && \
		yum config-manager --set-enabled powertools && \
		su user -c rpmdev-setuptree \
		;; \
	centos:7) \
		set -x && \
		sed -i 's/mirror.centos.org/vault.centos.org/g' /etc/yum.repos.d/*.repo && \
		sed -i 's/^#.*baseurl=http/baseurl=http/g' /etc/yum.repos.d/*.repo && \
		sed -i 's/^mirrorlist=http/#mirrorlist=http/g' /etc/yum.repos.d/*.repo && \
		\
		yum -y install \
			autoconf \
			automake \
			binutils \
			dnf-utils \
			gcc \
			gcc-c++ \
			glibc-devel \
			iproute \
			libtool \
			make \
			redhat-rpm-config \
			rpm-build \
			rpmdevtools \
			wget && \
		su user -c rpmdev-setuptree \
		;; \
	esac

# Add master repository, where packages immediately get updated after merging
# patches to master.
# sed: first letter uppercase (testing -> Testing)
RUN	set -x; \
	VERSION="$(echo "$DISTRO" | cut -d : -f 2 | sed 's/./\u&/')"; \
	case "$DISTRO" in \
	debian:*) \
		echo "deb [signed-by=/usr/share/keyrings/osmocom.asc] https://downloads.osmocom.org/packages/osmocom:/$FEED/Debian_$VERSION/ ./" \
			> /etc/apt/sources.list.d/osmocom-$FEED.list \
		;; \
	ubuntu:*) \
		echo "deb [signed-by=/usr/share/keyrings/osmocom.asc] https://downloads.osmocom.org/packages/osmocom:/$FEED/xUbuntu_$VERSION/ ./" \
			> /etc/apt/sources.list.d/osmocom-$FEED.list \
		;; \
	almalinux:*|centos:*) \
		{ echo "[network_osmocom_$FEED]"; \
		  echo "name=osmocom:$FEED"; \
		  echo "type=rpm-md"; \
		  echo "baseurl=https://downloads.osmocom.org/packages/osmocom:/$FEED/CentOS_$VERSION/"; \
		  echo "gpgcheck=1"; \
		  echo "gpgkey=https://downloads.osmocom.org/packages/osmocom:/$FEED/CentOS_$VERSION/repodata/repomd.xml.key"; \
		  echo "enabled=1"; \
		} > /etc/yum.repos.d/network:osmocom:$FEED.repo \
		;; \
	*) \
		echo "can't install repo for $DISTRO" && \
		exit 1 \
		;; \
	esac

WORKDIR	/obs/
