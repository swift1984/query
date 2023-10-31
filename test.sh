#!/usr/bin/env bash

G_LOG_DATE_FORMAT='+%Y%m%d_%H%M%S'
DOS_NOC_NAMESPACE=doc-norc

GREEN="\e[32m"
RED="\e[31m"
BLUE="\e[34m"
NORMAL="\\033[0;39m"
YELLOW="\e[33m"
PINK="\e[1;35m"
export GREEN RED BLUE NORMAL YELLOW PINK

declare -A MAP_COLOR=(
  [green]=${GREEN}
  [red]=${RED}
  [blue]=${BLUE}
  [normal]=${NORMAL}
  [yellow]=${YELLOW}
  [pink]=${PINK}
)
export MAP_COLOR

function ko() {
  error "$@"
  exit 1
}
export -f ko

function error() {
  echo -e "${RED}[ERROR] $*${NORMAL}"
}
export -f error

function info() {
  echo -e "${BLUE}[INFO] $*${NORMAL}"
}
export -f info

function debug() {
  if [[ "${DEBUG:-}" == "1" ]]; then
    stderr echo "[DEBUG] $*"
  fi
}
export -f debug

do_op() {
   local l_id l_op=$1 l_app_name=$2 l_rid=$3
   local l_command
   local l_max_attempt=5 l_num_attempt=1 l_success=false
   
   while [[ $l_success = false ]] && [[ $l_num_attempt -le $l_max_attempt ]]; do
      if [[ "$#" -eq 3 ]]; then
         l_command="ncm --raw app "$l_op" --id "$l_app_name" --backup_id "$l_rid" | jq -r '.details | keys[]'"
      elif [[ "$#" -eq 2 ]]; then
         l_command="ncm --raw app "$l_op" --id "$l_app_name" | jq -r '.details | keys[]'"
      else
         ko "$(date "$G_LOG_DATE_FORMAT") Invalid operation"
      fi
      
      if ! l_id=$(eval "$l_command"); then
         info "Attempt $l_num_attempt failed. Retrying... "
         l_num_attempt=$(( l_num_attempt + 1 ))
      else
         l_success=true
      fi
   done

   if [ $l_success = true ]; then
      echo "$l_id"
   else
      ko "$(date "$G_LOG_DATE_FORMAT") Operation failed after $l_max_attempt attempts"
   fi
}

wait_for_op() {
   local n=0 max=10 delay=60 l_op=$1 l_app_name=$2 l_id=$3
   for((i=0;i<=max;i++)); do
      if [[ $n -lt $max ]]; then
         if [[ "$l_op" == "backup" ]]; then
            status=$(ncm --raw app backupJob --id "$l_app_name" --backup_id "$l_id" | jq -r '.status')
         elif [[ "$l_op" == "restore" ]]; then
            status=$(ncm --raw app restoreJob --id "$l_app_name" --restore_id "$l_id" | jq -r '.status')
         else
            ko "$(date "$G_LOG_DATE_FORMAT") Invalid operation"
         fi
         
         if [[ "$status" == "Success" ]]; then
            ok "$(date "$G_LOG_DATE_FORMAT") Operation $l_op completed"
            break
         fi
         sleep $delay
         n=$((n+1))
      else
         ko "$(date "$G_LOG_DATE_FORMAT") Operation failed"
      fi
      
      info "$(date "$G_LOG_DATE_FORMAT") $status"
   done
}

do_backup() {
   local l_app_name=$1

   info "$(date "$G_LOG_DATE_FORMAT") Starting backup"
   backup_id="$(do_op "backup" "$l_app_name")"
   info "$(date "$G_LOG_DATE_FORMAT") Backup ID: $backup_id"

   #info "$(date "$G_LOG_DATE_FORMAT") Waiting for backup to complete"
   #wait_for_op "backup" "$l_app_name" "$backup_id"
}

do_backup "cmdb-norc-doc-norc-aaa"
