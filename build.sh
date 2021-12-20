#!/bin/bash

if [ -z "${RUBY_IMAGE_TAG}" ]; then
  echo "Error: \$RUBY_IMAGE_TAG is unset. Exiting."
  exit 64
fi

set -ev

docker pull ruby:${RUBY_IMAGE_TAG} # (needlessly mandatory to prevent a bug in Travis)

docker build . \
  --build-arg BASE_IMAGE_TAG=${RUBY_IMAGE_TAG} \
  --tag alpinelab/ruby-dev:${RUBY_IMAGE_TAG} \
  $(
    for alias in ${ALIAS_TAGS//,/ }; do
      echo "--tag alpinelab/ruby-dev:${alias}"
    done
  )
