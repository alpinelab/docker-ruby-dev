#!/usr/bin/env bash

set -Eeuo pipefail

THIS_SCRIPT_PATH="$(dirname $(readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}"))"
THIS_SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
  c_reset='\033[0m'
  c_gray='\033[1;30m'
  c_red='\033[0;31m'
  c_green='\033[0;32m'
  c_yellow='\033[0;33m'
  c_blue='\033[0;34m'
  c_purple='\033[0;35m'
  c_cyan='\033[0;36m'
fi

pushd () { command pushd "$@" > /dev/null ; }
popd  () { command popd  "$@" > /dev/null ; }

success () { command echo -ne "${c_green}[success]${c_reset} "  && command echo -e $* ; }
info    () { command echo -ne "${c_blue}[info]${c_reset} "      && command echo -e $* ; }
warn    () { command echo -ne "${c_yellow}[warning]${c_reset} " && command echo -e $* ; }
error   () { command echo -ne "${c_red}[error]${c_reset} "      && command echo -e $* ; }
fail    () { command echo -ne "${c_red}[error]${c_reset} "      && command echo -e $* && exit 1 ; }

[[ $(uname -s) = "Darwin" ]] && SED_I_OPTION="-i ''" || SED_I_OPTION="-i"

if [[ $# -eq 0 || $1 = "-h" || $1 = "--help" ]]; then
  echo "Usage: ${THIS_SCRIPT_NAME} <version> [<alias>]"
  echo
  echo "For example: ${THIS_SCRIPT_NAME} 2.3.5 2.3"
  exit 64
fi

pushd "${THIS_SCRIPT_PATH}"
  version="$1"
  alias="${2:-}"
  echo "The following branch(es) and tag(s) will be created for Ruby ${version}:"
  echo "  ruby-${version}"
  [[ -n ${alias} ]] && echo "  ruby-${alias}"
  echo -ne "Press ${c_gray}ENTER${c_reset} to continue or ${c_gray}Ctrl+C${c_reset} to cancel"
  read

  info "Fetching latest code"
  git checkout -q latest
  git pull -q origin latest

  info "Creating version branch and tag"
  git checkout -q -b "ruby-${version}"
  sed ${SED_I_OPTION} "1 s/^FROM ruby:.*\$/FROM ruby:${version}/" Dockerfile
  git commit -q Dockerfile -m "Change Ruby version to ${version}"
  git tag -a "ruby-${version}" -m "For Ruby ${version}"
  git push -q -u origin "refs/heads/ruby-${version}" --tags

  if [[ -n ${alias} ]]; then
    git checkout -q latest
    if git rev-parse -q --verify "ruby-${alias}" > /dev/null; then
      previous_version=$( \
        git checkout -q "refs/heads/ruby-${alias}" ;\
        sed -n 's/^FROM ruby:\(.*\)/\1/p' Dockerfile ;\
        git checkout -q -
      )
      warn "Branch ruby-${alias} already exists and uses Ruby ${previous_version}."
      echo -ne "Press ${c_gray}ENTER${c_reset} to ${c_red}overwrite${c_reset} it or ${c_gray}Ctrl+C${c_reset} to cancel"
      read
    fi
    info "Creating alias branch and tag"
    git checkout -q -B "refs/heads/ruby-${alias}"
    sed ${SED_I_OPTION} "1 s/^FROM ruby:.*\$/FROM ruby:${version}/" Dockerfile
    git commit -q Dockerfile -m "Change Ruby version to ${version}"
    git tag -f -a "ruby-${alias}" -m "For Ruby ${alias} (${version}, exactly)"
    git push -q -f -u origin "refs/heads/ruby-${alias}" --tags
  fi

  git checkout -q latest
popd

success "Support for Ruby ${version} added 👍"
