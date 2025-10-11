FROM php:8.4-apache-trixie

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Install APCu and APC backward compatibility
RUN pecl install apcu \
    && docker-php-ext-enable apcu --ini-name 10-docker-php-ext-apcu.ini

# imagick and gd is for pdf-newspaper only
RUN apt-get update -q -y \
    && apt-get install -q -y libmagickwand-dev --no-install-recommends \
    && echo "" | pecl install imagick \
    && docker-php-ext-enable imagick

RUN docker-php-ext-configure gd \
    && docker-php-ext-install gd

RUN apt-get update -q -y \
    && apt-get install -q -y libtidy-dev libicu-dev libzip-dev \
    && docker-php-ext-install tidy \
    && docker-php-ext-enable tidy \
    && docker-php-ext-configure intl \
    && docker-php-ext-install intl \
    && docker-php-ext-configure zip \
    && docker-php-ext-install zip

# Clean repository
RUN apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && pecl clear-cache
