FROM ubuntu:18.04

EXPOSE 80 443

RUN apt update \
    && apt install -y --no-install-recommends \
        apache2 \
        gawk \
        groff \
        pdf2svg \
        ps2eps \
        python3-pygments \
        rcs \
        wget \
        unzip \
    && rm -rf /var/lib/apt/lists/*

RUN wget http://mirrors.ctan.org/support/epstopdf.zip -O /tmp/epstopdf.zip \
    && unzip /tmp/epstopdf.zip -d /tmp \
    && mv /tmp/epstopdf/epstopdf.pl /usr/bin/epstopdf \
    && rm -r /tmp/epstopdf*

ENV APACHE_RUN_USER  www-data
ENV APACHE_RUN_GROUP www-data
ENV APACHE_LOG_DIR   /var/log/apache2
ENV APACHE_PID_FILE  /var/run/apache2/apache2.pid
ENV APACHE_RUN_DIR   /var/run/apache2
ENV APACHE_LOCK_DIR  /var/lock/apache2
ENV APACHE_LOG_DIR   /var/log/apache2
ENV AWKI_ROOT        /var/www/awki/

RUN mkdir -p $APACHE_RUN_DIR
RUN mkdir -p $APACHE_LOCK_DIR
RUN mkdir -p $APACHE_LOG_DIR

RUN a2enmod rewrite \
    && a2enmod cgi \
    && rm -f /etc/apache2/sites-enabled/* /etc/apache2/conf-enabled/serve-* \
    && ln -s /etc/apache2/sites-available/wiki.conf /etc/apache2/sites-enabled

COPY . $AWKI_ROOT
RUN chown -R www-data:www-data $AWKI_ROOT \
    && $AWKI_ROOT/setup.sh
COPY apache/wiki.conf /etc/apache2/sites-available/

VOLUME [ "$AWKI_ROOT/data" ]
VOLUME [ "$AWKI_ROOT/sessions" ]

CMD [ "apache2", "-D", "FOREGROUND" ]

