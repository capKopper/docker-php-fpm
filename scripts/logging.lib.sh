# """
# Logging common functions.
# """
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

_warning(){
  declare RED="\e[91m" WHITE="\e[39m"
  echo -e "$(date --iso-8601=s)${RED} (warning)${WHITE}:" $@
}