#!/bin/sh

echo "Begin loading roboconf functions..."

function roboconf-check {
  echo -n "checking for $1... "
  hash "$1" 2>&- || {
    echo 'no'
    exit -1
  }
  echo 'yes'
}

# Since the developer may not want to merge the latest SHAs during his development,
# this function only checks out what the current parent project "thinks" are the
# current submodule SHAs.  To retrieve the latest SHAs (from the submodule
# point of view), use function 'update_git_submodules'.
function check_out_current_project_shas {
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

function fire_up_heroku_app {
  curl "http://${app}.herokuapp.com/" &> /dev/null
}

# Loads $HEROKU_CONSTANTS or exits
function load_heroku_constants {
  if [ -z "$HEROKU_CONSTANTS" ]; then
    echo "Error: \$HEROKU_CONSTANTS is undefined"
    echo "\$HEROKU_CONSTANTS should reference a file holding key=value pairs of Heroku configuration settings"
    exit 1
  elif [[ -f $HEROKU_CONSTANTS ]]; then
    echo "Sourcing $HEROKU_CONSTANTS"
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
  echo "Starting detect_heroku_vars_changed"

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
    if [[ $new_key =~ 'HEROKU_CONFIG_ADD_CONSTANTS' # ignore this script-only variable; it is not a Heroku config setting
        || $new_key == \#* # ignore lines that start with '#' (comments)
        || $new_key == '' # ignore blank lines
        ]]; then
      continue
    fi
    if [[ "$current_configs" == *"$new_key"* && "$current_configs" == *"$new_value"* ]]; then
      echo "Key '$new_key' already has value '$new_value'"
    else
      heroku_vars_changed=true
      echo "Key '$new_key' will be set to value '$new_value'"
    fi
  done < $HEROKU_CONSTANTS
}

# runs 'heroku config:set' only if the Heroku configuration settings have changed
function run_heroku_config_if_settings_changed {
  echo "Starting run_heroku_config_if_settings_changed..."
  detect_heroku_vars_changed
  if ! $heroku_vars_changed; then
    echo "Skipping 'heroku config:add' because Heroku variables unchanged"
  else
    echo "Running 'heroku config:add' because Heroku variables have changed"
    heroku config:set $HEROKU_CONFIG_ADD_CONSTANTS --app "$app"
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

function show_config_usage_and_exit {
  cat <<EOF
Usage: $0 heroku-app-name

Function: Update Heroku configuration.

Example: $0 hedgeye-labs
EOF
  exit 1
}

function heroku_addon {
  name="$1"
  match=$(ruby -e "puts %x(heroku addons --app "$app").match(/$name/).to_s")

  if [ '' == "$match" ]; then
    echo "Installing '$name' because it's not yet installed"
    echo_cmd heroku addons:add $name --app "$app"
  else
    echo "Not installing '$name' because it's already installed"
  fi  
}

# Since database migration is performed in CMS, the db/schema.rb file
# for non-CMS applications can get out of sync.  The ./configure file
# in such projects should invoke this method to make sure that the
# db/schema.rb file is updated periodically.
#
# The 'cruise' check is to allow Jenkins to not do this, since
# non-CMS applications _do_ have their own databases and therefore
# handle db/schema.rb differently.
function dump_schema {
    if ! [[ "$TEST_ENVIRONMENT" == 'cruise' ]]; then
      bundle exec rake db:schema:dump
    fi
}

# ***********************************************************
# ****** BEGIN CODE TO SUPPORT AUTO SUBMODULE UPDATING ******
# ***********************************************************

function checkout_git_branch {
  set_current_git_branch_name
  echo "Checking out Git $current_git_branch_name branch"
  git checkout $current_git_branch_name
}

# Retrieves the latest submodule SHAs from git.  If you only want to
# checkout the parent project's current SHAs, use function 'check_out_current_branch_project_shas'
#
# NOTE: this is only intended for Jenkins use; it presumes the 'git remote' to retrieve
# from to be 'origin'.  Whether it runs or not depends upon the setting of the Jenkins
# environment variable $AUTO_UPDATE_SUBMODULE_SHAS_ON_MASTER which must be set to 'true';
# any other value will cause the submodule update to NOT occur.
#
# See https://github.com/hedgeyedev/hedgeye_utilities_for_jenkins/wiki/Whether-to-Auto-Update-Submodule-SHAs
# for more information on turning $AUTO_UPDATE_SUBMODULE_SHAS_ON_MASTER on and off.
function update_submodules {

  if [ "$AUTO_UPDATE_SUBMODULE_SHAS_ON_MASTER" = "true" ]; then
    echo "***************************************************************"
    echo "   Auto-updating submodules for branch '$current_git_branch_name'"
    echo "***************************************************************"
    echo_cmd git submodule update --remote --merge
  else
    echo "DISABLED: Auto-updating submodules"
  fi
}

function get_current_git_branch_name {
  git rev-parse --abbrev-ref HEAD
}

function set_current_git_branch_name {
  current_git_branch_name=$(get_current_git_branch_name)
  echo "The current branch is '$current_git_branch_name'"
}

function set_git_status {
  git_status=$(git status)
}

function set_git_show {
  git_show=$(git show)
}

function set_git_submodule_dirs {
  git_submodule_dirs=( $(cat .gitmodules | grep 'path = ' | sed 's/path = //') )
}

function git_add_submodule_dirs {
  set_git_submodule_dirs
  for submodule_dir in "${git_submodule_dirs[@]}"; do
    git add $submodule_dir
  done
}

function git_add_and_commit_submodule_dirs {
  git_add_submodule_dirs
  set_git_status
  if [[ "$git_status" == *"Changes to be committed"* ]]; then
    echo "***************************************************************"
    echo "   Committing submodule auto-updates"
    echo "***************************************************************"
    git commit -m "auto-update all submodules"
  fi
}

function commit_and_push_submodule_sha_updates {
  echo "Starting commit_and_push_submodule_sha_updates..."
  if [ "$AUTO_UPDATE_SUBMODULE_SHAS_ON_MASTER" = "true" ]; then
    set_git_status
    if [[ "$git_status" == *"Changes not staged"* ]]; then
      git_add_and_commit_submodule_dirs
      set_git_show
      if [[ "$git_show" == *"auto-update all submodules"* ]]; then
        echo "***************************************************************"
        echo "   Pushing changes back to $current_git_branch_name"
        echo "***************************************************************"
        git push -v origin $current_git_branch_name
      else
        echo "No updated submodule SHAs were found to commit to parent"
      fi
    else
      echo "No unstaged changes to commit"
    fi
  else
    echo "DISABLED: Committing and pushing submodule SHA updates"
  fi
}

# ***********************************************************
# ******* END CODE TO SUPPORT AUTO SUBMODULE UPDATING *******
# ***********************************************************

echo "Finished loading roboconf functions"
