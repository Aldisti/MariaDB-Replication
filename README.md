
# MariaDB Replication

## Introduction

In this example of replication we have two databases: main and replica.
The replica copies all transactions of the main and keeps synchronized with it, in this way, we have a perfect copy of the main.
When the need arises, we can switch the replica to be the main and keep reading and writing our data.
Then we just have to synchronize the old main (new replica) with the new main (old replica) and, when it's done, we can switch back the new replica to its original role.

## Architecture

In this demostration of the MariaDB replication process we have two docker containers, both with an almost identical configuration. Thus, it'll be described just one container.

### Container

The docker compose is pretty simple and follows the guidelines of the docker hub [page](https://hub.docker.com/_/mariadb) on MariaDB. The only difference is the environment variable IS_SLAVE that is used to decide whether to start the container as master or as slave.

### Image

The base image used to build the container is the official [one](https://hub.docker.com/_/mariadb) provided by MariaDB.
But, during the build process, two our files are copied into the container:
- my.cnf
- init.sh

These files will be used to correctly configure the database.

## Database

We have two databases, main (or primary/master) and replica (or slave), they both have the same initialization script (init.sh) and conf file (my.cnf).
There is only one major difference: the server_id in the conf file. It has to be "unique for each server in the replication group", master included.

### init.sh

When the script init.sh is run we do some common operations:
- create a slave user (so it can be used by a replica server).
- assign to the user the [REPLICA SLAVE](https://dev.mysql.com/doc/refman/8.0/en/privileges-provided.html#priv_replication-slave) privilege.
- set the master information.

We do these operations also on the main, so, in case, we are ready to switch the roles.
Then follows an if statement that allows us to run different commands based on the type of the database, if it's master or slave.
- slave case, we start the slave and nothing more.
- master case, we create a database and a table for demostration purposes.

## Replication

At the begin, when we start the containers, we have:
- the main who receives all the requests and saves the updates in the binary log as binlog events.
- the replica who reads the main's binary log in order to replicate the data in the main.

Now that the two databases are up and running, if we want to switch the roles we can simply run the script switchdb.sh.
This script will set the main as read-only, then will wait for the replica to fully synchronize with the main and then switch the roles.


