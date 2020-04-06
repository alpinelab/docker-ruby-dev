# Simple test app for alpinelab/ruby-dev

Run Ruby (gem) "cowsay" with:

    docker-compose run app bundle exec ruby -rbundler/setup -rruby_cowsay -e 'puts Cow.new.say("Mooooo")'

Run JS (NPM package) "cowsay" with:

    docker-compose run app yarn run --silent cowsay Mooooo
