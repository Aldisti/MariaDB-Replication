
# MariaDB Replication

## Introduction

In this example of replication we have two databases: **primary** and **replica**.
The **replica** copies all transactions of the **primary** and keeps synchronized with it, in this way, we have an exact copy of the **primary**.
When the need arises, we can switch the **replica** to be the **primary** and keep reading and writing our data without any loss.
Then we just have to synchronize the old **primary** (new **replica**) with the new **primary** (old **replica**) and, when it's done, we can switch back the new **replica** (old **primary**) to its original role.

> [!IMPORTANT]
> In this demo the replication is asynchronous, however, it can also be semi-synchronous or fully-synchronous.

## Architecture

In this demonstration of the MariaDB Replication process, we have two docker containers, both with an almost identical configuration. Thus, it'll be described only one container.

### Container

The docker-compose is pretty simple and follows the guidelines of the docker hub [page](https://hub.docker.com/_/mariadb) on MariaDB.
The only difference is the environment variable `IS_SLAVE` which is used to decide whether to start the container as *master* or as *slave*.

### Image

The base image used to build the container is the official [one](https://hub.docker.com/_/mariadb) provided by MariaDB.
But, during the build process, two of our files are copied into the container:
- `my.cnf`,
- `init.sh`.

These files will be used to correctly configure the database.

## Database

We have two databases, **primary** (or *master*) and **replica** (or *slave*), and they both have almost the same initialization script (`init.sh`) and conf file (`my.cnf`).
There is only one major difference: the server_id in the conf file.

> [!WARNING]
> The `server_id` has to be unique for *master* and *slave* both.

### init.sh

When the script `init.sh` is run it does some common operations:
- creates a *slave* user, so it can be used by a **replica** server;
- assigns to the previously created user the [REPLICA SLAVE](https://dev.mysql.com/doc/refman/8.0/en/privileges-provided.html#priv_replication-slave) privilege.

We do these operations also on the **primary**, so, in case, we are ready to switch roles.
Then follows an if statement that allows us to run different commands based on the type of the database, if it is *master* or *slave* (we know that based on the `IS_SLAVE` env variable).
- *slave* case, set the *master* information, like host, port, etc, and start the *slave*.
- *master* case, creates a database and a table for demonstration purposes.

## Replication

In the beginning, when we start the containers, we have:
- the **primary** who receives all the requests and saves the updates in the binary log as binlog events.
- the **replica** that reads the **primary**'s binary log in order to replicate its data.

> [!CAUTION]
> The binary log can contain sensible information, thus it should be kept safe.

### Switch

> [!IMPORTANT]
> The `switchdb.sh` script is being replaced by `switch.sh` which is a newer version with better error handling than the former one.

Now that the two databases are up and running, if we want to switch the roles we can simply run the script `switchdb.sh`.

This script will:
1. set the **primary** as read-only (in order to stop all write operations),
2. then will wait for the **replica** to fully synchronize with the **primary**,
3. switch roles when the **replica** has finished.

> [!NOTE]
> All of these operations can be done manually. The `switchdb.sh` is just an automation of those commands.

### Setup

To recreate a basic and functional replication system, you have to:
1. give to the **primary** and the **replica** unique server_ids;
1. activate the binary log on the **primary**;
1. create a *slave* user on the **primary** and grant him the REPLICATION SLAVE privilege;
1. set the *master* info on the **replica**;
1. start the *slave* on the **replica**.

> [!TIP]
> Many of these actions could be very helpful to apply to the *slave* too.


