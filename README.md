# docker-ruby-dev

Ruby development with Docker made easy :whale:

This Docker image is an opinionated Docker setup for Ruby development.
It aims to provide an easy but consistent configuration experience for your Ruby projects.

## Goals

* use the same Docker image in all projects
* stop messing your host environment with multiple rubies and gemsets
* stop building your Docker image every time you change your `Gemfile` (or worse: your code :scream:)

## Usage

### with Docker Engine

Start your project from its codebase:
```
docker run -it -v $(pwd):/app alpinelab/ruby-dev
```

You can also add `-v $(basename $(pwd))-bundle:/bundle` to persist gems installed by Bundler.

And/or `-v $(basename $(pwd))-node_modules:/app/node_modules` to persist JS packages installed by Yarn.

And/or `-v $(basename $(pwd))-config:/config` to persist shell (Bash) and Ruby REPL histories.

And/or `-v $(basename $(pwd))-sync:/app:nocopy` if you're on MacOS and already started `docker-sync` manually.

As you see, it ends up in very long/complex command-lines just to start your app (or run `rake` 😕). That's why we recommend to either create an alias for this, or even better: use Docker Compose (see immediately below).

### with Docker Compose (recommended)

With Docker Compose (recommended to persist history, dependencies, etc… without super long command lines), create a `docker-compose.yml` file in your codebase root directory like this:

```yaml
version: "3"
volumes:
  app-bundle:       { driver: local }
  app-node_modules: { driver: local }
  app-config:       { driver: local }
services:
  app:
    image: alpinelab/ruby-dev
    volumes:
      - ./:/app
      - app-bundle:/bundle
      - app-node_modules:/app/node_modules
      - app-config:/config
```

If you're on MacOS, you'll very likely want to use [Docker Sync](http://docker-sync.io) too:

0. install it with `gem install docker-sync`

1. add a `docker-sync.yml` file:

    ```yaml
    version: "2"
    syncs:
      app-sync:
        src: ./
        sync_excludes: [log, tmp, .git, .bundle, .idea, node_modules]
    ```

2. add the sync container as external container in `docker-compose.yml`:

    ```yaml
    volumes:
      app-sync: { external: true }
    ```

3. use it in the `app` service by replacing `- ./:/app` by `- app-sync:/app:nocopy`

4. start it with `docker-sync start`

You can finally start your project with:

```shell
docker-compose up
```

Or run any command like `rake` with:

```shell
docker-compose run app rake
```

> 💡 Note that you don't need to prefix commands with `bundle exec`.

## Features

* shell history
* IRB/Pry history
* auto-maintain Ruby (Bundler) & JS (npm) dependencies
* basic in-container tools

## Conventions

Filesystem conventions:
* `/app` holds your application source code
* `/app/node_modules` holds NPM/Yarn packages
* `/bundle` holds Bundler data
* `/config` holds miscellaneous configuration files

Dependencies conventions:
* `bundle install` is run before any command if necessary
* `yarn install` is run before any command if necessary

## Configurations

### Custom Yarn check command

By default, we use `yarn check --integrity --verify-tree --silent` to check that all JS dependencies are met, but you can override this if you need to by defining your own `check` command in the `scripts` section of `package.json`.

### Installing software in the container

To temporarily install a package inside the container (_e.g._ for a one-time debugging session), you can simply run:

```shell
apt-get update && apt-get install <your_package>
```

> ⚠️ This will probably **not be persisted** (because it will likely be installed in this container instance a UnionFS layer that will be discarded when you exit it).
