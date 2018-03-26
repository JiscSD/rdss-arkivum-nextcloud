
# Use upstream Alpine with NGINX and PHP-FPM image
FROM boxedcode/alpine-nginx-php-fpm:v1.7.2

#
# Fetch and build NextCloud
#

ARG NEXTCLOUD_VERSION=12.0.6
ARG GPG_nextcloud="2880 6A87 8AE4 23A2 8372  792E D758 99B9 A724 937A"

ENV UID=991 GID=991 \
    UPLOAD_MAX_SIZE=10G \
    APC_SHM_SIZE=128M \
    OPCACHE_MEM_SIZE=128 \
    MEMORY_LIMIT=512M \
    CRON_PERIOD=15m \
    CRON_MEMORY_LIMIT=1g \
    TZ=Etc/UTC \
    DB_TYPE=sqlite3 \
    DOMAIN=localhost

RUN apk -U upgrade \
 && apk add -t build-dependencies \
    gnupg \
    tar \
    build-base \
    autoconf \
    automake \
    pcre-dev \
    libtool \
    samba-dev \
 && apk add \
    libressl \
    ca-certificates \
    libsmbclient \
    mysql-client \
    sudo \
    tzdata \
 && pecl install \
    smbclient \
    apcu \
    redis \
 && ln -s $(dirname $(readlink -f /usr/lib/php/modules/opcache.so))/apcu.so /usr/lib/php/modules/ \
 && ln -s $(dirname $(readlink -f /usr/lib/php/modules/opcache.so))/redis.so /usr/lib/php/modules/ \
 && ln -s $(dirname $(readlink -f /usr/lib/php/modules/opcache.so))/smbclient.so /usr/lib/php/modules/ \
 && rm -f /usr/etc/php-fpm.d/* \
 && mkdir /nextcloud \
 && cd /tmp \
 && NEXTCLOUD_TARBALL="nextcloud-${NEXTCLOUD_VERSION}.tar.bz2" \
 && wget -q https://download.nextcloud.com/server/releases/${NEXTCLOUD_TARBALL} \
 && wget -q https://download.nextcloud.com/server/releases/${NEXTCLOUD_TARBALL}.sha512 \
 && wget -q https://download.nextcloud.com/server/releases/${NEXTCLOUD_TARBALL}.asc \
 && wget -q https://nextcloud.com/nextcloud.asc \
 && echo "Verifying both integrity and authenticity of ${NEXTCLOUD_TARBALL}..." \
 && CHECKSUM_STATE=$(echo -n $(sha512sum -c ${NEXTCLOUD_TARBALL}.sha512) | tail -c 2) \
 && if [ "${CHECKSUM_STATE}" != "OK" ]; then echo "Warning! Checksum does not match!" && exit 1; fi \
 && gpg --import nextcloud.asc \
 && FINGERPRINT="$(LANG=C gpg --verify ${NEXTCLOUD_TARBALL}.asc ${NEXTCLOUD_TARBALL} 2>&1 \
  | sed -n "s#Primary key fingerprint: \(.*\)#\1#p")" \
 && if [ -z "${FINGERPRINT}" ]; then echo "Warning! Invalid GPG signature!" && exit 1; fi \
 && if [ "${FINGERPRINT}" != "${GPG_nextcloud}" ]; then echo "Warning! Wrong GPG fingerprint!" && exit 1; fi \
 && echo "All seems good, now unpacking ${NEXTCLOUD_TARBALL}..." \
 && tar xjf ${NEXTCLOUD_TARBALL} --strip 1 -C /nextcloud \
 && update-ca-certificates \
 && apk del build-dependencies \
 && rm -rf /var/cache/apk/* /tmp/* /root/.gnupg \
 && wget -q -O /usr/local/bin/ep https://github.com/kreuzwerker/envplate/releases/download/v0.0.8/ep-linux \
 && chmod +x /usr/local/bin/ep

COPY rootfs /

# Copy the files_mv app to NextCloud
COPY build/files_mv /nextcloud/apps/files_mv

# Copy the user_saml app to NextCloud
COPY build/user_saml /nextcloud/apps/user_saml

VOLUME /nextcloud/themes /var/lib/nextcloud

EXPOSE 8888

LABEL description="A server software for creating file hosting services" \
      nextcloud="Nextcloud v${NEXTCLOUD_VERSION}" \
      maintainer="Arkivum Limited"

