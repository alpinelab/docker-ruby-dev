# `alpinelab/ruby-dev` [![Docker Stars](https://img.shields.io/docker/stars/alpinelab/ruby-dev.svg?style=flat-square)](https://hub.docker.com/r/alpinelab/ruby-dev/) [![Docker Pulls](https://img.shields.io/docker/pulls/alpinelab/ruby-dev.svg?style=flat-square)](https://hub.docker.com/r/alpinelab/ruby-dev/)

This image provides an easy, generic, consistent and non-intrusive Docker Compose setup for all your Ruby projects. [Why?](#about)

## Usage

### Setup

Simply create a `docker-compose.yml` file in your project root directory like this:

```yaml
version: "3"
volumes:
  bundle:       { driver: local }
  node_modules: { driver: local }
  config:       { driver: local }
services:
  app:
    image: alpinelab/ruby-dev
    volumes:
      - .:/app
      - bundle:/bundle
      - node_modules:/app/node_modules
      - config:/config
```

> :bulb: Feel free to use `alpinelab/ruby-dev:<ruby-version>`: we support multiple Ruby versions [via image tags](https://hub.docker.com/r/alpinelab/ruby-dev/tags/)

<details>

  <summary>If you're on MacOS, you'll very likely want to use Docker Sync too.</summary>

  > ⚠️ Use your **actual** application name suffixed with `-sync` instead of `your_app-sync` to prevent conflicts between your projects.

  0. install it with `gem install docker-sync`

  1. add a `docker-sync.yml` file:

      ```yaml
      version: "2"
      syncs:
        your_app-sync:
          src: ./
          sync_excludes: [log, tmp, .git, .bundle, .idea, node_modules]
      ```

  2. add the sync container as external container in `docker-compose.yml`:

      ```yaml
      volumes:
        your_app-sync: { external: true }
      ```

  3. use it by replacing `- ./:/app` with `- your_app-sync:/app:nocopy` in `docker-compose.yml`

  4. start the sync with `docker-sync start`

</details>

### Run

You can now start your project with:

```shell
docker-compose up
```

Or run any command (like `rake`, `bash`, or whatever else) with:

```shell
docker-compose run app [rake|bash|...]
```

> 💡 Note that you don't need to prefix commands with `bundle exec`.

## About

### Goals

* use the same Docker image in all your projects
* stop messing your host environment with multiple rubies and gemsets
* stop building your Docker image every time you change your `Gemfile` (or worse: your code :scream:)
* use up-to-date Ruby, Bundler, Node and Yarn versions

### Features

* shell history
* IRB/Pry history
* auto-install Ruby (Bundler) and Javascript (NPM) dependencies
* basic in-container tools (`vim`, `nano`, `heroku`, …)
* runs whatever you define in the `Procfile`

### Conventions

Filesystem conventions:
* `/app` holds your application source code
* `/app/node_modules` holds packages installed by Yarn
* `/bundle` holds gems installed by Bundler
* `/config` holds miscellaneous configuration files

Dependencies conventions:
* `bundle install` is run before any command if necessary
* `yarn install` is run before any command if necessary

Other conventions:
* the default command run by the image is `foreman start`

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

## Customisation

### Custom Yarn check command

By default, we use `yarn check --integrity --verify-tree --silent` to check that all JS dependencies are met, but you can override this if you need to by defining your own `check` command in the `scripts` section of `package.json`, like:

```json
{
  "scripts": {
    "check": "cd client && yarn check --integrity --verify-tree --silent"
  }
}
```

### Installing software in the container

To **temporarily** install a package inside the container (_e.g._ for a one-time debugging session), you can simply run:

```shell
apt-get update && apt-get install <your_package>
```

> ⚠️ This will probably **not be persisted** (because it will likely be installed in this container instance a UnionFS layer that will be discarded when you exit it).

To **permanently** install packages inside a container, you'll need to create a new Docker image based on this very one (or any of its tags). For example, to add packages needed to compile [Thoughtbot](https://thoughtbot.com)'s [`capybara-webkit`](https://github.com/thoughtbot/capybara-webkit) gem native extensions, create the following `Dockerfile` in your project root folder (it will build an image based on this one but with some extra packages installed by `apt-get` on top of it):

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

Then, change your `docker-compose.yml` to use it (and to build it on-demand) by changing `image: alpinelab/ruby-dev` to `build: .`.

## Contributing

Contributions are indeed warmly welcome as [pull requests](https://github.com/alpinelab/docker-ruby-dev/pulls), or [issues](https://github.com/alpinelab/docker-ruby-dev/issues).

There's also a handy [`add-ruby-version-support.sh`](https://github.com/alpinelab/docker-ruby-dev/blob/latest/add-ruby-version-support.sh) script to add support for a Ruby version and another handy [`rebase-all.sh`](https://github.com/alpinelab/docker-ruby-dev/blob/latest/rebase-all.sh) script to apply a change made on `latest` branch to all other branches.
