#!/bin/bash

set -ev

### Build

docker build . \
  --build-arg BASE_IMAGE_TAG=${RUBY_VERSION} \
  --tag alpinelab/ruby-dev:${RUBY_VERSION} \
  $(
    for alias in ${ALIAS//,/ }; do
      echo "--tag alpinelab/ruby-dev:${alias}"
    done
  )

### Publish

if [[ ${TRAVIS_BRANCH} = "master" && -z ${TRAVIS_PULL_REQUEST_BRANCH} ]]; then
  # Publish with base image name
  docker push alpinelab/ruby-dev:${RUBY_VERSION}
  # Publish as aliases
  for alias in ${ALIAS//,/ }; do
    docker push alpinelab/ruby-dev:${alias}
  done
else
  echo "This is not a commit on \`master\`: skip publishing.";
fi
