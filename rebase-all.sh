#!/usr/bin/env bash

set -Eeuo pipefail

THIS_SCRIPT_PATH="$(dirname $(readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}"))"
THIS_SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

pushd () { command pushd "$@" > /dev/null ; }
popd  () { command popd  "$@" > /dev/null ; }

pushd "${THIS_SCRIPT_PATH}"
  git checkout -q latest
  git pull -q origin latest

  for branch in $(git for-each-ref --format='%(refname:short)' refs/heads/ | grep -v '^latest$'); do
    echo "Rebasing branch ${branch}"
    git checkout -q ${branch}
    git pull -q origin ${branch}
    GIT_EDITOR=true git rebase -q latest
    git push -q -f origin ${branch}
  done

  git checkout -q latest
popd
