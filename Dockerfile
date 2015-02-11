FROM ubuntu:14.04

# Install tools
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update
RUN apt-get install runit -y

# Install php and dependencies
ENV PHP_VERSION 5
RUN apt-get update && \
    apt-get install -y php5-cli php5-fpm php5-curl php5-mysql php5-gd php5-json php5-mcrypt
# Install others common tools
RUN apt-get install graphicsmagick curl -y
RUN curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer

# Override default php-fpm configuration
ADD files/php-fpm.conf /etc/php5/fpm/php-fpm.conf
# Templates files
ADD files/php-fpm-pool.tpl /tmp/tpl/

# Add init script
ADD files/init.sh /init.sh
RUN chmod u+x /init.sh

EXPOSE 9000
ENTRYPOINT ["/init.sh"]
CMD []
