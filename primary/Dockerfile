FROM mariadb

COPY ./conf/my.cnf /etc/mysql/conf.d/.
COPY ./tools/init.sh /docker-entrypoint-initdb.d/.

RUN chmod 664 /etc/mysql/conf.d/my.cnf
RUN chmod +x /docker-entrypoint-initdb.d/init.sh

