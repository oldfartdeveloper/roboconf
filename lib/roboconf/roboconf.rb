class Roboconf

  # @return true if a program exists; else false
  def check(program_name)
    puts "checking for #{program_name}..."
    system "hash #{program_name} 2>&-"
    $?.success?
  end

  def check_verbal(program_name)
    found = check(program_name)
    puts "Program #{program_name} is#{found ? '' : 'not'} found"
    found
  end

  def git_modules
    exit 1 unless check 'git'
    git_submodule 'init'
    git_submodule 'sync'
    git_submodule 'update'
  end

  # Make sure bundler is installed
  #
  # @param [String] bundler_version the version of bundler to install
  # @param [String] opts command line arguments to be added to "gem install bundler"
  def bundler(bundler_version, opts)
    check_verbal 'rvm'
    check_verbal 'gem'
    unless check_verbal 'bundler'
      version = (bundler_version.nil? || bundler_version =~ /^\s*$/) ? '' : "--version #{bundler_version}"
      echo_cmd "gem install bundler #{version} --no-rdoc --no-ri"
    end
    echo_cmd "bundle install #{opts}"
  end

  def npm
    exit 1 unless check_verbal 'node'
    unless check_verbal 'npm'
      echo_cmd 'npm install'
    end
  end

=begin

def rails-activerecord
  bundle exec rake db:create
  bundle exec rake db:migrate
end

def padrino-activerecord
  bundle exec padrino rake ar:create
  bundle exec padrino rake ar:create -e test
  bundle exec padrino rake ar:migrate
  bundle exec padrino rake ar:migrate -e test
  bundle exec padrino rake seed
end

def passenger
  mkdir -p tmp
  touch tmp/restart.txt
end

def echo_cmd
  puts "\$ $*"
  $*
end

def fire_up_heroku_app
  curl "http://${app}.herokuapp.com/" &> /dev/null
end

# Loads $HEROKU_CONSTANTS or exits
def load_heroku_constants
  if [ -z "$HEROKU_CONSTANTS" ]; then
  puts "Error: \$HEROKU_CONSTANTS is undefined"
  puts "\$HEROKU_CONSTANTS should reference a file holding key=value pairs of Heroku configuration settings"
  exit 1
  elif [[ -f $HEROKU_CONSTANTS ]]; then
  source $HEROKU_CONSTANTS
  else
    puts "Error: Failed to find $HEROKU_CONSTANTS"
    exit 1
    fi
    }

# "Private" function called by run_heroku_config_if_settings_changed.
# Sets the heroku_vars_changed variable to true/false depending on whether
# the Heroku environment variables in $HEROKU_CONSTANTS differ from what
# is currently configured for the Heroku app.
def detect_heroku_vars_changed
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
          puts "Key '$new_key' already has value '$new_value'"
          else
            heroku_vars_changed=true
            puts "Key '$new_key' will be set to value '$new_value'"
            fi
            done < $HEROKU_CONSTANTS
            }

# runs 'heroku config:set' only if the Heroku configuration settings have changed
def run_heroku_config_if_settings_changed
              detect_heroku_vars_changed
              if ! $heroku_vars_changed; then
                puts "Skipping 'heroku config:add' because Heroku variables unchanged"
              else
                puts "Running 'heroku config:add' because Heroku variables have changed"
                heroku config:set $HEROKU_CONFIG_ADD_CONSTANTS --app "$app"
                fi
end
                
def show_prep_release_usage_and_exit
                  cat <<EOF
Usage: $0 heroku-app-name

Function: Release app to heroku-app-name.herokuapp.com as staging/testing environment before a release.

Example: $0 hedgeye-cedar-smarketing
Example: $0 hedgeye-smailroom
EOF
                  exit 1
end
def show_release_usage_and_exit
                  cat <<EOF
Usage: $0 heroku-app-name

Function: Release app to heroku-app-name.herokuapp.com as production environment.

Example: $0 hedgeye-cedar-marketing
Example: $0 hedgeye-reader
EOF
                  exit 1
end
def show_config_usage_and_exit
                  cat <<EOF
Usage: $0 heroku-app-name

Function: Update Heroku configuration.

Example: $0 hedgeye-labs
EOF
                  exit 1
end
def heroku_addon
                  name="$1"
                  match=$(ruby -e "puts %x(heroku addons --app "$app").match(/$name/).to_s")

                  if [ '' == "$match" ]; then
                    puts "Installing '$name' because it's not yet installed"
                    echo_cmd heroku addons:add $name --app "$app"
                  else
                    puts "Not installing '$name' because it's already installed"
                    fi
end
                    
def update_submodules_and_commit_shas
                      git checkout master
                      echo_cmd git_submodule update --remote --merge
                      git_status=$(git status)
                      if [[ "$git_status" == *"Changes not staged"* ]]; then
                      puts "***************************************************************"
                      puts "**********        Auto-updating submodules &         **********"
                      puts "**********       pushing changes back to master      **********"
                      puts "***************************************************************"
                      git commit -a -m "auto-update all submodules"
                      git checkout master
                      git push -v origin master
                      fi
end
=end

  private

  def git_submodule(action)
    system "git submodule #{action}"
  end

  def echo_cmd(command)
    puts command
    system command
  end

end
