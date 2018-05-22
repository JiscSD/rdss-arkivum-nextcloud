
# Use upstream Debian OS image
FROM debian:stretch-slim

ARG NEXTCLOUD_VERSION=12.0.7
ARG GPG_nextcloud="2880 6A87 8AE4 23A2 8372  792E D758 99B9 A724 937A"

ENV DEBIAN_FRONTEND=noninteractive \
    UID=991 GID=991 \
    UPLOAD_MAX_SIZE=10G \
    APC_SHM_SIZE=128M \
    OPCACHE_MEM_SIZE=128 \
    MEMORY_LIMIT=512M \
    CRON_PERIOD=15m \
    CRON_MEMORY_LIMIT=1g \
    TZ=Etc/UTC \
    DB_TYPE=sqlite3 \
    DOMAIN=localhost

#
# Install dependencies, nginx, php-fpm, required PHP extensions and NextCloud
#
RUN apt update && apt install -y \
    coreutils \
    netcat \
    nginx \
    php-apcu \
    php-curl \
    php-dev \
    php-fpm \
    php-gd \
    php-mbstring \
    php-mysql \
    php-pear \
    php-smbclient \
    php-xml \
    php-zip \
    sudo \
    supervisor \
    wget \
 && pecl install redis \
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
 && wget -q -O /usr/local/bin/ep https://github.com/kreuzwerker/envplate/releases/download/v0.0.8/ep-linux \
 && chmod +x /usr/local/bin/ep \
 && apt remove -y php-dev php-pear wget \
 && apt -y autoremove \
 && rm -rf /var/lib/apt/lists/* /tmp/* /root/.gnupg

COPY rootfs /

# Copy the files_mv app to NextCloud
COPY build/files_mv /nextcloud/apps/files_mv

# Copy the user_saml app to NextCloud
COPY build/user_saml /nextcloud/apps/user_saml

VOLUME /nextcloud/themes /var/lib/nextcloud

EXPOSE 8888

ENTRYPOINT ["/entrypoint.sh"]

LABEL description="A server software for creating file hosting services" \
      nextcloud="Nextcloud v${NEXTCLOUD_VERSION}" \
      maintainer="Arkivum Limited"

