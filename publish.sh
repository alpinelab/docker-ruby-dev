#!/bin/bash

if [ -z "${RUBY_IMAGE_TAG}" ]; then
  echo "Error: \$RUBY_IMAGE_TAG is unset. Exiting."
  exit 64
fi

set -ev

# Publish default name
docker push alpinelab/ruby-dev:${RUBY_IMAGE_TAG}

# Publish aliases
for alias in ${ALIAS_TAGS//,/ }; do
  docker push alpinelab/ruby-dev:${alias}
done
