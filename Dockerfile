FROM ubuntu:14.04

ENV CONTAINER_VERSION 2016050401

# Install tools
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update
RUN apt-get install runit git wget unzip -y

# Install consul-template
ENV CT_VERSION 0.14.0
RUN cd /tmp && \
    wget https://releases.hashicorp.com/consul-template/${CT_VERSION}/consul-template_${CT_VERSION}_linux_amd64.zip && \
    unzip consul-template_${CT_VERSION}_linux_amd64.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/consul-template && \
    rm -fr consul-template_${CT_VERSION}_linux_amd64.zip

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
# (https://www.digitalocean.com/community/tutorials/how-to-install-linux-nginx-mysql-php-lemp-stack-on-ubuntu-14-04)
RUN sed -i -e 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php5/fpm/php.ini

# Add init script
ADD scripts/ /scripts/
RUN chmod u+x /scripts/init.sh && \
    mkdir /init.d

ADD templates/ /consul-template/templates

EXPOSE 9000
ENTRYPOINT ["/scripts/init.sh"]
CMD []
