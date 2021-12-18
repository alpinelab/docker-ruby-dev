ARG BASE_IMAGE_TAG=latest

FROM ruby:${BASE_IMAGE_TAG}

LABEL maintainer "Michael Baudino <michael.baudino@alpine-lab.com>"

# Explicitely define locale
# as advised in https://github.com/docker-library/docs/blob/master/ruby/content.md#encoding
ENV LANG="C.UTF-8"

# Define dependencies base versions
ENV RUBYGEMS_VERSION="3.2.26" \
    BUNDLER_VERSION="2.2.26" \
    NODE_VERSION="15" \
    GOSU_VERSION="1.14"

# Define some default variables
ENV PORT="5000" \
    BUNDLE_PATH="/bundle" \
    BUNDLE_BIN="/bundle/bin" \
    BUNDLE_APP_CONFIG="/bundle" \
    GEM_HOME="/bundle/global" \
    PATH="/bundle/bin:/bundle/global/bin:${PATH}" \
    HISTFILE="/config/.bash_history" \
    GIT_COMMITTER_NAME="Just some fake name to be able to git-clone" \
    GIT_COMMITTER_EMAIL="whatever@this-user-is-not-supposed-to-git-push.anyway" \
    DISABLE_SPRING="true"

# Install APT dependencies
RUN sed -i '/jessie-updates/d' /etc/apt/sources.list \
 && apt-get update \
 && apt-get install --assume-yes --no-install-recommends --no-install-suggests \
      apt-transport-https \
      lsb-release \
 && releaseCodename=$(lsb_release -cs) \
 && if [ "${releaseCodename}" = "jessie" ]; then \
      apt-get install --assume-yes --no-install-recommends --no-install-suggests \
        ca-certificates \
        curl \
        libssl1.0.0 \
      && sed -i 's|mozilla/DST_Root_CA_X3.crt|!mozilla/DST_Root_CA_X3.crt|g' /etc/ca-certificates.conf \
      && update-ca-certificates; \
    fi \
 && curl -sSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg \
 && if [ "${releaseCodename}" = "jessie" ]; then \
      echo "deb https://apt-archive.postgresql.org/pub/repos/apt ${releaseCodename}-pgdg-archive main" > /etc/apt/sources.list.d/pgdg.list; \
    else \
      echo "deb https://apt.postgresql.org/pub/repos/apt/ ${releaseCodename}-pgdg main" > /etc/apt/sources.list.d/pgdg.list; \
    fi \
 && curl -sSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor > /etc/apt/trusted.gpg.d/apt.nodesource.com.gpg \
 && echo "deb https://deb.nodesource.com/node_${NODE_VERSION}.x ${releaseCodename} main" > /etc/apt/sources.list.d/nodesource.list \
 && curl -sSL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor > /etc/apt/trusted.gpg.d/apt.yarnpkg.com.gpg \
 && echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list \
 && curl -sSL https://cli-assets.heroku.com/apt/release.key | gpg --dearmor > /etc/apt/trusted.gpg.d/apt.heroku.com.gpg \
 && echo "deb https://cli-assets.heroku.com/branches/stable/apt ./" > /etc/apt/sources.list.d/heroku.list \
 && apt-get update \
 && apt-get install --assume-yes --no-install-recommends --no-install-suggests \
      heroku \
      jq \
      nano \
      nodejs \
      postgresql-client \
      vim \
      yarn \
 && rm -rf /var/lib/apt/lists/*

# Install `gosu`
RUN export GNUPGHOME="$(mktemp -d)" dpkgArch="$(dpkg --print-architecture | cut -d- -f1)" \
 && for keyserver in $(shuf -e keys.gnupg.net ha.pool.sks-keyservers.net hkp://p80.pool.sks-keyservers.net:80 keyserver.ubuntu.com pgp.mit.edu); do \
      gpg --batch --no-tty --keyserver "$keyserver" --recv-keys "B42F6819007F00F88E364FD4036A9C25BF357DD4" && break || :; \
    done \
 && curl -sSL -o /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-${dpkgArch}" \
 && curl -sSL "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-${dpkgArch}.asc" | gpg --batch --verify - /usr/local/bin/gosu \
 && chmod +x /usr/local/bin/gosu \
 && rm -rf "${GNUPGHOME}"

# Install GEM dependencies
# Note: we still need Bundler 1.x because Bundler auto-switches to it when it encounters a Gemfile.lock with BUNDLED WITH 1.x
RUN gem update --system ${RUBYGEMS_VERSION} \
 && gem install bundler:${BUNDLER_VERSION} \
 && gem install bundler:1.17.3

# Add dot files to the home directory skeleton (they persist IRB/Pry/Rails console history, configure Yarn, etc…)
COPY dotfiles/* /etc/skel/

# Configure the main working directory.
WORKDIR /app

# Expose listening port to the Docker host, so we can access it from the outside.
EXPOSE ${PORT}

# Use entrypoints that switch to unprivileged user, install foreman, install dependencies (bundler & yarn), and fix a Rails server issue
COPY entrypoints/* /usr/local/bin/
ENTRYPOINT ["gosu-entrypoint", "foreman-entrypoint", "bundler-entrypoint", "yarn-entrypoint", "rails-entrypoint"]

# The main command to run when the container starts is to start whatever the Procfile defines
CMD ["foreman", "start", "-m", "all=1,release=0"]
