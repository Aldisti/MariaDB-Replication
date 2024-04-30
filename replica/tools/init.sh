#!/bin/bash

MARIADB_ROOT_PASSWORD="root"

MASTER_HOST="primary"
MASTER_USER="slave"
MASTER_PASSWORD="password"
MASTER_PORT="3306"


log_info() { echo "==> [INFO] "$@; }

exe_query() { mariadb -uroot -p$MARIADB_ROOT_PASSWORD -e "$@"; }


log_info "creating SLAVE user"
exe_query "CREATE USER IF NOT EXISTS '$MASTER_USER'@'%' IDENTIFIED BY '$MASTER_PASSWORD';"

log_info "granting privileges to slave"
exe_query "GRANT REPLICATION SLAVE ON *.* TO '$MASTER_USER'@'%';"

log_info "granting privileges to user"
exe_query "GRANT ALTER, CREATE, DELETE, DROP, INSERT, UPDATE, SELECT, INDEX, SHOW DATABASES, SLAVE MONITOR ON *.* TO 'user'@'%';"


if [ $IS_SLAVE -eq 1 ]; then
	log_info "changing MASTER info"
	exe_query "CHANGE MASTER TO MASTER_HOST='$MASTER_HOST', MASTER_USER='$MASTER_USER', MASTER_PASSWORD='$MASTER_PASSWORD', MASTER_PORT=$MASTER_PORT;"

	log_info "starting as SLAVE"
	exe_query "START SLAVE;"
else
	log_info "creating database"
	exe_query "CREATE DATABASE IF NOT EXISTS testdb;"

	log_info "creating table"
	exe_query "USE testdb; CREATE TABLE IF NOT EXISTS users (id INTEGER AUTO_INCREMENT PRIMARY KEY, username VARCHAR(32) UNIQUE);"

	log_info "starting as MASTER"
fi

