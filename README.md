# `alpinelab/ruby-dev` [![Docker Stars](https://img.shields.io/docker/stars/alpinelab/ruby-dev.svg?style=flat-square)](https://hub.docker.com/r/alpinelab/ruby-dev/) [![Docker Pulls](https://img.shields.io/docker/pulls/alpinelab/ruby-dev.svg?style=flat-square)](https://hub.docker.com/r/alpinelab/ruby-dev/)

This image provides an easy, generic, consistent and non-intrusive Docker setup for all your Ruby projects. [Why?](#about)

## Usage

### With Docker Compose (recommended)

#### Setup

With Docker Compose, simply create a `docker-compose.yml` file in your codebase root directory like this:

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

#### Run

You can now start your project with:

```shell
docker-compose up
```

Or run any command (like `rake`) with:

```shell
docker-compose run app rake
```

> 💡 Note that you don't need to prefix commands with `bundle exec`.

### With Docker Engine only

Start your project from its codebase:
```
docker run -it -v $(pwd):/app alpinelab/ruby-dev
```

You can also add `-v $(basename $(pwd))-bundle:/bundle` to persist gems installed by Bundler.

And/or `-v $(basename $(pwd))-node_modules:/app/node_modules` to persist JS packages installed by Yarn.

And/or `-v $(basename $(pwd))-config:/config` to persist shell (Bash) and Ruby REPL histories.

And/or `-v $(basename $(pwd))-sync:/app:nocopy` if you're on MacOS and already started `docker-sync` manually.

As you can see, you will quickly end up with very long and complex commands just to start your app (or run `rake` 😕). That's why we recommend to either create an alias for this, or even better: use Docker Compose (see above).

## About

### Goals

* use the same Docker image in all projects
* stop messing your host environment with multiple rubies and gemsets
* stop building your Docker image every time you change your `Gemfile` (or worse: your code :scream:)
* use up-to-date Ruby, Bundler, Node and Yarn versions

### Features

* shell history
* IRB/Pry history
* auto-install Ruby (Bundler) and Javascript (NPM) dependencies
* basic in-container tools (`vim`, `nano`, …)

### Conventions

Filesystem conventions:
* `/app` holds your application source code
* `/app/node_modules` holds packages installed by Yarn
* `/bundle` holds gems installed by Bundler
* `/config` holds miscellaneous configuration files

Dependencies conventions:
* `bundle install` is run before any command if necessary
* `yarn install` is run before any command if necessary

### Customisation

#### Custom Yarn check command

By default, we use `yarn check --integrity --verify-tree --silent` to check that all JS dependencies are met, but you can override this if you need to by defining your own `check` command in the `scripts` section of `package.json`, like:

```json
{
  "scripts": {
    "check": "cd client && yarn check --integrity --verify-tree --silent"
  }
}
```


#### Installing software in the container

To temporarily install a package inside the container (_e.g._ for a one-time debugging session), you can simply run:

```shell
apt-get update && apt-get install <your_package>
```

> ⚠️ This will probably **not be persisted** (because it will likely be installed in this container instance a UnionFS layer that will be discarded when you exit it).
