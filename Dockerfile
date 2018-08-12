FROM php:7.2-apache
MAINTAINER Extensive IT B.V. <info@extensive-it.nl>

# Install required dependencies
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends cron git wget software-properties-common build-essential python vim libglib2.0-dev patchelf librabbitmq-dev libssh-dev

# Install depot_tools first (needed for source checkout)
# Download v8 and setup GN
# Build v8
# Install v8 to /opt/v8
# Download v8js, build and install
RUN cd /tmp && git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git && \
	export PATH="$PATH:/tmp/depot_tools" && \	
	cd /tmp && fetch v8 && \
	cd /tmp/v8 && gclient sync && \
	cd /tmp/v8 && tools/dev/v8gen.py -vv x64.release -- is_component_build=true && \
	cd /tmp/v8 && ninja -C out.gn/x64.release/ && \
	mkdir -p /opt/v8/lib && mkdir /opt/v8/include && \
	cd /tmp/v8 && cp out.gn/x64.release/lib*.so out.gn/x64.release/*_blob.bin /opt/v8/lib/ && \
	for A in /opt/v8/lib/*.so; do patchelf --set-rpath '$ORIGIN' $A; done && \
	cd /tmp/v8 && cp -R include/* /opt/v8/include/ && \
	cd /tmp && git clone https://github.com/phpv8/v8js.git && \
	cd /tmp/v8js && phpize && \
	cd /tmp/v8js && ./configure --with-v8js=/opt/v8 LDFLAGS="-lstdc++" && \
	cd /tmp/v8js && make && \
	cd /tmp/v8js && make install && \
	echo extension=v8js.so >> /usr/local/etc/php/conf.d/v8js.ini && \
	docker-php-ext-install mbstring pdo pdo_mysql && \
	a2enmod rewrite && \
	pecl install amqp && \
	docker-php-ext-enable amqp && \
	rm -rf /tmp/depot_tools /tmp/v8js /tmp/v8 && \
	apt-get remove -y git wget build-essential python vim && \
	apt-get autoremove -y && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

# Start cron and Apache
CMD (cron) && apachectl -D FOREGROUND

## Do the following for adding your PHP application (website)
# COPY . /srv/app
# COPY docker/sample-vhost.conf /etc/apache2/sites-available/000-default.conf
# RUN chown -R www-data:www-data /srv/app

## Do the following for adding cron-jobs
# ADD docker/sample-crontab /etc/cron.d/cron
# RUN chmod 0644 /etc/cron.d/cron
