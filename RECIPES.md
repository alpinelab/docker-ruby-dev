# Recipes

You will find here some instructions, explanations, examples and code snippets to configure or customize the `alpinelab/ruby-dev` image.

Please refer to [README.md](README.md) for generic overview, setup and usage instructions.

<details>

  <summary>Table of contents</summary>

  * [Usage](#usage)
    * [with PostgreSQL](#with-postgresql)
    * [with MailCatcher](#with-mailcatcher)
  * [Configuration](#configuration):
    * [Heroku CLI authentication](#heroku-cli-authentication)
    * [Git authentication](#git-authentication)
    * [Custom Yarn check command](#custom-yarn-check-command)
  * [Customisation](#customisation):
    * [capybara-webkit](#capybara-webkit)
    * [wkhtmltopdf](#wkhtmltopdf)
    * [rails-erd](#rails-erd)

</details>

## Usage

### With PostgreSQL

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
    links:
      - postgres
  postgres:
    image: postgres
    volumes:
      - postgres-data:/var/lib/postgresql/data
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
  host: postgres
  port: 5432
  username: postgres
  password:

development:
  <<: *default
  database: app_development

test:
  <<: *default
  database: app_test

production:
  <<: *default
  database: app_production
```

> ℹ️ There is almost no risk of database name collision with other projects of yours since Docker Compose will create a different volume for each different `docker-compose.yml` file, hence the very generic database names used here.

### With MailCatcher

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
heroku authorizations:create --output-format short --description "Docker [alpinelab/ruby-dev]"
```

An alternative but less secure approach would be to mount your host's `~/.netrc` to the container's `/root/.netrc`.

### Git authentication

If you're using SSH as underlying Git protocol, you may want to use your host SSH authentication from within the container (to use `git` from there, for example).

You can do it by mounting your host's `~/.ssh` to the container's `/root/.ssh` from `docker-compose.override.yml`:

```yaml
version: "3"
services:
  app:
    volumes:
      - ~/.ssh:/root/.ssh
```

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
