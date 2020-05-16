FROM php:7.2-apache-buster

# Install APCu and APC backward compatibility
RUN pecl install apcu \
    && pecl install apcu_bc-1.0.5 \
    && docker-php-ext-enable apcu --ini-name 10-docker-php-ext-apcu.ini \
    && docker-php-ext-enable apc --ini-name 20-docker-php-ext-apc.ini \
    && pecl clear-cache

# imagick and gd is for pdf-newspaper only
RUN apt-get update \
    && apt-get install -y libmagickwand-dev --no-install-recommends \
    && echo "" | pecl install imagick \
    && docker-php-ext-enable imagick

RUN docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install gd \
    && pecl clear-cache

RUN apt-get update \
    && apt-get install -y libtidy-dev libicu-dev libzip-dev \
    && docker-php-ext-install tidy \
    && docker-php-ext-enable tidy \
    && docker-php-ext-configure intl \
    && docker-php-ext-install intl \
    && docker-php-ext-configure zip \
    && docker-php-ext-install zip

# Clean repository
RUN apt-get clean \
    && rm -rf /var/lib/apt/lists/*
