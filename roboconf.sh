function roboconf-check {
  echo -n "checking for $1... "
  hash "$1" 2>&- || {
    echo 'no'
    exit -1
  }
  echo 'yes'
}

function roboconf-git-modules {
  roboconf-check git
  git submodule init
  git submodule sync
  git submodule update
}

function roboconf-bundler {
  bundler_version="$1"
  opts="$2"

  roboconf-check rvm
  roboconf-check gem
  # Assumes rvm
  gem install bundler --version "$bundler_version" --no-rdoc --no-ri
  bundle install $opts
}

function roboconf-npm {
  roboconf-check node
  roboconf-check npm
  npm install
}

function roboconf-rails-activerecord {
  bundle exec rake db:create
  bundle exec rake db:migrate
}

function roboconf-padrino-activerecord {
  bundle exec padrino rake ar:create
  bundle exec padrino rake ar:create -e test
  bundle exec padrino rake ar:migrate
  bundle exec padrino rake ar:migrate -e test
  bundle exec padrino rake seed
}

function roboconf-passenger {
  mkdir -p tmp
  touch tmp/restart.txt
}

function echo_cmd {
  echo "\$ $*"
  $*  
}

# Loads $HEROKU_CONSTANTS or exits
function load_heroku_constants {
  if [ -z "$HEROKU_CONSTANTS" ]; then
    echo "Error: \$HEROKU_CONSTANTS is undefined"
    echo "\$HEROKU_CONSTANTS should reference a file holding key=value pairs of Heroku configuration settings"
    exit 1
  elif [[ -f $HEROKU_CONSTANTS ]]; then
    source $HEROKU_CONSTANTS
  else
    echo "Error: Failed to find $HEROKU_CONSTANTS"
    exit 1
  fi
}

# "Private" function called by run_heroku_config_if_settings_changed.
# Sets the heroku_vars_changed variable to true/false depending on whether
# the Heroku environment variables in $HEROKU_CONSTANTS differ from what
# is currently configured for the Heroku app.
function detect_heroku_vars_changed {
  # current app settings on Heroku
  current_configs=$(heroku config --app "$app")

  # desired new Heroku settings
  load_heroku_constants

  # test whether desired Heroku settings equal current Heroku settings
  heroku_vars_changed=false
  while read line
  do
    new_key="$( cut -d '=' -f 1 <<< $line )"
    new_value="$( cut -d '=' -f 2- <<< $line )"
    new_value=`sed -E -e "s/(^'|'$)//g" <<< $new_value` # strip leading/trailing 's
    new_value=`sed -E -e "s/(^\"|\"$)//g" <<< $new_value` # strip leading/trailing "s
    if [[ $new_key =~ 'HEROKU_CONFIG_ADD_CONSTANTS' ]]; then
      continue   # ignore this script-only variable; it's not a Heroku config setting
    fi
    if [[ "$current_configs" == *"$new_key"* && "$current_configs" == *"$new_value"* ]]; then
      echo "Key '$new_key' already has value '$new_value'"
    else
      heroku_vars_changed=true
      echo "Key '$new_key' will be set to value '$new_value'"
    fi
  done < $HEROKU_CONSTANTS
}

# runs 'heroku config:add' only if the Heroku configuration settings have changed
function run_heroku_config_if_settings_changed {
  detect_heroku_vars_changed
  if ! $heroku_vars_changed; then
    echo "Skipping 'heroku config:add' because Heroku variables unchanged"
  else
    echo "Running 'heroku config:add' because Heroku variables have changed"
    heroku config:add $HEROKU_CONFIG_ADD_CONSTANTS --app "$app"
  fi
}

function show_prep_release_usage_and_exit {
  cat <<EOF
Usage: $0 heroku-app-name

Function: Release app to heroku-app-name.herokuapp.com as staging/testing environment before a release.

Example: $0 hedgeye-cedar-smarketing
Example: $0 hedgeye-smailroom
EOF
  exit 1
}

function show_release_usage_and_exit {
  cat <<EOF
Usage: $0 heroku-app-name

Function: Release app to heroku-app-name.herokuapp.com as production environment.

Example: $0 hedgeye-cedar-marketing
Example: $0 hedgeye-reader
EOF
  exit 1
}
