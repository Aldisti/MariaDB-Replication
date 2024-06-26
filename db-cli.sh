#!/bin/bash

DB_NAME="testdb"
DB_TABLE="users"

FIRST_HOST="primary"
FIRST_PORT="3306"
FIRST_USER="user"
FIRST_PASSWORD="password"
FIRST_REPLICA="replica"
FIRST_REPLICA_PASSWORD="password"

SECOND_HOST="replica"
SECOND_PORT="3306"
SECOND_USER="user"
SECOND_PASSWORD="password"
SECOND_REPLICA="replica"
SECOND_REPLICA_PASSWORD="password"


# UTILS
ACTUAL_PRIMARY=1
ERRNO=0

# COLORS
RED="\033[38;5;124m"
CYAN="\033[38;5;81m"
BLUE="\033[38;5;21m"
GREEN="\033[38;5;40m"
PURPLE="\033[38;5;105m"
ORANGE="\033[38;5;11m"
RESET="\033[0m"

_error() { echo -e "${RED}Error${RESET}: $1"; }
_invalid() { echo -e "${ORANGE}Invalid${RESET}: $1"; }

# 1: container name or host name
# 2: user on database with right privileges
# 3: password of the user
# 4: query to execute on database
_exe_query() {
	docker exec $1 mariadb -u$2 -p$3 -e "$4"
	ERRNO=$?
#	echo "recv: |$4|"
	if ! [ $ERRNO -eq 0 ];then
		_error "failed query '$4' on host '$1'"
		return 1
	fi
	return 0
}

# 1: query to execute on database
_exe_first() {
	_exe_query "$FIRST_HOST" "$FIRST_USER" "$FIRST_PASSWORD" "$1";
	return $?;
}
_exe_second() {
	_exe_query "$SECOND_HOST" "$SECOND_USER" "$SECOND_PASSWORD" "$1";
	return $?
}

_exe_primary() {
	if [ $ACTUAL_PRIMARY -eq 1 ];then
		_exe_first "$1"
		return $?
	elif [ $ACTUAL_PRIMARY -eq 2 ];then
		_exe_second "$1"
		return $?
	else
		_error "num '$ACTUAL_PRIMARY' not valid in '_exe_primary'"
	fi
	return 0
}

help() {
	echo -e "${PURPLE}Commands${RESET}"
	echo
	echo -e "\t${CYAN}HELP${RESET}: shows this list."
	echo -e "\t${CYAN}SHOW${RESET} [1|2]: shows the database N table."
	echo -e "\t${CYAN}STATUS${RESET} [1|2]: shows the database N status."
	echo -e "\t${CYAN}ADD${RESET} [USERNAME]: adds a new user called USERNAME."
	echo -e "\t${CYAN}CYCLE${RESET} [N]: adds N random users to the database."
	echo -e "\t${CYAN}SWITCH${RESET}: switch database roles, primary -> replica and viceversa."
	echo -e "\t${CYAN}EXIT${RESET}: exits the CLI."
}

show() {
	if [ -z "$1" ] || [ "$1" = "1" ]; then
		echo -e "${BLUE}$FIRST_HOST${RESET}"
		_exe_first "USE $DB_NAME; SELECT * FROM $DB_TABLE;"
	fi
	if [ -z "$1" ] || [ "$1" = "2" ]; then
		echo -e "${BLUE}$SECOND_HOST${RESET}"
		_exe_second "USE $DB_NAME; SELECT * FROM $DB_TABLE;"
	fi
}

_status() {
	if [ -z "$1" ] || [ "$1" = "1" ]; then
		echo -e "${BLUE}$FIRST_HOST${RESET}"
		_exe_first "SHOW SLAVE STATUS\G;" | grep -we "Slave_IO_Running" -we "Slave_SQL_Running" | awk '{print $1 " " $2}'
	fi
	if [ -z "$1" ] || [ "$1" = "2" ]; then
		echo -e "${BLUE}$SECOND_HOST${RESET}"
		_exe_second "SHOW SLAVE STATUS\G;" | grep -we "Slave_IO_Running" -we "Slave_SQL_Running" | awk '{print $1 " " $2}'
	fi
}

add() {
	if [ -z "$1" ]; then
		_invalid "no USERNAME inserted."
		return 1
	fi
#	echo "name: $DB_NAME"
	_exe_primary "USE ${DB_NAME}; INSERT INTO $DB_TABLE (username) values ('$1')"
	if ! [ $? -eq 0 ]; then
		echo -e "Try with a different username."
	else
		echo -e "${GREEN}$1${RESET} added successfully!"
	fi
}

switch() {
	if [ $ACTUAL_PRIMARY -eq 1 ]; then
		./switch.sh \
			--primary-host "$FIRST_HOST" \
			--primary-port "$FIRST_PORT" \
			--primary-user "$FIRST_REPLICA" \
			--primary-password "$FIRST_REPLICA_PASSWORD" \
			--replica-host "$SECOND_HOST" \
			--replica-port "$SECOND_PORT" \
			--replica-user "$SECOND_REPLICA" \
			--replica-password "$SECOND_REPLICA_PASSWORD"
		ERRNO=$?
	elif [ $ACTUAL_PRIMARY -eq 2 ]; then
		./switch.sh \
			--primary-host "$SECOND_HOST" \
			--primary-port "$SECOND_PORT" \
			--primary-user "$SECOND_REPLICA" \
			--primary-password "$SECOND_REPLICA_PASSWORD" \
			--replica-host "$FIRST_HOST" \
			--replica-port "$FIRST_PORT" \
			--replica-user "$FIRST_REPLICA" \
			--replica-password "$FIRST_REPLICA_PASSWORD"
		ERRNO=$?
	else
		_error "num '$ACTUAL_PRIMARY' not valid in 'switch'"
		return 1
	fi
	if [ $ERRNO -eq 0 ]; then
		echo -e "${GREEN}switch${RESET} successfull!"
		ACTUAL_MASTER=$((ACTUAL_MASTER % 2 + 1))
	else
		echo -e "${RED}switch${RESET} failed with error $ERRNO."
		ACTUAL_PRIMARY=$((ACTUAL_PRIMARY % 2 + 1))
	fi
}


echo -e " Welcome to the Replication Demo CLI"
echo
help

while :; do
	echo
	read -p "$(basename $0)$ " cmd
	arg="$(echo "$cmd" | grep ' ' | cut -d ' ' -f2)"
#	echo "cmd: |$cmd| arg: |$arg|"
	echo
	case "$(echo "$cmd" | cut -d ' ' -f1 | tr a-z A-Z)" in
		HELP)
			help
		;;
		SHOW)
			show "$arg"
		;;
		ADD)
			add "$arg"
		;;
		CYCLE)
			if ! grep -q "^[0-9]*$" <<< "$arg"; then
				_invalid "value '$arg' should be a number."
			fi
			i=0
			while [ $i -lt $arg ]; do
				add "$(tr -dc a-z < /dev/urandom | head -c 13)"
				i=$((i + 1))
			done
		;;
		SWITCH)
			switch
		;;
		STATUS)
			_status "$arg"
		;;
		EXIT)
			echo -e "${PURPLE}Exiting the CLI${RESET}"
			break
		;;
		"")
		;;
		*)
			_invalid "command '$cmd' not found."
		;;
	esac
done


