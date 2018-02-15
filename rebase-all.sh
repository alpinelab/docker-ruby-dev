#!/usr/bin/env bash

set -Eeuo pipefail

THIS_SCRIPT_PATH="$(dirname $(readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}"))"
THIS_SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

pushd () { command pushd "$@" > /dev/null ; }
popd  () { command popd  "$@" > /dev/null ; }

pushd "${THIS_SCRIPT_PATH}"
  # Make sure all remote branches are tracked
  git branch --remotes | grep -v '\->' | while read remote; do
    branch="${remote#origin/}"
    git rev-parse --quiet --verify "${branch}" > /dev/null \
      && git branch --quiet --set-upstream-to="${remote}" "${branch}" \
      || git branch --quiet --track "${branch}" "${remote}"
  done

  # Update all branches
  git pull --all --quiet

  # Rebase each branch on `latest`
  for branch in $(git for-each-ref --format='%(refname:short)' refs/heads/ | grep -v '^latest$'); do
    echo "Rebasing branch ${branch}"
    git checkout --quiet ${branch}
    git pull --quiet origin ${branch}
    GIT_EDITOR=true git rebase --quiet --strategy=recursive --strategy-option=theirs latest
    git push --quiet --force origin ${branch}
  done

  git checkout -q latest
popd
