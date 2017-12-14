FROM wonderfall/nextcloud

MAINTAINER Arkivum Limited

# Use EnvPlate for templating
RUN curl -sLo /usr/local/bin/ep \
    https://github.com/kreuzwerker/envplate/releases/download/v0.0.8/ep-linux \
    && chmod +x /usr/local/bin/ep

# Copy the files_mv app to NextCloud
COPY build/files_mv /nextcloud/apps/files_mv

# Redirect NextCloud logs to stdout
RUN rm -f /var/log/nextcloud.log && \
	ln -s /dev/stdout /var/log/nextcloud.log

# Copy our rootfs
COPY rootfs /

# Replace the default setup.sh with our own
RUN mv /usr/local/bin/setup.sh /usr/local/bin/installer.sh && \
    ln -s /usr/local/bin/arkivum-setup.sh /usr/local/bin/setup.sh

# Upstream image has too many volume mounts, so use a single one and change the
# installer to use our location instead
VOLUME /var/lib/nextcloud
RUN sed -i -r \
    -e 's#(\W)/config#\1/var/lib/nextcloud/config#' \
    -e 's#(\W)/data#\1/var/lib/nextcloud/data#' \
    -e 's#path([^/]+)/apps2#path\1/var/lib/nextcloud/apps2#' \
    /usr/local/bin/installer.sh
