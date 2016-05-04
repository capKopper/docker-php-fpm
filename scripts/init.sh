#!/bin/bash
#set -eo pipefail

# Required vars
CONSUL_LOGLEVEL=${CONSUL_LOGLEVEL:-info}


# load library
source /scripts/logging.lib.sh

function usage(){
cat <<USAGE
  init.sh <username> <uid>      Start a php-fpm server running with the given <username>/<uid>.

Configure using the following environment variables:

Project vars:
  PROJECT                       Set the project id
                                (default not set)

Consul vars:
  CONSUL_LOGLEVEL               Set the consul-template log level
                                (default info)

  CONSUL_CONNECT                URI for Consul agent
                                (default not set)

Checks vars:
  CHECK_CONSUL_CONNECT          Check if the Consul agent is available
                                (default not set)

  CHECK_CONSUL_CONNECT_TIMEOUT  Consul agent connection check timeout in seconds
                                (default 120)
USAGE
}

check_consul_connect() {
  # """
  # Check the Consul connexion.
  # """
  if [ -n "${CHECK_CONSUL_CONNECT}" ]; then
    _debug "checking if Consul ($CONSUL_CONNECT) is up..."
    MAX_SECONDS=${CHECK_CONSUL_CONNECT_TIMEOUT:-120}
    until curl -s --fail --max-time 1 -o /dev/null "http://${CONSUL_CONNECT}/v1/status/leader"; do
      sleep 1
      [[ "$SECONDS" -ge "$MAX_SECONDS" ]] && _warning "Consul not responding after $MAX_SECONDS seconds ($CONSUL_CONNECT)" && return 1
    done
    _debug "connection ok"
  fi
}

check_user(){
  # """
  # Check if the given user is present.
  # If not add it.
  # """"
  _log "Checking that '$FPM_USER' user exists..."
  if [ $(grep -c $FPM_USER /etc/passwd) == "0" ]; then
    _debug "create user '$FPM_USER' with uid '$FPM_USER_UID'"
    useradd -m -u $FPM_USER_UID -s /bin/bash $FPM_USER
  else
    _debug "user exists"
  fi
  chown $FPM_USER:$FPM_USER /home/$FPM_USER && chmod 750 /home/$FPM_USER
}

check_php_fpm_logdir(){
  # """
  # Check if the log dir for php-fpm exists.
  # """
  local logdir="/var/log/php5-fpm"

  _log "Checking if php-fpm log directory exists..."

  if [ ! -d $logdir ]; then
    _debug "create directory '$logdir'"
    mkdir $logdir
  fi

  chown -R $FPM_USER:$FPM_USER $logdir
}

