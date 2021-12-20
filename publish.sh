#!/bin/bash

if [ -z "${RUBY_VERSION}" ]; then
  echo "Error: \$RUBY_VERSION is unset. Exiting."
  exit 64
fi

set -ev

# Publish default name
docker push alpinelab/ruby-dev:${RUBY_VERSION}

# Publish aliases
for alias in ${ALIAS//,/ }; do
  docker push alpinelab/ruby-dev:${alias}
done
