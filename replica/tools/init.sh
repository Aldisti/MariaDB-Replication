#!/bin/bash

MARIADB_ROOT_PASSWORD="root"

PRIMARY_HOST="primary"
PRIMARY_USER="replica"
PRIMARY_PASSWORD="password"
PRIMARY_PORT="3306"


log_info() { echo "==> [INFO] "$@; }

exe_query() { mariadb -uroot -p$MARIADB_ROOT_PASSWORD -e "$@"; }


log_info "creating REPLICA user"
exe_query "CREATE USER IF NOT EXISTS '$PRIMARY_USER'@'%' IDENTIFIED BY '$PRIMARY_PASSWORD';"

log_info "granting privileges to replica"
exe_query "GRANT REPLICATION SLAVE ON *.* TO '$PRIMARY_USER'@'%';"

log_info "granting privileges to user"
exe_query "GRANT ALTER, CREATE, DELETE, DROP, INSERT, UPDATE, SELECT, INDEX, SHOW DATABASES, SLAVE MONITOR ON *.* TO 'user'@'%';"


if [ $IS_REPLICA -eq 1 ]; then
	log_info "changing PRIMARY info"
	exe_query "CHANGE MASTER TO MASTER_HOST='$PRIMARY_HOST', MASTER_USER='$PRIMARY_USER', MASTER_PASSWORD='$PRIMARY_PASSWORD', MASTER_PORT=$PRIMARY_PORT;"

	log_info "starting as REPLICA"
	exe_query "START SLAVE;"
else
	log_info "creating database"
	exe_query "CREATE DATABASE IF NOT EXISTS testdb;"

	log_info "creating table"
	exe_query "USE testdb; CREATE TABLE IF NOT EXISTS users (id INTEGER AUTO_INCREMENT PRIMARY KEY, username VARCHAR(32) UNIQUE);"

	log_info "starting as PRIMARY"
fi