generate_php_fpm_pool(){
  # """
  # Generate the customer specific pool.
  #
  # Some environments variables can be used to defined specific configuration.
  # - PHP_FPM_MAX_EXECUTION_TIME : maximum execution time for a php process
  # - PHP_FPM_MEMORY_LIMIT : php memory limit
  # - PHP_FPM_POST_MAX_SIZE: maximum size of data received from a POST request
  # - PHP_FPM_UPLOAD_MAX_FILESIZE: maximum size of a file to download
  # """
  local pool_tpl="/tmp/tpl/php-fpm-pool.tpl"
  local pool_dir="/etc/php5/fpm/pool.d"
  local max_exec_time=${PHP_FPM_MAX_EXECUTION_TIME:-30}
  local memory_limit=${PHP_FPM_MEMORY_LIMIT:-196M}
  local post_max_size=${PHP_FPM_POST_MAX_SIZE:-30M}
  local upload_max_filesize=${PHP_FPM_UPLOAD_MAX_FILESIZE:-24M}

  _log "Generate php-fpm customer pool ..."

  _debug "remove old files in the pool dir '$pool_dir'"
  rm -fr $pool_dir/*

  _debug "generate '$FPM_USER' pool from template file ($pool_tpl)"
  _debug "=> max_execution_time set to: $max_exec_time"
  _debug "=> memory_limit set to: $memory_limit"
  _debug "=> post_max_size set to: $post_max_size"
  _debug "=> upload_max_filesize set to: $upload_max_filesize"
  sed -e 's/{{ CUSTOMER }}/'$FPM_USER'/g' \
      -e 's/{{ PHP_FPM_MAX_EXECUTION_TIME }}/'$max_exec_time'/g' \
      -e 's/{{ PHP_FPM_MEMORY_LIMIT }}/'$memory_limit'/g' \
      -e 's/{{ PHP_FPM_POST_MAX_SIZE }}/'$post_max_size'/g' \
      -e 's/{{ PHP_FPM_UPLOAD_MAX_FILESIZE }}/'$upload_max_filesize'/g' \
      $pool_tpl > /etc/php5/fpm/pool.d/$FPM_USER.conf
}

configure_php_cli(){
  # """
  # PHP configuration for php-cli.
  #
  # Some environments variables can be used to defined specific configuration.
  # - PHP_CLI_MAX_EXECUTION_TIME : maximum execution time for a php process
  # - PHP_CLI_MEMORY_LIMIT : php memory limit
  # """
  local php_cli_ini="/etc/php5/cli/php.ini"
  local max_exec_time=${PHP_CLI_MAX_EXECUTION_TIME:-30}
  local memory_limit=${PHP_CLI_MEMORY_LIMIT:-256M}

  _log "Configure php-cli ..."
  _debug "=> max_execution_time set to: $max_exec_time"
  _debug "=> memory_limit set to: $memory_limit"
  sed -i \
      -e 's/^max_execution_time =.*$/max_execution_time = '$max_exec_time'/g' \
      -e 's/^memory_limit =.*$/memory_limit = '$memory_limit'/g' \
      $php_cli_ini
}

configure_runit(){
  # """
  # Configure runit to launch php-fpm service.
  # """
  local sv_dir="/etc/sv/php-fpm"
  local sv_run=${sv_dir}"/run"

  _log "Configure runit to launch php-fpm..."

  if [ ! -d $sv_dir ]; then
    _debug "add php-fpm './run' script"
    mkdir $sv_dir
    cat > $sv_run << EOF
#!/bin/bash
exec chpst -u $FPM_USER /usr/sbin/php5-fpm 2>&1
EOF
    chmod u+x $sv_run
  fi
}

activate_service(){
  # """
  # Activate the given service.
  # """
  local service=$1
  local sv_dir="/etc/sv/$service"

  _log "Activating $1 service..."
  if [ ! -h /etc/service/$service ]; then
    ln -s $sv_dir /etc/service
  fi
}

get_custom_php_actions(){
  # """
  # Get custom pre-start php actions for the PROJECT
  # and generate a bash script into /init.d/
  # """
  _log "Getting custom pre-start php actions..."

  # Check if CONSUL_CONNECT is set
  if [ -z "${CONSUL_CONNECT}" ]; then
    _warning "CONSUL_CONNECT environment variable is not set."

  else
    ctargs="${ctargs} -consul ${CONSUL_CONNECT}"

    check_consul_connect

    if [ "$?" == "0" ]; then
      _debug "generating custom pre-start php actions script..."
      consul-template -log-level ${CONSUL_LOGLEVEL} \
                      -retry=2s \
                      -once \
                      -template "/consul-template/templates/actions.sh.ctmpl:/init.d/pre-99-custom-actions.sh" \
                      ${ctargs}
    fi
  fi
}

run_pre-scripts(){
  # """
  # Run some bash scripts before starting runit.
  # """
  local scripts_pattern=$1
  shift
  local args=$@

  _log "Running pre-scripts..."
  for script in $(ls $scripts_pattern); do
    _debug "=> execute '$script' script"
    /bin/bash $script $args
  done
}

start_runit(){
  # """
  # Start runit.
  # """
  _log "Starting runit ..."
  runsvdir /etc/service
}


main(){
  if [ $# -ne 2 ]; then
    usage
    exit 1
  else
    FPM_USER=$1
    FPM_USER_UID=$2
    export FPM_USER
  fi

  check_user
  check_php_fpm_logdir
  generate_php_fpm_pool
  configure_php_cli
  configure_runit
  activate_service "php-fpm"
  get_custom_php_actions
  run_pre-scripts "/init.d/pre-*.sh" $@
  start_runit
}


main $@
