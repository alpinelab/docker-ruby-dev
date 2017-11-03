FROM ruby:2.2.4

LABEL maintainer "Michael Baudino <michael.baudino@alpine-lab.com>"

# Explicitely define locale
# as advised in https://github.com/docker-library/docs/blob/master/ruby/content.md#encoding
ENV LANG="C.UTF-8"

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
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ jessie-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
 && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
 && apt-get update \
 && apt-get install -y --no-install-recommends --no-install-suggests \
      nodejs \
      postgresql-client-9.5 \
      nano \
      vim \
 && rm -rf /var/lib/apt/lists/*

# Install GEM dependencies
RUN gem update --system 2.6.13 \
 && gem install \
      bundler:1.16.0 \
      foreman:0.84.0

# Persist IRB/Pry/Rails console history
ADD .irbrc .pryrc /root/

# Configure the main working directory.
WORKDIR /app

# Expose listening port to the Docker host, so we can access it from the outside.
EXPOSE ${PORT}

# Use a bundle wrapper as entrypoint which runs `bundle install` if necessary.
COPY bundler-wrapper /usr/local/bin/
ENTRYPOINT ["bundler-wrapper"]

# The main command to run when the container starts.
CMD ["foreman", "start"]
