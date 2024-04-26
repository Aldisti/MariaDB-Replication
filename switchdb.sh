#!/bin/bash

MASTER_ROOT_PASSWORD="root"
MASTER_HOST="primary"
MASTER_PORT="3306"
MASTER_USER="slave"
MASTER_PASSWORD="password"

SLAVE_ROOT_PASSWORD="root"
SLAVE_HOST="replica"
SLAVE_PORT="3306"
SLAVE_USER="slave"
SLAVE_PASSWORD="password"



error() { echo "Error: $1"; exit $2; }

usage()
{
	local me=$(basename $0)
	if [ -n "$1" ]; then
		echo "$me: unrecognized option '$1'"
	fi
	echo "Usage: $me [OPTION]... MODE"
	echo "Try '$me --help' for more information."
}

# CHECK OPTIONS

while [ $# -gt 0 ]; do
	tmp="$1"
	shift
	case $tmp in
		-? | -h | --help)
			echo "Working on it :)"
			exit 0
		;;
		-mH | --master-host)
			MASTER_HOST="$1"
		;;
		-mP | --master-port)
			MASTER_PORT="$1"
		;;
		-mu | --master-user)
			MASTER_USER="$1"
		;;
		-mp | --master-password)
			MASTER_PASSWORD="$1"
		;;
		-sH | --slave-host)
			SLAVE_HOST="$1"
		;;
		-sP | --slave-port)
			SLAVE_PORT="$1"
		;;
		-su | --slave-user)
			SLAVE_USER="$1"
		;;
		-sp | --slave-password)
			SLAVE_PASSWORD="$1"
		;;
		*)
			usage $tmp
			exit 1
		;;
	esac
	if [ -z "$1" ]; then
		error "no argument to '$tmp' option." 3
	fi
	shift
done

#echo "mh: $MASTER_HOST"
#echo "sh: $SLAVE_HOST"

if [ "$MASTER_HOST:$MASTER_PORT" = "$SLAVE_HOST:$SLAVE_PORT" ]; then
	echo "Error: master host should be different from the slave host"
	exit 2
fi

# GET MODE

#if ! [ $# -eq 1 ]; then
#	usage
#	exit 2
#fi

# _exe_query() 1: hostname 2: root password 3: query
_exe_query()
{
	if ! [ $# -eq 3 ]; then
		error "_exe_query invalid arguments" 4
	fi
	docker exec "$1" mariadb -uroot -p$2 -e "$3"
	if ! [ $? -eq 0 ];then
		error "'$1' failed to execute '$3'" $?
	fi
}

# exe_master() 1: query
exe_master() { _exe_query "$MASTER_HOST" "$MASTER_ROOT_PASSWORD" "$1"; }

# exe_slave() 1: query
exe_slave() { _exe_query "$SLAVE_HOST" "$SLAVE_ROOT_PASSWORD" "$1"; }


get_master_info()
{
	local master_status="$(exe_master "show master status;" | awk '{print $1" "$2}' | tail -n +2)"
	MASTER_FILE="$(echo $master_status | awk '{print $1}')"
	MASTER_POS="$(echo $master_status | awk '{print $2}')"
	echo -e "file: $MASTER_FILE\npos: $MASTER_POS"
}

get_slave_info()
{
	local slave_status="$(exe_slave "show slave status\G;" | grep -we "Master_Log_File" -we "Read_Master_Log_Pos" | awk '{print $2}')"
	SLAVE_FILE="$(echo "$slave_status" | head -1)"
	SLAVE_POS="$(echo "$slave_status" | tail -1)"
	echo -e "file: $SLAVE_FILE\npos: $SLAVE_POS"
}

check_status()
{
	get_master_info
	get_slave_info
	if [ "$MASTER_FILE" = "$SLAVE_FILE" ] && [ "$MASTER_POS" = "$SLAVE_POS" ]; then
		return 0
	fi
	return 1
}

# STOP ALL SLAVES
# RESET ALL SLAVES
# SET @@global.read_only=0; # disable read-only mode
switch_master()
{
	exe_master "SET @@global.read_only=1;"

	local retries=10
	while ! [ check_status ]; do
		if ! [ $retries -gt 0 ]; then
			error "SLAVE and MASTER are not synced!" 42
		fi
		sleep 1
		retries=$((retries - 1))
	done

	exe_slave "STOP ALL SLAVES;"
	exe_slave "RESET SLAVE ALL;"
	echo "$SLAVE_HOST got promoted to MASTER!"
	exe_master "CHANGE MASTER TO MASTER_HOST='$SLAVE_HOST', MASTER_USER='$SLAVE_USER', MASTER_PASSWORD='$SLAVE_PASSWORD', MASTER_PORT=$SLAVE_PORT;"
	exe_master "SET @@global.read_only=0;"
	exe_master "START SLAVE;"
	echo "$MASTER_HOST got demoted to SLAVE"
}

#get_master_info
#get_slave_info
#
#check_status
#echo "check: $?"

switch_master


