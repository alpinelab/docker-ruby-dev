FROM ruby:2.5

LABEL maintainer "Michael Baudino <michael.baudino@alpine-lab.com>"

# Explicitely define locale
# as advised in https://github.com/docker-library/docs/blob/master/ruby/content.md#encoding
ENV LANG="C.UTF-8"

# Define dependencies base versions
ENV NODEJS_VERSION="8.9.4" \
    YARN_VERSION="1.3.2" \
    FOREMAN_VERSION="0.84.0" \
    HEROKU_CLI_VERSION="6.15.26" \
    RUBYGEMS_VERSION="2.7.6"

# Define dependencies package-manager versions
ENV NODEJS_APT_VERSION="${NODEJS_VERSION}-1nodesource1" \
    YARN_APT_VERSION="${YARN_VERSION}-1" \
    HEROKU_CLI_APT_VERSION="${HEROKU_CLI_VERSION}-1"

# Define some default variables
ENV PORT="5000" \
    BUNDLE_PATH="/bundle" \
    BUNDLE_BIN="/bundle/bin" \
    BUNDLE_APP_CONFIG="/bundle" \
    PATH="/app/bin:/bundle/bin:${PATH}" \
    HISTFILE="/config/.bash_history" \
    GIT_COMMITTER_NAME="Just some fake name to be able to git-clone" \
    GIT_COMMITTER_EMAIL="whatever@this-user-is-not-supposed-to-git-push.anyway"

# Install APT dependencies
RUN apt-get update \
 && apt-get install --assume-yes --no-install-recommends --no-install-suggests \
      apt-transport-https \
      lsb-release \
 && echo "deb https://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
 && curl --silent https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
 && echo "deb https://deb.nodesource.com/node_8.x $(lsb_release -cs) main" > /etc/apt/sources.list.d/nodesource.list \
 && curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - \
 && echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list \
 && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
 && echo "deb https://cli-assets.heroku.com/branches/stable/apt ./" > /etc/apt/sources.list.d/heroku.list \
 && curl -sS https://cli-assets.heroku.com/apt/release.key | apt-key add - \
 && apt-get update \
 && apt-get install --assume-yes --no-install-recommends --no-install-suggests \
      heroku=${HEROKU_CLI_APT_VERSION} \
      nano \
      nodejs=${NODEJS_APT_VERSION} \
      postgresql-client-10 \
      vim \
      yarn=${YARN_APT_VERSION} \
 && rm -rf /var/lib/apt/lists/*

# Install GEM dependencies
RUN gem update --system ${RUBYGEMS_VERSION} \
 && gem install \
      foreman:${FOREMAN_VERSION}

# Add dot files to home directory (to persist IRB/Pry/Rails console history, to configure Yarn, etc…)
COPY dotfiles/* /root/

# Configure the main working directory.
WORKDIR /app

# Expose listening port to the Docker host, so we can access it from the outside.
EXPOSE ${PORT}

# Use wrappers that check and maintain Ruby & JS dependencies (if necessary) as entrypoint
COPY bin/* /usr/local/bin/
ENTRYPOINT ["bundler-wrapper", "yarn-wrapper"]

# The main command to run when the container starts is to start whatever the Procfile defines
CMD ["foreman", "start"]
