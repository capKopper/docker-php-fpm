FROM ubuntu:14.04

# Install tools
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update
RUN apt-get install runit git -y

# Install php from sources
ENV PHP_VERSION 5.3.29
RUN apt-get install -y gcc make wget libxml2-dev libssl-dev libcurl4-openssl-dev libbz2-dev libpng12-dev libmcrypt-dev libmysqlclient-dev libfreetype6-dev libt1-dev libltdl-dev libjpeg62-dev && \
    mkdir /usr/include/freetype2/freetype && \
    ln -s /usr/include/freetype2/freetype.h /usr/include/freetype2/freetype/freetype.h
RUN wget -O /usr/src/php-${PHP_VERSION}.tar.bz2 http://bg2.php.net/get/php-${PHP_VERSION}.tar.bz2/from/this/mirror && \
    cd /usr/src && \
    tar xvjf php-${PHP_VERSION}.tar.bz2 && \
    cd php-${PHP_VERSION}/ && \
    ./configure \
      --enable-fpm \
      --enable-bcmath \
      --with-bz2 \
      --enable-calendar \
      --with-curl \
      --enable-dba \
      --enable-exif \
      --enable-ftp \
      --with-gd \
      --enable-gd-native-ttf \
      --with-freetype-dir=/usr \
      --with-t1lib=/usr \
      --with-jpeg-dir \
      --with-gettext \
      --enable-mbstring \
      --with-mcrypt \
      --with-mhash \
      --with-mysql \
      --with-mysqli \
      --with-openssl \
      --with-pcre-regex \
      --with-pdo-mysql \
      --enable-shmop \
      --enable-soap \
      --enable-sockets \
      --enable-sysvmsg \
      --enable-wddx \
      --enable-zip \
      --with-zlib && \
    make -j4 && \
    make install && \
    rm -fr /usr/src/php-${PHP_VERSION}*

# Install others common tools
RUN apt-get install graphicsmagick curl -y
RUN curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer

# PHP configuration
ADD files/php.ini etc/php5/cli/php.ini
ADD files/php.ini etc/php5/fpm/php.ini
# Add default php-fpm configuration
ADD files/php-fpm.conf /etc/php5/fpm/php-fpm.conf
RUN mkdir /etc/php5/fpm/pool.d/
# Templates files
ADD files/php-fpm-pool.tpl /tmp/tpl/

# Add init script
ADD files/init.sh /init.sh
RUN chmod u+x /init.sh && \
    mkdir /init.d

EXPOSE 9000
ENTRYPOINT ["/init.sh"]
CMD []