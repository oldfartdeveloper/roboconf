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

function set_heroku_vars_changed {
  current_configs=$(heroku config --app "$app")

  heroku_vars_changed=false
  while read line
  do
    new_consts=(${line//=/ })
    new_key=${new_consts[0]}
    new_value=${new_consts[1]}
    new_value=`sed -E -e "s/(^'|'$)//g" <<< $new_value` # strip leading/trailing 's
    new_value=`sed -E -e "s/(^\"|\"$)//g" <<< $new_value` # strip leading/trailing "s
    if [[ $new_key =~ 'HEROKU_CONFIG_ADD_CONSTANTS' ]]; then
      continue 
    fi  
    if [[ $current_configs =~ $new_key ]]; then
      echo "$new_key is present"
    else
      heroku_vars_changed=true
      echo "$new_key is not present"
    fi  
    if [[ $current_configs =~ $new_value ]]; then
      echo "$new_value is present"
    else
      heroku_vars_changed=true
      echo "$new_value is not present"
    fi
  done < $HEROKU_CONSTANTS
}

function run_heroku_config_if_settings_changed {
  set_heroku_vars_changed
  if ! $heroku_vars_changed; then
    echo "Skipping 'heroku config:add' because Heroku variables unchanged"
  else
    echo "Running 'heroku config:add' because Heroku variables have changed"
    heroku config:add $HEROKU_CONFIG_ADD_CONSTANTS --app "$app"
  fi
}
