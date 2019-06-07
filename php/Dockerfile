FROM php:7.1-fpm-alpine as magento2_php

# Install Magento requirements
RUN \
    apk add --no-cache \
        autoconf \
        automake \
        freetype-dev \
        g++ \
        git \
        icu-dev \
        icu-libs \
        libjpeg-turbo-dev \
        libmcrypt-dev \
        libpng-dev \
        libxml2-dev \
        libxml2-utils \
        libxslt-dev \
        libwebp-dev \
        make \
        openssh-client \
        patch \
        perl \
        shadow \
        ssmtp \
        yarn && \
    apk add --no-cache --virtual .build-deps $PHPIZE_DEPS && \
    docker-php-ext-configure bcmath && \
    docker-php-ext-configure gd \
        --with-freetype-dir=/usr/include/ \
        --with-jpeg-dir=/usr/include/ \
        --with-png-dir=/usr/include/ \
        --with-webp-dir=/usr/include/ && \
    docker-php-ext-install -j$(nproc) \
        bcmath \
        intl \
        gd \
        opcache \
        pdo_mysql \
        soap \
        sockets \
        xsl \
        mcrypt \
        zip && \
    yes "" | pecl install apcu redis && \
    docker-php-ext-enable apcu redis && \
    perl -pi -e "s/mailhub=mail/mailhub=maildev/" /etc/ssmtp/ssmtp.conf && \
    perl -pi -e "s|;pm.status_path = /status|pm.status_path = /php_fpm_status|g" /usr/local/etc/php-fpm.d/www.conf && \
    yarn global add grunt-cli && \
    apk del .build-deps

## Install Composer globally
ENV COMPOSER_ALLOW_SUPERUSER 1
RUN \
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
    composer global require "hirak/prestissimo" --no-suggest --optimize-autoloader --classmap-authoritative
ENV PATH "${PATH}:/root/.composer/vendor/bin"

# Install netz98/n98-magerun2
RUN \
    curl -sS https://files.magerun.net/n98-magerun2.phar --output /usr/local/bin/magerun2 && \
    chmod +x /usr/local/bin/magerun2

# Automatically start the SSH agent when a new session is created
RUN echo 'eval $(ssh-agent) && ssh-add' >> /home/www-data/.profile

# Assign a new UID/GID to avoid using a generated value
RUN \
    usermod -u 1000 www-data && \
    groupmod -g 1000 www-data

# Install custom entrypoint
COPY entrypoint.sh /usr/local/bin/docker-custom-entrypoint
RUN chmod 777 /usr/local/bin/docker-custom-entrypoint
CMD ["php-fpm"]
ENTRYPOINT ["docker-custom-entrypoint"]

# ======================================================================================================================
FROM magento2_php as magento2_php_blackfire
RUN \
    curl -sS https://packages.blackfire.io/binaries/blackfire-php/1.25.0/blackfire-php-alpine_amd64-php-71.so \
        --output $(php -r "echo ini_get('extension_dir');")/blackfire.so && \
    docker-php-ext-enable blackfire
# ======================================================================================================================

# ======================================================================================================================
FROM magento2_php as magento2_php_xdebug
RUN \
    apk add --no-cache --virtual .build-deps $PHPIZE_DEPS && \
    yes "" | pecl install xdebug && \
    docker-php-ext-enable xdebug
# ======================================================================================================================