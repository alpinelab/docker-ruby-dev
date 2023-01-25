# syntax=docker/dockerfile:1

ARG BASE_IMAGE_TAG=latest

FROM ruby:${BASE_IMAGE_TAG}

LABEL maintainer "Michael Baudino <michael.baudino@alpine-lab.com>"

# Explicitely define locale
# as advised in https://github.com/docker-library/docs/blob/master/ruby/content.md#encoding
ENV LANG="C.UTF-8"

# Define dependencies base versions
ENV RUBYGEMS_VERSION="3.4.5" \
    BUNDLER_VERSION="2.4.5" \
    NODE_VERSION="16" \
    GOSU_VERSION="1.16"

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

# Install dependencies
RUN set -eux; \
    osType="$(sed -n 's|^ID=||p' /etc/os-release)"; \
    \
    case "${osType}" in \
      alpine) \
        alpineMajorVersion=$(sed -nr 's/^VERSION_ID=(\d+\.\d+).*/\1/p' /etc/os-release); \
        \
        # Use `libpq-dev` (~20MB) rather than `postgresql-dev` (~200MB) if available
        # (the former was extracted from the latter in Alpine 3.15)
        case ${alpineMajorVersion} in \
          3.3|3.4|3.5|3.6|3.7|3.8|3.9|3.10|3.11|3.12|3.13|3.14) libpqPackage="postgresql-dev" ;; \
          3.15|*) libpqPackage="libpq-dev" ;; \
        esac; \
        \
        apk add --no-cache \
          alpine-sdk \
          openssh \
          jq \
          nano \
          nodejs \
          postgresql \
          vim \
          yarn \
          ${libpqPackage} \
        ; \
      ;; \
      \
      debian|ubuntu) \
        # Fix Jessie APT sources
        sed -i '/jessie-updates/d' /etc/apt/sources.list; \
        \
        # Install some prerequisites
        apt-get update; \
        apt-get install --assume-yes --no-install-recommends --no-install-suggests \
          apt-transport-https \
          lsb-release \
        ; \
        debianReleaseCodename=$(lsb_release -cs); \
        \
        # Fix LetsEncrypt expired CA on older Debian releases
        case ${debianReleaseCodename} in \
          jessie|buster|stretch) \
            apt-get install --assume-yes --no-install-recommends --no-install-suggests \
              ca-certificates \
              curl \
              $([ "${debianReleaseCodename}" = "jessie" ] && echo libssl1.0.0) \
            ; \
            sed -i 's|mozilla/DST_Root_CA_X3.crt|!mozilla/DST_Root_CA_X3.crt|g' /etc/ca-certificates.conf; \
            update-ca-certificates; \
          ;; \
        esac; \
        \
        # Add PostgreSQL APT reposiroty
        curl -sSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg; \
        case ${debianReleaseCodename} in \
          jessie) echo "deb https://apt-archive.postgresql.org/pub/repos/apt ${debianReleaseCodename}-pgdg-archive main" ;; \
          *) echo "deb https://apt.postgresql.org/pub/repos/apt/ ${debianReleaseCodename}-pgdg main" ;; \
        esac > /etc/apt/sources.list.d/pgdg.list; \
        \
        # Add NodeJS APT repository
        curl -sSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor > /etc/apt/trusted.gpg.d/apt.nodesource.com.gpg; \
        case ${debianReleaseCodename} in \
          jessie) echo "deb https://deb.nodesource.com/node_14.x ${debianReleaseCodename} main" ;; \
          *) echo "deb https://deb.nodesource.com/node_${NODE_VERSION}.x ${debianReleaseCodename} main" ;; \
        esac > /etc/apt/sources.list.d/nodesource.list; \
        \
        # Add Yarn APT repository
        curl -sSL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor > /etc/apt/trusted.gpg.d/apt.yarnpkg.com.gpg; \
        echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list; \
        \
        # Add Heroku APT repository
        curl -sSL https://cli-assets.heroku.com/apt/release.key | gpg --dearmor > /etc/apt/trusted.gpg.d/apt.heroku.com.gpg; \
        echo "deb https://cli-assets.heroku.com/branches/stable/apt ./" > /etc/apt/sources.list.d/heroku.list; \
        \
        # Install everything
        apt-get update; \
        apt-get install --assume-yes --no-install-recommends --no-install-suggests \
          heroku \
          jq \
          nano \
          nodejs \
          postgresql-client \
          vim \
          yarn \
        ; \
        \
        # Cleanup
        rm -rf /var/lib/apt/lists/*; \
      ;; \
    esac;

# Install `gosu`
ARG TARGETARCH
RUN set -eux; \
    osType="$(sed -n 's|^ID=||p' /etc/os-release)"; \
    export GNUPGHOME="$(mktemp -d)"; \
    \
    # Install GPG on Alpine (for signature verification)
    [ "${osType}" = "alpine" ] && apk add --no-cache --virtual .gosu-deps gnupg || :; \
    \
    # Fetch author public key
    for keyserver in $(shuf -e keys.gnupg.net ha.pool.sks-keyservers.net hkp://p80.pool.sks-keyservers.net:80 keyserver.ubuntu.com pgp.mit.edu); do \
      gpg --batch --no-tty --keyserver "${keyserver}" --recv-keys "B42F6819007F00F88E364FD4036A9C25BF357DD4" && break || :; \
    done; \
    \
    # Download binary
    curl -sSL -o /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-${TARGETARCH}"; \
    chmod +x /usr/local/bin/gosu; \
    \
    # Verify binary signature
    curl -sSL "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-${TARGETARCH}.asc" \
      | gpg --batch --verify - /usr/local/bin/gosu; \
    \
    # Cleanup
    command -v gpgconf && gpgconf --kill all || :; \
    rm -rf "${GNUPGHOME}"; \
    unset -v GNUPGHOME; \
    [ "${osType}" = "alpine" ] && apk del --no-network .gosu-deps || :;

# Install GEM dependencies
# Note: we still need Bundler 1.x because Bundler auto-switches to it when it encounters a Gemfile.lock with BUNDLED WITH 1.x
RUN gem update --system ${RUBYGEMS_VERSION} \
 && gem install bundler:${BUNDLER_VERSION} \
 && gem install bundler:1.17.3

# Add dot files to the home directory skeleton (they persist IRB/Pry/Rails console history, configure Yarn, etc…)
COPY dotfiles/* /etc/skel/

# Create expected mount points
RUN mkdir -p /app /bundle /config

# Configure the main working directory.
WORKDIR /app

# Expose listening port to the Docker host, so we can access it from the outside.
EXPOSE ${PORT}

# Use entrypoints that switch to unprivileged user, install foreman, install dependencies (bundler & yarn), and fix a Rails server issue
COPY entrypoints/* /usr/local/bin/
ENTRYPOINT ["gosu-entrypoint", "foreman-entrypoint", "bundler-entrypoint", "yarn-entrypoint", "rails-entrypoint"]

# The main command to run when the container starts is to start whatever the Procfile defines
CMD ["foreman", "start", "-m", "all=1,release=0"]
