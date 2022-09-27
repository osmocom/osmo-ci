# Optimization: installing osmo-gsm-manuals-dev and its many, many dependencies
# takes quite a long time - sometimes longer than building the package itself
# (related: OS#4132). Instead of doing this every time before starting a build,
# here is a second docker container that already has it installed. This gets
# used by build_binpkg.py in case the package to build depends on
# osmo-gsm-manuals-dev and the build is done for Debian. Note that right now we
# don't build the manuals for rpm-based distributions.
ARG	DISTRO_FROM
FROM	${DISTRO_FROM}
ARG	DISTRO

RUN	case "$DISTRO" in \
	debian*) \
		apt-get update && \
		apt-get install -y --no-install-recommends \
			osmo-gsm-manuals-dev \
			&& \
		apt-get clean \
		;; \
	esac
