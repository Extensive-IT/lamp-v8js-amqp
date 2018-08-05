FROM php:7.2-apache
MAINTAINER Extensive IT B.V. <info@extensive-it.nl>

# Install required dependencies
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends git curl wget software-properties-common build-essential python vim libglib2.0-dev patchelf

# Install depot_tools first (needed for source checkout)
RUN cd /tmp && git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
ENV PATH /tmp/depot_tools:$PATH

# Download v8
RUN cd /tmp && fetch v8
RUN cd /tmp/v8 && gclient sync

# Setup GN
RUN cd /tmp/v8 && tools/dev/v8gen.py -vv x64.release -- is_component_build=true

# Build
RUN cd /tmp/v8 && ninja -C out.gn/x64.release/

# Install to /opt/v8/
RUN mkdir -p /opt/v8/lib
RUN mkdir /opt/v8/include
RUN cd /tmp/v8 && cp out.gn/x64.release/lib*.so out.gn/x64.release/*_blob.bin /opt/v8/lib/
RUN for A in /opt/v8/lib/*.so; do patchelf --set-rpath '$ORIGIN' $A; done
RUN cd /tmp/v8 && cp -R include/* /opt/v8/include/

# Install v8js
RUN cd /tmp && git clone https://github.com/phpv8/v8js.git
RUN cd /tmp/v8js && phpize
RUN cd /tmp/v8js && ./configure --with-v8js=/opt/v8 LDFLAGS="-lstdc++"
RUN cd /tmp/v8js && make
#RUN cd /tmp/v8js && make test
RUN cd /tmp/v8js && make install
RUN echo extension=v8js.so >> /usr/local/etc/php/conf.d/v8js.ini

#RUN cp -R include/* /opt/v8/include/
#RUN for A in /opt/v8/lib/*.so; do patchelf --set-rpath '$ORIGIN' $A; done

# Enable V8JS
# RUN docker-php-ext-enable v8js

# Other dependencies
RUN docker-php-ext-install mbstring pdo pdo_mysql \
	&& a2enmod rewrite

# Install PHP AMQP extension
RUN apt-get install -y librabbitmq-dev libssh-dev \
    && pecl install amqp \
    && docker-php-ext-enable amqp

# Crontab
RUN apt-get -y install cron

# Start cron and Apache
CMD (cron) && apachectl -D FOREGROUND

## Do the following for adding your PHP application (website)
# COPY . /srv/app
# COPY docker/sample-vhost.conf /etc/apache2/sites-available/000-default.conf
# RUN chown -R www-data:www-data /srv/app

## Do the following for adding cron-jobs
# ADD docker/sample-crontab /etc/cron.d/cron
# RUN chmod 0644 /etc/cron.d/cron