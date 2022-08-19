ARG	DISTRO_FROM
FROM	${DISTRO_FROM}
ARG	DISTRO
ARG	UID

COPY	Release.key /tmp/Release.key

RUN	useradd --uid=${UID} -m user

# Only install build-essential here, and what's needed to add the Osmocom
# repository. Everything else must be defined as dependency in the package
# build recipe. For rpm-based distributions, there is no build-essential or
# similar package. Instead add relevant packages from prjconf, e.g.:
# https://build.opensuse.org/projects/CentOS:CentOS-8/prjconf
RUN	case "$DISTRO" in \
	debian*) \
		apt-get update && \
		apt-get install -y --no-install-recommends \
			build-essential \
			ca-certificates \
			fakeroot \
			git \
			gnupg2 \
			&& \
		apt-get clean \
		;; \
	centos*) \
		dnf -y install \
			autoconf \
			automake \
			binutils \
			dnf-utils \
			gcc \
			gcc-c++ \
			glibc-devel \
			libtool \
			make \
			redhat-rpm-config \
			rpm-build \
			rpmdevtools \
			wget && \
		yum config-manager --set-enabled powertools && \
		su user -c rpmdev-setuptree \
		;; \
	esac

# Add master repository, where packages immediately get updated after merging
# patches to master.
RUN	case "$DISTRO" in \
	debian:11) \
		apt-key add /tmp/Release.key && \
		rm /tmp/Release.key && \
		echo "deb https://downloads.osmocom.org/packages/osmocom:/master/Debian_11/ ./" \
			> /etc/apt/sources.list.d/osmocom-master.list \
		;; \
	centos:8) \
		{ echo "[network_osmocom_master]"; \
		  echo "name=Nightly packages of the Osmocom project (CentOS_8)"; \
		  echo "type=rpm-md"; \
		  echo "baseurl=https://downloads.osmocom.org/packages/osmocom:/master/CentOS_8/"; \
		  echo "gpgcheck=1"; \
		  echo "gpgkey=https://downloads.osmocom.org/packages/osmocom:/master/CentOS_8/repodata/repomd.xml.key"; \
		  echo "enabled=1"; \
		} > /etc/yum.repos.d/network:osmocom:master.repo \
		;; \
	*) \
		echo "can't install repo for $DISTRO" && \
		exit 1 \
		;; \
	esac

WORKDIR	/obs/
