# `alpinelab/ruby-dev` [![Docker Stars](https://img.shields.io/docker/stars/alpinelab/ruby-dev?style=flat-square)](https://hub.docker.com/r/alpinelab/ruby-dev/) [![Docker Pulls](https://img.shields.io/docker/pulls/alpinelab/ruby-dev.svg?style=flat-square)](https://hub.docker.com/r/alpinelab/ruby-dev/) [![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/alpinelab/docker-ruby-dev/docker-build.yml?style=flat-square)](https://github.com/alpinelab/docker-ruby-dev/actions/workflows/docker-build.yml)

The main goal of this project is to have a single Docker image to develop all your Ruby projects, with **all dependencies contained inside Docker** (like gems, NPM packages or even Ruby itself, that won't pollute your host environment) and without anything specific to the project in the Docker image (the **codebase is mounted directly from the host filesystem into the container**, thus you'll never have to build the image when you add a gem or change some code).

The Docker container also provides developer-friendly tools and behaviours like persisted **Ruby console history** (IRB and Pry), **shell history**, or even auto-installing dependencies (that's right:  simply change your `Gemfile` or `package.json` and **`bundle install` or `yarn install` will be run automatically** for you and only when necessary). It also provides a few CLI tools to get your hands dirty, but as least as possible: `vim`, `nano`, `heroku`.

The default command (when you just `docker-compose up`) is to run `foreman start`, thus starting whatever you put in your `Procfile` (except the `release` process, if you have one: it's a reserved process name by Heroku/Dokku). All commands are run inside the container **as the same user that owns your codebase** (thus probably your host user), which means that any file generated inside the container (think of `rails generate`, `yarn init`, or even log files) will be owned by yourself (not by `root`, like they would with a default Docker configuration).

We try to use sane default conventions so you don't have to think about it, but this image also allows some configuration (_e.g._ Heroku CLI or Git authentication) and [customisation](#customisation) (install extra software inside the container). See the [recipes book](RECIPES.md) for more details.

> **TL;DR** 🙄
>
> * your codebase is 2-way-mounted from your host to `/app` inside the container
> * [Yarn](https://yarnpkg.com) is configured to store installed modules in `/app/node_modules`
> * [Bundler](https://bundler.io) is configured to store installed gems in `/bundle`
> * [Rubygems](https://github.com/rubygems/rubygems) is configured to store installed gems (using `gem install …` directly) in `/bundle/global`
> * everything ran inside the container is done with your host user UID and GID
> * `bundle install` is run before any command, only if necessary
> * `yarn install` is run before any command, only if necessary
> * you can [customise](RECIPES.md) the image with extra software

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
    ports: ["5000:5000"]
    volumes:
      - .:/app
      - bundle:/bundle
      - node_modules:/app/node_modules
      - config:/config
```

> 💡 Feel free to use `alpinelab/ruby-dev:<ruby-version>`: we support [multiple Ruby versions](.github/workflows/docker-build.yml) [as Docker tags](https://hub.docker.com/r/alpinelab/ruby-dev/tags/)
> and Alpine Linux variants (append `-alpine` to image tag).

<details>

  <summary>If you're on MacOS, you'll very likely want to use Docker Sync too.</summary>

  > ⚠️ Use your **actual** application name suffixed with `-sync` instead of `your_app-sync` to prevent conflicts between your projects.

  0. install it with `gem install docker-sync`

  1. add a `docker-sync.yml` file:

      ```yaml
      version: "3"
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

You can even bypass dependencies check/auto-install before the command is run by setting the `DISABLE_AUTO_INSTALL_DEPS` environment variable from the command-line:

```shell
docker-compose run -e DISABLE_AUTO_INSTALL_DEPS=1 app bash
```

## Customisation

You can customise this image by **building your own image based on this one** (or any of its tags, by appending them to the `FROM` step of the `Dockerfile`), and install additional software on top of it:

  1. create a `Dockerfile` in your project root folder, and add a build step that installs the APT package you need (other installation methods work too, but it's out of the scope of this documentation):

      ```Dockerfile
      FROM alpinelab/ruby-dev

      RUN apt-get update \
       && apt-get install --assume-yes --no-install-recommends --no-install-suggests \
            <INSERT APT PACKAGE NAME HERE> \
       && rm -rf /var/lib/apt/lists/*
      ```

  2. change your `docker-compose.yml` to use this `Dockerfile` (rather than an upstream image) and to build it on-demand:

      * change this line:

          ```yaml
          image: alpinelab/ruby-dev
          ```

      * into this line:

          ```yaml
          build: .
          ```

> ℹ️ To **temporarily** install a package inside the container (_e.g._ for a one-time debugging session), you can simply:
>
> 1. Run a shell as root in the container (notice the empty entrypoint):
>
>     ```shell
>     docker-compose run --entrypoint= app bash
>     ```
>
> 2. Install the pakckage using APT (any change will be undone when you close the shell):
>     ```shell
>     apt-get update && apt-get install <your_package>
>     ```

## Known issues

A wild `node_modules` directory owned by `root` may appear in your codebase directory. This is due to Docker [creating the destination mount point](https://github.com/moby/moby/issues/26051) for the bind mount. It should be solved when we will be able to reliably configure Yarn to [use an absolute directory](https://github.com/alpinelab/docker-ruby-dev/issues/1) (instead of relative `node_modules`) outside of the codebase, like we do with Bundler.

## Unmaintained versions

The following Ruby versions are not maintained anymore:

* Ruby 2.2 ([EOL](https://www.ruby-lang.org/en/news/2018/06/20/support-of-ruby-2-2-has-ended/)'d)

## Contributing

Contributions are indeed warmly welcome as [pull requests](https://github.com/alpinelab/docker-ruby-dev/pulls), or [issues](https://github.com/alpinelab/docker-ruby-dev/issues) ❤️

## License

This project is developed by [Alpine Lab](https://www.alpine-lab.com) and released under the terms of the [MIT license](LICENSE.md).

<a href="https://www.alpine-lab.com"><img src=".github/alpinelab-logo.png" width="40%" /></a>
