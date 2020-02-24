FROM php:7.2-apache-buster

# Install APCu and APC backward compatibility
RUN pecl install apcu \
    && pecl install apcu_bc-1.0.5 \
    && docker-php-ext-enable apcu --ini-name 10-docker-php-ext-apcu.ini \
    && docker-php-ext-enable apc --ini-name 20-docker-php-ext-apc.ini

RUN apt-get update \
    && apt-get install -y libtidy-dev libicu-dev \
    && docker-php-ext-install tidy \
    && docker-php-ext-enable tidy \
    && docker-php-ext-configure intl \
    && docker-php-ext-install intl

# Clean repository
RUN apt-get clean \
    && rm -rf /var/lib/apt/lists/*