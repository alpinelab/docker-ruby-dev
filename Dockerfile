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

# Install apt based dependencies
RUN sed -i 's/^deb-src/# deb-src/' /etc/apt/sources.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends --no-install-suggests \
      build-essential \
      postgresql-client \
      nodejs \
 && rm -rf /var/lib/apt/lists/*

# Install some global gems
RUN gem install bundler foreman

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
