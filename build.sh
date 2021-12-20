#!/bin/bash

if [ -z "${RUBY_VERSION}" ]; then
  echo "Error: \$RUBY_VERSION is unset. Exiting."
  exit 64
fi

set -ev

docker build . \
  --build-arg BASE_IMAGE_TAG=${RUBY_VERSION} \
  --tag alpinelab/ruby-dev:${RUBY_VERSION} \
  $(
    for alias in ${ALIAS//,/ }; do
      echo "--tag alpinelab/ruby-dev:${alias}"
    done
  )
