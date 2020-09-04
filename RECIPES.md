# Recipes

You will find here some instructions, explanations, examples and code snippets to configure or customize the `alpinelab/ruby-dev` image.

Please refer to [README.md](README.md) for generic overview, setup and usage instructions.

<details>

  <summary>Table of contents</summary>

  * [Usage](#usage)
    * [creating a Rails application from scratch](#creating-a-rails-application-from-scratch)
    * [creating a gem from scratch](#creating-a-gem-from-scratch)
    * [using PostgreSQL](#using-postgresql)
    * [using Webpacker](#using-webpacker)
    * [using PGAdmin](#using-pgadmin)
    * [using MailCatcher](#using-mailcatcher)
  * [Configuration](#configuration):
    * [Heroku CLI authentication](#heroku-cli-authentication)
    * [Git authentication](#git-authentication)
    * [RubyGems authentication](#rubygems-authentication)
    * [Custom Yarn check command](#custom-yarn-check-command)
    * [Bundler 1.x](#bundler-1.x)
  * [Operations](#operations)
    * [Load a database dump](#load-a-database-dump)
    * [Fetch and load a Heroku database](#fetch-and-load-a-heroku-database)
  * [Customisation](#customisation):
    * [capybara-webkit](#capybara-webkit)
    * [wkhtmltopdf](#wkhtmltopdf)
    * [rails-erd](#rails-erd)
    * [phantomjs](#phantomjs)

</details>

## Usage

### Creating a Rails application from scratch

1. Create an empty directory to hold your project code:

    ```shell
    mkdir my_project
    ```

2. Create a default `docker-compose.yml` as described in the [`Setup` section of the `README`](https://github.com/alpinelab/docker-ruby-dev#setup)

3. Install Rails and generate your Rails application (it replaces the usual `gem install rails && rails new my_project` command that you will find in every documentation and tutorial out there):

    ```shell
    docker-compose run app bash -c "bundle init && bundle add rails && rails new . --force --skip-spring"
    ```

    > 💡 You can specify the Rails version you want by appending the [`--version` switch](https://bundler.io/v1.16/man/bundle-add.1.html#OPTIONS) to the `bundle add rails` command (_e.g._ `--version "~> 5.2.0"`).
    >
    > ℹ️ The `--force` switch passed to the `rails new` command will overwrite the first version of the `Gemfile` (used only to install `rake` and `rails`)
    >
    > ℹ️ The `--skip-spring` switch passed to the `rails new` command will prevent installing [Spring](https://github.com/rails/spring) because it makes no sense in a containerized environment (unless you want to [configure it on your host and configure it to manage containers](https://github.com/jonleighton/spring-docker-example) but it's out of the scope of this recipe and contradicts the purpose of this image).

4. Create a `Procfile` that starts the Rails server:

    ```
    web: bundle exec rails server -b 0.0.0.0
    ```

    > ⚠️ Whatever you do in this `Procfile`, always configure your servers to listen on `0.0.0.0` (`puma` [does it](https://github.com/puma/puma/blob/8dbc6eb6ed96b2cefa7092dd398ea2c0a4a0be80/lib/puma/configuration.rb#L10) by default but using `rails server` [forces it](https://github.com/rails/rails/blob/b10f371366a606310cab26648d798836e030bdc8/railties/lib/rails/commands/server/server_command.rb#L236) to listen to `localhost`, unless you override it again using the `-b|--binding` switch like above). Without it, you won't be able to connect to this server from outside the running container.

5. Run `docker-compose up app` as usual and you're [good to profit 🎉](http://localhost:5000).

### Creating a gem from scratch

1. Create an empty directory to hold your project code:

    ```shell
    mkdir my_project
    ```

2. Create a basic `docker-compose.yml` (even simpler than as described in the [`Setup` section of the `README`](https://github.com/alpinelab/docker-ruby-dev#setup) because it doesn't need any port:

    ```yaml
    version: "3"
    volumes:
      bundle: { driver: local }
      config: { driver: local }
    services:
      app:
        image: alpinelab/ruby-dev
        volumes:
          - .:/app
          - bundle:/bundle
          - config:/config
    ```

3. Generate your gem skeleton (it just needs to trick `bundler` to think that the current directory is available as a subdirectory named `my_project`):

    ```shell
    docker-compose run app bash -c "ln -s . my_project && bundle gem my_project && rm my_project"
    ```

### Using Webpacker

This is a minimal `docker-compose.yml` for a Rails application that uses [Webpacker](https://github.com/rails/webpacker):

```yaml
version: "3"
volumes:
  bundle: { driver: local }
  node_modules: { driver: local }
  config: { driver: local }
services:
  app:
    image: alpinelab/ruby-dev
    ports: ["5000:5000", "3035:3035"]
    volumes:
      - .:/app
      - bundle:/bundle
      - node_modules:/app/node_modules
      - config:/config
    environment:
      PORT: 3000
      WEBPACKER_DEV_SERVER_HOST: "0.0.0.0"
```

The important parts are:
* add `3035` to the `ports` exposed (it's used for `webpack-dev-server` websocket connection)
* add `WEBPACKER_DEV_SERVER_HOST: "0.0.0.0"` to `environment` variables to tell `webpack-dev-server` to bind on all interfaces (not only `localhost`)

Then, add a `Procfile.dev` file to start `webpack-dev-server` automatically:

```Procfile
web: bin/rails server -b 0.0.0.0 -p ${PORT:-5000}
webpack: bin/webpack-dev-server
```

Finally, add a `.foreman` fill to tell `foreman` to use your newly created `Procfile.dev` (without messing up with your production `Procfile`):

```
procfile: Procfile.dev
```

### Using PostgreSQL

This is a minimal configuration for a Ruby application that uses a [PostgreSQL](https://www.postgresql.org) server with persisted data:

```yaml
version: "3"
volumes:
  bundle:        { driver: local }
  config:        { driver: local }
  postgres-data: { driver: local }
services:
  app:
    image: alpinelab/ruby-dev
    volumes:
      - .:/app
      - bundle:/bundle
      - config:/config
    environment:
      DATABASE_URL: "postgres://postgres:password@postgres:5432"
    links:
      - postgres
  postgres:
    image: postgres
    volumes:
      - postgres-data:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD: password
```

Here is what it does:

* create a Docker volume to persist the databases:

    ```yaml
    postgres-data: { driver: local }
    ```

* create a service for the PostgreSQL server (that mounts this volume where it will store databases):

    ```yaml
    postgres:
      image: postgres
      volumes:
        - postgres-data:/var/lib/postgresql/data
      environment:
        POSTGRES_PASSWORD: password
    ```

* set fully qualified `DATABASE_URL` except database name (because it will differ in `development` and `test` environments):

    ```yaml
    environment:
      DATABASE_URL: "postgres://postgres:password@postgres:5432"
    ```

* link this server to the application service (`app`), so it will be started whenever it's needed and it can be accessed inside Docker network by its name (`postgres`):

    ```yaml
    links:
      - postgres
    ```

From within the Ruby application, the Postgres server is accessible at the fully-qualified URL `postgres://postgres:@postgres/<DATABASE_NAME>`, or using the following `config/database.yml` if you are using Rails:

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  url: <%= ENV["DATABASE_URL"] %>
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

development:
  <<: *default
  database: app_development

test:
  <<: *default
  database: app_test

production:
  <<: *default
```

> ℹ️ There is almost no risk of database name collision with other projects of yours since Docker Compose will create a different volume for each different `docker-compose.yml` file, hence the very generic database names used here.

> ℹ️ We explicitly set database names for `development` and `test` environments, since it is not defined in the fully-qualified URL provided by `docker-compose.yml`. In production, the URL provided will include the database name, thus we do not need (and do not want!) to explicitly set it here.

### Using PGAdmin

This is a minimal configuration demonstrating how use [PGAdmin 4](https://www.pgadmin.org) to manage a PostgreSQL database configured as described in the above section:

```yaml
version: "3"
volumes:
  postgres-data:  { driver: local }
  pgadmin-config: { driver: local }
services:
  postgres:
    image: postgres
    volumes:
      - postgres-data:/var/lib/postgresql/data
  pgadmin:
    image: thajeztah/pgadmin4
    ports:
      - "5050:5050"
    volumes:
      - pgadmin-config:/pgadmin
    links:
      - postgres
```

> ℹ️ Note that this example doesn't include your own application configuration because it is completely independent from your code. A real world `docker-compose.yml` would indeed include it.

Here is what it does:

* create a Docker volume to persist the configuration:

    ```yaml
    pgadmin-config: { driver: local }
    ```

* create a service for the PGAdmin4 server that publishes the web server port (`5050`) to the host OS, uses the previously created volume to persist configuration (_i.e._ mount it on `/pgadmin`) and links to the PostgreSQL server (to autostart it and be able to reach it by its name in the Docker Compose virtual network):

    ```yaml
    pgadmin:
      image: thajeztah/pgadmin4
      ports:
        - "5050:5050"
      volumes:
        - pgadmin-config:/pgadmin
      links:
        - postgres
    ```

You can now start PGAdmin using the usual command `docker-compose up pgadmin` then access it on http://localhost:5050 🐘 (from where you can configure it to connect to the PostgreSQL server on host `postgres` with user `postgres` and no password).

### Using MailCatcher

This is a minimal configuration to use [MailCatcher](https://mailcatcher.me) to intercept and read all emails sent by your application:

```yaml
version: "3"
volumes:
  bundle: { driver: local }
  config: { driver: local }
services:
  app:
    image: alpinelab/ruby-dev
    volumes:
      - .:/app
      - bundle:/bundle
      - config:/config
    links:
      - mailcatcher
  mailcatcher:
    image: schickling/mailcatcher
    ports:
      - "1080:1080"
```

Here is what it does:

* create a service for the MailCatcher server, that publishes the web server port (`1080`) to the host OS:

    ```yaml
    mailcatcher:
      image: schickling/mailcatcher
      ports:
        - "1080:1080"
    ```

* link this server to the application service (`app`), so it will be started whenever it's needed and it can be accessed inside Docker network by its name (`mailcatcher`):

    ```yaml
    links:
      - mailcatcher
    ```

You can now configure your application to use SMTP server on hostname `mailcatcher` and port `1025`, the fully-qualified URL `smtp://mailcatcher:1025` or the following configuration if you are using Rails:

```ruby
config.action_mailer.delivery_method       = :smtp
config.action_mailer.smtp_settings         = { address: "mailcatcher", port: 1025 }
config.action_mailer.raise_delivery_errors = false
```

Your application will now send all emails to MailCatcher SMTP server and you can check them on http://localhost:1080 📩

> 💡 Use this config in `config/environments/development.rb` only, or use environment variables instead of hard-coded values if you want a generic configuration (working for both development and production) in `config/application.rb`.

## Configuration

Most configurations can be done from a `docker-compose.override.yml` file alongside your `docker-compose.yml` file (by default, it will be [automatically read](https://docs.docker.com/compose/extends/#multiple-compose-files) by `docker-compose`, and it should probably be [gitignore'd globally](https://help.github.com/articles/ignoring-files/#create-a-global-gitignore)).

### Heroku CLI authentication

The recommended approach to have the Heroku CLI authenticated is to set the `HEROKU_API_KEY` in `docker-compose.override.yml` with an OAuth token:

```yaml
version: "3"
services:
  app:
    environment:
      HEROKU_API_KEY: 12345-67890-abcdef
```

If you don't have an [OAuth token](https://github.com/heroku/heroku-cli-oauth#authorizations) yet, you can create and output one with:

```shell
heroku authorizations:create --short --description "Docker [alpinelab/ruby-dev]"
```

An alternative but less secure approach would be to mount your host's `~/.netrc` to the container's `/etc/skel/.netrc` so that it will copied into the user's home directory.

### Git authentication

There are 2 methods to be able to pull private repositories from within the Docker container (there are other use-cases, but this one is the most frequent).

> ⚠️ Look out if you commit from within the container, though: it [uses](https://github.com/alpinelab/docker-ruby-dev/blob/latest/Dockerfile) fake `GIT_COMMITTER_NAME` and `GIT_COMMITTER_EMAIL` by default, which is probably not what you want. You may want to override them too, from `docker-compose.override.yml`:
> ```yaml
> version: "3"
> services:
>   app:
>     environment:
>       GIT_COMMITTER_NAME: "Your name"
>       GIT_COMMITTER_EMAIL: "you@example.com"
> ```

#### For SSH repositories

If you're using SSH as underlying Git protocol (_e.g._ your `Gemfile` uses URLs starting with `git@`), you may want to use your host SSH authentication from within the container.

You can do it by mounting your host's `~/.ssh` to the container's `/etc/skel/.ssh` directory from `docker-compose.override.yml`:

```yaml
version: "3"
services:
  app:
    volumes:
      - ~/.ssh:/etc/skel/.ssh
```

It will be copied into the user's home directory before any command run into the container.

#### For HTTPS repositories

If you're using HTTPS as underlying Git protocol (_e.g._ your `Gemfile` uses URLs starting with `https://`), you may want to pass your repository credentials to the container via the an environment variable:

```yaml
version: "3"
services:
  app:
    environment:
      BUNDLE_GITHUB__COM: 'USERNAME:PASSWORD' # if you do NOT use 2FA
      BUNDLE_GITHUB__COM: 'PERSONAL_ACCESS_TOKEN:x-oauth-basic' # if you use 2FA
```

> ℹ️ This example works for repositories hosted on the `github.com` host name, but can be adapted to any host name (note the double-underscore between host name parts):
> * `BUNDLE_BITBUCKET__ORG`
> * `BUNDLE_GITLAB__COM` (the format is `oauth2:PERSONAL_TOKEN`, though)
> * …

### RubyGems authentication

If you want to build and publish gems from within the container (_e.g._ [using Bundler's `rake release` task](https://www.schneems.com/blogs/2016-03-18-bundler-release-tasks)), you may want to use your host's RubyGems credentials.

You can do it by mounting your host's `~/.gem/credentials` to the container's `/etc/skel/.gem/credentials` directory from `docker-compose.override.yml`:

```yaml
version: "3"
services:
  app:
    volumes:
      - ~/.gem/credentials:/etc/skel/.gem/credentials
```

It will be copied into the user's home directory before any command run into the container.

### Custom Yarn check command

By default, we use `yarn check --integrity --verify-tree --silent` to check that all JS dependencies are met, but you can override this if you need to by defining your own `check` command in the `scripts` section of `package.json`, like:

```json
{
  "scripts": {
    "check": "cd client && yarn check --integrity --verify-tree --silent"
  }
}
```

This can be particularly useful with configurations like the one traditionally setup by [ReactOnRails](https://github.com/shakacode/react_on_rails), which combines a `package.json` in the `client/` sub-directory (for the actual client-side code) and another `package.json` in the Rails root (for development tools like linters or proxying Yarn scripts/commands to the `client/` sub-directory config).

### Bundler 1.x

Our image uses Bundler 2.x by default, but for convenience, it also embeds Bundler 1.x. To use it in your legacy project, simply set the `BUNDLER_VERSION` environment variable from your `docker-compose.yml`:

```yaml
services:
  app:
    environment:
      BUNDLER_VERSION: "1.17.3"
```

> :warning: We may bump Bundler 1.x exact version number in the future if a new version is released (and forget to update this very documentation :grimacing:). Make sure you are setting the correct version number by checking which Bundler versions are available in your container image by running `gem list bundler`.

## Operations

First of all, make sure your development database exists and is empty:

```shell
docker-compose run --entrypoint=bypass -e PGHOST=postgres -e PGUSER=postgres app dropdb app_development
docker-compose run --entrypoint=bypass -e PGHOST=postgres -e PGUSER=postgres app createdb app_development
```

### Load a database dump

To copy a database dump (_e.g._ `latest.dump`) to your local Postgres development database, use [`pg_restore`](https://www.postgresql.org/docs/current/app-pgrestore.html):

```shell
docker-compose run --entrypoint=bypass -e PGHOST=postgres -e PGUSER=postgres app pg_restore --verbose --clean --no-acl --no-owner -d app_development latest.dump
```

### Fetch and load a Heroku database

To copy a Postgres database from Heroku to your local development environment (assuming you followed the Postgres config from the [using PostgreSQL](#using-postgresql) section), use [`heroku pg:pull`](https://devcenter.heroku.com/articles/heroku-cli-commands#heroku-pg-pull-source-target):

```shell
docker-compose run -e PGSSLMODE=prefer --entrypoint=bypass app heroku pg:pull DATABASE_URL postgres://postgres:@postgres/app_development -a your-heroku-app
```

> ℹ️ You need [Heroku CLI authentication](#heroku-cli-authentication) configured for this to work.

## Customisation

The followin recipes provide a `Dockerfile` for different common use-cases in Ruby projects (see the [README "Customisation" section](README.md#customisation) for usage instructions).

Feel free to [contribute more](README.md#contributing) like those ❤️

### capybara-webkit

This `Dockerfile` adds packages required to compile [Thoughtbot](https://thoughtbot.com)'s [`capybara-webkit`](https://github.com/thoughtbot/capybara-webkit) gem native extensions.

```Dockerfile
FROM alpinelab/ruby-dev

RUN apt-get update \
 && apt-get install --assume-yes --no-install-recommends --no-install-suggests \
      qt5-default \
      libqt5webkit5-dev \
      gstreamer1.0-plugins-base \
      gstreamer1.0-tools \
      gstreamer1.0-x \
 && rm -rf /var/lib/apt/lists/*
```

### wkhtmltopdf

This `Dockerfile` adds the [wkhtmltopdf](https://github.com/wkhtmltopdf/wkhtmltopdf) binary from GitHub:

```Dockerfile
FROM alpinelab/ruby-dev

ENV WKHTMLTOPDF_VERSION="0.12.4"

RUN dpkgArch="$(dpkg --print-architecture | cut -d- -f1)" \
 && curl --silent --location "https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/${WKHTMLTOPDF_VERSION}/wkhtmltox-${WKHTMLTOPDF_VERSION}_linux-generic-${dpkgArch}.tar.xz" \
  | tar --extract --xz --directory /usr/local/bin --strip-components=2 wkhtmltox/bin/wkhtmltopdf
```

### rails-erd

This `Dockerfile` adds packages required by the [rails-erd](https://github.com/voormedia/rails-erd) gem:

```Dockerfile
FROM alpinelab/ruby-dev

ENV GRAPHVIZ_VERSION="2.38.0-7"

RUN apt-get update \
 && apt-get install --assume-yes --no-install-recommends --no-install-suggests \
      graphviz=${GRAPHVIZ_VERSION} \
 && rm -rf /var/lib/apt/lists/*
```

### phantomjs

This `Dockerfile` adds the [PhantomJS](http://phantomjs.org) binary from BitBucket:

```Dockerfile
FROM alpinelab/ruby-dev

ENV PHANTOMJS_VERSION="2.1.1"

RUN cpuArch="$(lscpu | sed -n 's/Architecture: *\(.*\)/\1/p')" \
 && curl --silent --location "https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-${PHANTOMJS_VERSION}-linux-${cpuArch}.tar.bz2" \
  | tar --extract --bzip2 --directory /usr/local/bin --strip-components=2 "phantomjs-${PHANTOMJS_VERSION}-linux-${cpuArch}/bin/phantomjs"
```
