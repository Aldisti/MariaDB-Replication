#!/bin/bash

#               #
# ENV VARIABLES #
#               #

PRIMARY_HOST="primary"
PRIMARY_PORT="3306"
PRIMARY_ADMIN="root"
PRIMARY_ADMIN_PASSWORD="root"
PRIMARY_SLAVE="slave"
PRIMARY_SLAVE_PASSWORD="password"

REPLICA_HOST="replica"
REPLICA_PORT="3306"
REPLICA_ADMIN="root"
REPLICA_ADMIN_PASSWORD="root"
REPLICA_SLAVE="slave"
REPLICA_SLAVE_PASSWORD="password"

#                 #
# UTILS VARIABLES #
#                 #

# 1:DEBUG 2:INFO 3:WARNING 4:ERROR
LOG_LEVEL=3

# COMMANDS
DOCKER_EXEC="docker exec"

# QUERIES
IS_UP="SELECT 1;"
SLAVE_STATUS="SHOW SLAVE STATUS\G;"
MASTER_STATUS="SHOW MASTER STATUS;"
START_SLAVE="START SLAVE;"
STOP_SLAVE="STOP ALL SLAVES;"
RESET_SLAVE="RESET SLAVE ALL;"
SET_RDONLY="SET GLOBAL read_only=ON;"
UNSET_RDONLY="SET GLOBAL read_only=OFF;"

#           #
# FUNCTIONS #
#           #

# _log <log_type> <message>
_log() {
	printf -v _date '%(%F %H:%M:%S)T'
	echo -e "$_date [$1] $2" >&2
}

# log_err <error_message> [exit_code]
log_err() {
	if [ $LOG_LEVEL -lt 5 ]; then
		_log "ERROR" "$1"
	fi
	if ! [ -z "$2" ]; then
		exit $2
	fi
}

# log_warn <message>
log_warn() {
	if [ $LOG_LEVEL -lt 4 ]; then
		_log "WARNING" "$1"
	fi
}

# log_info <message>
log_info() {
	if [ $LOG_LEVEL -lt 3 ]; then
		_log "INFO" "$1"
	fi
}

# log_debug <message>
log_debug() {
	if [ $LOG_LEVEL -lt 2 ]; then
		_log "DEBUG" "$1"
	fi
}


