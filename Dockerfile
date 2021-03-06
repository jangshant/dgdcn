FROM ubuntu:16.04
MAINTAINER Jangshant Singh <mail@jangshant.com>

ENV DEBIAN_FRONTEND noninteractive
## Install php nginx mysql supervisor drush git
RUN apt update
RUN    apt install -y php-fpm php-cli php-gd php-mcrypt php-mysql php-curl && \
				nginx \
				curl \
				supervisor \
				mysql-server \
				libpng12-dev libjpeg-dev libpq-dev \
				drush \
				git 
RUN	echo "mysql-server mysql-server/root_password password" | debconf-set-selections && \
    echo "mysql-server mysql-server/root_password_again password" | debconf-set-selections && \
    rm -rf /var/lib/apt/lists/*
    ## Configuration
RUN sed -i 's/^listen\s*=.*$/listen = 127.0.0.1:9000/' /etc/php/7.0/fpm/pool.d/www.conf && \
    sed -i 's/^\;error_log\s*=\s*syslog\s*$/error_log = \/var\/log\/php\/cgi.log/' /etc/php/7.0/fpm/php.ini && \
    sed -i 's/^\;error_log\s*=\s*syslog\s*$/error_log = \/var\/log\/php\/cli.log/' /etc/php/7.0/cli/php.ini && \
    sed -i 's/^key_buffer\s*=/key_buffer_size =/' /etc/mysql/my.cnf

COPY files/root /

WORKDIR /var/www/

VOLUME /var/www/

EXPOSE 80
RUN 	chown -R www-data:www-data /var/www /var/log/php
RUN	if [ ! -d /var/lib/mysql/mysql ];then mysqld --initialize-insecure --user=root --datadir=/var/lib/mysql; fi
RUN	chown -R mysql:mysql /var/lib/mysql && \
RUN	exec /usr/bin/supervisord --nodaemon -c /etc/supervisor/supervisord.conf
	
#ENTRYPOINT ["/entrypoint.sh"]
  
