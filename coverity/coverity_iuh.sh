#!/usr/bin/env bash

set -e -x

export PATH=~/coverity/cov-analysis-linux64-8.5.0/bin/:$PATH

rm -rf sources-iuh/cov-int
cov-build --dir sources-iuh/cov-int ./build_iuh.sh
cd sources-iuh
tar czf myproject.tgz cov-int

	curl \
		--form token="$(../get_token.sh ../tokens.txt iuh)" \
		--form email=holger@freyther.de --form file=@myproject.tgz \
		--form version=Version --form description=AutoUpload \
		https://scan.coverity.com/builds?project=Osmocom
