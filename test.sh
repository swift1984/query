#!/usr/bin/env bash

# The following functions are source from anycloud deployment's
# logging.sh script, which is again source from docf_main.sh
#   info()
#   ko()
#   ok()
#   debug()

G_LOG_DATE_FORMAT='+%Y%m%d_%H%M%S'

#######################################
# function name: do_backup(){
# Execute the backup; return backup_id
# INPUTS:
#   l_app_name: application name
# ON ERROR:
#   output the ncm command stderr
# EXAMPLE:
#   do_backup "cmgo-norc"
#######################################

do_backup() {
   local l_app_name=$1

   info "$(date "$G_LOG_DATE_FORMAT") Starting backup"
   backup_id="$(do_op "backup" "$l_app_name")"
   info "$(date "$G_LOG_DATE_FORMAT") Backup ID: $backup_id"

   info "$(date "$G_LOG_DATE_FORMAT") Waiting for backup to complete"
   wait_for_op "backup" "$l_app_name" "$backup_id"
}

#######################################
# function name: do_restore(){
# Execute the restore; return restore_id
# INPUTS:
#   l_app_name: application name
# ON ERROR:
#   output the ncm command stderr
# EXAMPLE:
#   do_restore "cmgo-norc" "$BACKUP_ID"
#######################################

do_restore() {
   local l_app_name=$1
   local backup_id=$2

   info "$(date "$G_LOG_DATE_FORMAT") Starting restore of $backup_id"
   restore_id="$(do_op "restore" "$l_app_name" "$backup_id")"
   info "$(date "$G_LOG_DATE_FORMAT") Restore ID: $restore_id"

   info "$(date "$G_LOG_DATE_FORMAT") Waiting for restore to complete"
   wait_for_op "restore" "$l_app_name" "$restore_id"
}

#######################################
# function name: do_op
# A WHILE loop to trigger application backup or restore
# INPUTS:
#   l_op: backup/restore
#   l_app_name: application name
#   l_rid: optional, required only for restore
# OUTPUTS:
#   backup id: returns backup id of backup/restore job
# ON ERROR:
#   error message
# EXAMPLE:
#   do_op "backup" "$APP_NAME"
#   do_op "restore" "$APP_NAME" "$RESTORE_BACKUP_ID_2"
#######################################
do_op() {
   local l_command l_op=$1 l_app_name=$2 l_rid=$3
   #local l_max_attempt=5 l_num_attempt=1 l_success=false
   
   #while [[ $l_success = false ]] && [[ $l_num_attempt -le $l_max_attempt ]]; do
      if [[ "$#" -eq 3 ]]; then
         l_command="ncm --raw app "$l_op" --id "$l_app_name" --backup_id "$l_rid" | jq -r '.details | keys[]'"
      elif [[ "$#" -eq 2 ]]; then
         l_command="ncm --raw app "$l_op" --id "$l_app_name" | jq -r '.details | keys[]'"
      else
         ko "$(date "$G_LOG_DATE_FORMAT") Invalid operation"
      fi
      # if [[ $? -eq 0 ]] && [[ -n "$l_id" ]]; then
      #    l_success=true
      # else
      #    info "Attempt $l_num_attempt failed. Retrying... "
      #    l_num_attempt=$(( l_num_attempt + 1 ))
      # fi
   #done
   eval "$l_command"
   # if [ $l_success = true ]; then
   #    echo "$l_id"
   # else
   #    ko "$(date "$G_LOG_DATE_FORMAT") Operation failed after $l_max_attempt attempts"
   # fi
}

#######################################
# function name: wait_for_op
# A FOR loop to wait for the application backup or restore
# INPUTS:
#   l_op: backup/restore
#   l_app_name: application name
#   l_id: backup_id/restore_id
# OUTPUTS:
#   status: return status of ncm backup/restore job
# ON ERROR:
#   error message
# EXAMPLE:
#   wait_for_op "backup" "$APP_NAME" "$backup_id"
#   wait_for_op "restore" "$APP_NAME" "$RESTORE_BACKUP_ID_2"
#######################################

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
      
      #info "$(date "$G_LOG_DATE_FORMAT") $status"
   done
   info "$(date "$G_LOG_DATE_FORMAT") $status"
}

