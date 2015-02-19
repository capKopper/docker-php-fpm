#!/bin/bash
set -eo pipefail

_log(){
  declare BLUE="\e[32m" WHITE="\e[39m" BOLD="\e[1m" NORMAL="\e[0m"
  echo -e "$(date --iso-8601=s)${BLUE}${BOLD} (info)${WHITE}:" $@${NORMAL}
}

_error(){
  declare RED="\e[91m" WHITE="\e[39m"
  echo -e "$(date --iso-8601=s)${RED} (error)${WHITE}:" $@
  exit 1
}

_debug()
{
  declare BLUE="\e[36m" WHITE="\e[39m"
  echo -e "$(date --iso-8601=s)${BLUE} (debug)${WHITE}:" $@
}


usage(){
  # """
  # Usage.
  # """
  echo "Usage: init.sh <username> <uid>"
  exit 1
}

check_user(){
  # """
  # Check if the given user is present.
  # If not add it.
  # """"
  local username=$1
  local uid=$2

  _log "Checking that user '$username' exists ..."
  if [ $(grep -c $username /etc/passwd) == "0" ]; then
    _debug "create user '$username'"
    useradd -m -u $uid -s /bin/bash $1
  fi
  chown $1:$1 /home/$1 && chmod 750 /home/$1
}

check_php_fpm_logdir(){
  # """
  # Check if the log dir for php-fpm exists.
  # """
  local username=$1
  local logdir="/var/log/php5-fpm"

  _log "Checking php-fpm log directory presence ..."

  if [ ! -d $logdir ]; then
    _debug "create directory '$logdir'"
    mkdir $logdir
  fi

  chown -R $username:$username $logdir
}

generate_php_fpm_pool(){
  # """
  # Generate the customer specific pool.
  #
  # Some environments variables can be used to defined specific configuration.
  # - PHP_FPM_MAX_EXECUTION_TIME : maximum execution time for a php process
  # - PHP_FPM_MEMORY_LIMIT : php memory limit
  # """
  local username=$1
  local pool_tpl="/tmp/tpl/php-fpm-pool.tpl"
  local pool_dir="/etc/php5/fpm/pool.d"
  local max_exec_time=${PHP_FPM_MAX_EXECUTION_TIME:-30}
  local memory_limit=${PHP_FPM_MEMORY_LIMIT:-128M}

  _log "Generate php-fpm customer pool ..."

  _debug "removing old pool files"
  rm -fr $pool_dir/*

  _debug "generate '$username' pool from template file ($pool_tpl)"
  _debug "=> max_execution_time set to: $max_exec_time"
  _debug "=> memory_limit set to: $memory_limit"
  sed -e 's/{{ CUSTOMER }}/'$username'/g' \
      -e 's/{{ PHP_FPM_MAX_EXECUTION_TIME }}/'$max_exec_time'/g' \
      -e 's/{{ PHP_FPM_MEMORY_LIMIT }}/'$memory_limit'/g' \
      $pool_tpl > /etc/php5/fpm/pool.d/$username.conf
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
  local username=$1
  local sv_dir="/etc/sv/php-fpm"
  local sv_run=${sv_dir}"/run"

  _log "Configure runit to launch php-fpm ..."

  if [ ! -d $sv_dir ]; then
    _debug "add php-fpm './run' script"
    mkdir $sv_dir
    cat > $sv_run << EOF
#!/bin/bash
exec chpst -u $username /usr/sbin/php5-fpm 2>&1
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

  _log "Activating $1 service ..."
  if [ ! -h /etc/service/$service ]; then
    ln -s $sv_dir /etc/service
  fi
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
  fi

  check_user $@
  check_php_fpm_logdir $1
  generate_php_fpm_pool $1
  configure_php_cli
  configure_runit $1
  activate_service "php-fpm"
  start_runit
}


main $@
