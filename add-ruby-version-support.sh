#!/usr/bin/env bash
set -Eeuo pipefail

HERE="$(dirname $(readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}"))"

pushd () { command pushd "$@" > /dev/null ; }
popd  () { command popd  "$@" > /dev/null ; }

[[ $(uname -s) = "Darwin" ]] && SED_I_OPTION="-i ''" || SED_I_OPTION="-i"

pushd "${HERE}"
  version="$@"
  git checkout -q latest
  git pull -q origin latest
  git checkout -q -b "ruby-${version}"
  sed ${SED_I_OPTION} "1 s/^FROM ruby:.*\$/FROM ruby:${version}/" Dockerfile
  git commit Dockerfile -m "Change Ruby version to ${version}"
  git push -u origin "ruby-${version}"
popd
