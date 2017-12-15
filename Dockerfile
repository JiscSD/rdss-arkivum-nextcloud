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

# Replace the default run.sh with our own
RUN mv /usr/local/bin/run.sh /usr/local/bin/base-run.sh && \
    ln -s /usr/local/bin/arkivum-run.sh /usr/local/bin/run.sh

# Replace the default setup.sh with our own
RUN mv /usr/local/bin/setup.sh /usr/local/bin/base-setup.sh && \
    ln -s /usr/local/bin/arkivum-setup.sh /usr/local/bin/setup.sh