# _exe_query <host> <user> <password> <query>
_exe_query() {
	if ! [ $# -eq 4 ]; then
		log_err "'_exe_query' received invalid arguments."
		return 1
	fi
	$DOCKER_EXEC "$1" mariadb -u$2 -p$3 -se "$4"
	local _errno="$?"
	if ! [ $_errno ]; then
		log_err "Cannot execute '$4' on '$1' with '$2'"
	fi
	return $_errno
}

# set_var <var_name> <var_value>
set_var() {
	if ! [ $# -eq 2 ] || [ -z "$1" ]; then
		log_err "'set_var' received invalid arguments." 1
	fi
	if [ -z "$2" ]; then
		log_err "'set_var' received invalid value for '$1'"
		return 1
	fi

	declare -g "$1"="$2"
	return 0
}

# _exe_on primary|replica <query>
exe_on() {
	if ! [ $# -eq 2 ]; then
		log_err "'exe_on' received invalid arguments."
		return 1
	fi
	local _host="${1^^}_HOST"
	local _admin="${1^^}_ADMIN"
	local _psswd="${1^^}_ADMIN_PASSWORD"

	_exe_query "${!_host}" "${!_admin}" "${!_psswd}" "$2"
	return $?
}

# _is_up primary|replica
is_up() {
	if ! [ $# -eq 1 ]; then
		log_err "'is_up' received invalid arguments."
		return 1
	fi
	local out="$(exe_on "$1" "$IS_UP")"
	log_debug "'is_up' '$1' got response: $out"
	if [ $? ] && [ "$out" = "1" ]; then
		return 0
	fi
	return 1
}

# is_slave primary|replica
is_slave() {
	if ! [ $# -eq 1 ]; then
		log_err "'is_slave' received invalid arguments."
		return 1
	fi
	local out="$(exe_on $1 "$SLAVE_STATUS" | \
				grep -we "Slave_IO_Running" -we "Slave_SQL_Running" | \
				awk '{print $2}' | tr '\n' ' ')"
	if ! [ $? ]; then
		return $?
	fi
	if grep -qwe "yes" <<< "${out,,}"; then
		if grep -qwe "no" <<< "${out,,}"; then
			log_warn "Detected a problem in slave '$1'"
		fi
		return 0
	fi
	return 1
}

# is_slave 

# switch_to_master primary|replica
switch_to_master() {
	is_up $1
	if ! [ $? ]; then
		log_info "'$1' is not available."
		return 1
	fi
	if ! is_slave $1; then
		log_info "'$1' is not a slave."
		return 1
	fi

	# TODO: check return codes
	exe_on $1 "$UNSET_RDONLY"
	exe_on $1 "$STOP_SLAVE"
	exe_on $1 "$RESET_SLAVE"
	log_info "'$1' is now master"
	return 0
}

# switch_to_slave primary|replica
switch_to_slave() {
	is_up $1
	if ! [ $? ]; then
		log_info "'$1' is not availble."
		return 1
	fi
	if is_slave $1; then
		log_info "'$1' is already a slave."
		return 1
	fi

	local change_master="CHANGE_MASTER_${1^^}"

	# TODO: check return codes
	exe_on $1 "${SET_RDONLY}"
	exe_on $1 "${!change_master}"
	exe_on $1 "${START_SLAVE}"
	log_info "'$1' is now slave"
	return 0
}

switch() {
	local slave=""
	local replica=""

	if is_slave "primary"; then
		slave="primary"
		master="replica"
	fi
	if is_slave "replica"; then
		if ! [ -z "$slave" ]; then
			log_err "Both primary and replica are slaves." 1
		fi
		slave="replica"
		master="primary"
	fi

	if [ -z "$master" ]; then
		log_warn "Master not found."
	else
		log_info "Detected '$master' as master"
	fi
	if [ -z "$slave" ]; then
		log_err "Slave not found." 3
	else
		log_info "Detected '$slave' as slave"
	fi

	if is_up "$master"; then
		switch_to_slave "$master"
		if ! [ $? ]; then
			log_warn "Cannot switch master to slave."
		fi
	fi

	switch_to_master "$slave"
	if ! [ $? ]; then
		log_err "Cannot switch slave into master."
	fi
}

#      #
# CODE #
#      #

# ask options
# check variables

# switch_to_master "primary"
# switch_to_slave "replica"

while [ $# -gt 0 ]; do
	tmp="$1"
	shift
	case $tmp in
		-? | -h | --help)
			echo "Working on it :)"
			exit 0
		;;
		--primary-host) set_var "PRIMARY_HOST" "$1" ;;
		--primary-port) set_var "PRIMARY_PORT" "$1" ;;
		--primary-user) set_var "PRIMARY_USER" "$1" ;;
		--primary-password) set_var "PRIMARY_PASSWORD" "$1" ;;
		--replica-host) set_var "REPLICA_HOST" "$1" ;;
		--replica-port) set_var "REPLICA_PORT" "$1" ;;
		--replica-user) set_var "REPLICA_USER" "$1" ;;
		--replica-password) set_var "REPLICA_PASSWORD" "$1" ;;

		--log-level)
			if ! [[ "$1" =~ ^[1-5]$ ]]; then
				echo -e "Invalid argument value for '--log-level'."
				exit 2
			fi
			set_var "LOG_LEVEL" "$1"
		;;
		*)
			log_err "Unrecognized option '$tmp'." "2"
		;;
	esac
	shift
done

# DYNAMIC VARIABLES

CHANGE_MASTER_REPLICA="CHANGE MASTER TO MASTER_HOST='$PRIMARY_HOST', MASTER_USER='$PRIMARY_SLAVE', MASTER_PASSWORD='$PRIMARY_SLAVE_PASSWORD', MASTER_PORT=$PRIMARY_PORT;"
CHANGE_MASTER_PRIMARY="CHANGE MASTER TO MASTER_HOST='$REPLICA_HOST', MASTER_USER='$REPLICA_SLAVE', MASTER_PASSWORD='$REPLICA_SLAVE_PASSWORD', MASTER_PORT=$REPLICA_PORT;"

switch