#######################################
# function name: find_app_pod_name(){
# Find out the Application release name, pod name of the given DB services
# INPUTS:
#   component: CMDB/CMGO/CCAS
#   namespace
# OUTPUTS:
#   BR_RELEASE: release name of component according to brpolicy
#   POD_NAME: name of component pod according to brpolicy
#   APP_NAME: name of application according to brpolicy
# ON ERROR:
#   error message
# EXAMPLE:
#   find_app_pod_name "CMDB" "doc-norc"
#######################################

find_app_pod_name() {
   local l_component=$1
   local l_namespace=$2

   info "$(date "$G_LOG_DATE_FORMAT") Checking the brpolicy for $l_component"
   command="kubectl -n $l_namespace get brpolicy -o name | cut -d '/' -f2 |grep -i $l_component"
   if ! BR_RELEASE=$(eval "$command"); then
      ko "$(date "$G_LOG_DATE_FORMAT") $l_component deployment not found; or the brpolicy is not found."
   else
      info "$(date "$G_LOG_DATE_FORMAT") $l_component deployment found: $BR_RELEASE"
   fi

   POD_NAME="$BR_RELEASE"-0
   info "The pod name is $POD_NAME"

   APP_NAME=${BR_RELEASE%-*}
   # Remove second last hypen again, needed for CCAS only
   if [[ $l_component = 'CCAS' ]]; then
      APP_NAME=${APP_NAME%-*}
   fi
   info "The application name is $APP_NAME"
}

#######################################
# function name: change_cron_backup(){
# Find out the Application release name, pod name of the given DB services
# INPUTS:
#   l_app_name
#   l_action: disable/enable
# ON ERROR:
#   output the ncm command stderr
# EXAMPLE:
#   change_cron_backup "cmgo-norc" "disable"
#######################################

change_cron_backup() {
   local l_app_name=$1
   local l_action=$2

   info "$(date "$G_LOG_DATE_FORMAT") To $l_action scheduled backup for application $l_app_name"
   command="ncm --raw app backup --id $l_app_name --action $l_action"
   if ! eval "$command"; then
      ko "$(date "$G_LOG_DATE_FORMAT") Fail to $l_action scheduled backup for application $l_app_name"
   else
      info "$(date "$G_LOG_DATE_FORMAT") Done $l_action scheduled backup for application $l_app_name"
   fi
}

#######################################
# function name: fetch_backup_id(){
# Check the backup history, and return the nth last backup_id
# INPUTS:
#   l_br_release: name of brpolicy
#   l_namespace: the namespace in which application is running
#   l_index: the item number for the backup history
# OUTPUT:
#   BACKUP_ID: backup id in backup history
# ON ERROR:
#   output the kubectl command stderr
# EXAMPLE:
#   fetch_backup_id "cassandra-norc-ccas-apache" "doc-norc" "-1"
#######################################

fetch_backup_id() {
   local l_br_release=$1
   local l_namespace=$2
   local l_index=$3

   info "$(date "$G_LOG_DATE_FORMAT") Showing backup history"
   command="kubectl -n $l_namespace get brpolicy $l_br_release -o json | jq -r '.status.backupHistory[]'"
   if ! eval "$command"; then
      ko "$(date "$G_LOG_DATE_FORMAT") Unable to retrieve backup history"
   fi

   if ! BACKUP_ID=$(kubectl -n "$l_namespace" get brpolicy "$l_br_release" -o json | jq -r --argjson i "$l_index" '.status.backupHistory[$i]'); then
      ko "$(date "$G_LOG_DATE_FORMAT") Unable to retrieve backup id"
   else
      info "$(date "$G_LOG_DATE_FORMAT") RESTORE_BACKUP_ID[$l_index]: $BACKUP_ID"
   fi
}
