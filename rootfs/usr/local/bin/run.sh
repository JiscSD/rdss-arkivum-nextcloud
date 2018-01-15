#!/bin/sh

# Use NextCloud defaults if GID and UID are not given
GID=${GID:-991}
UID=${UID:-991}

# Ensure nextcloud user exists for given uid and group id
getent group "${GID}" || addgroup -S -g "${GID}" nextcloud
getent passwd "${UID}" || \
    adduser -G nextcloud -u "${UID}" -S -H -s /bin/false nextcloud

# Update various config files with environment variable values
sed -i -e "s/<APC_SHM_SIZE>/$APC_SHM_SIZE/g" /php/conf.d/apcu.ini \
       -e "s/<OPCACHE_MEM_SIZE>/$OPCACHE_MEM_SIZE/g" /php/conf.d/opcache.ini \
       -e "s/<CRON_MEMORY_LIMIT>/$CRON_MEMORY_LIMIT/g" /etc/s6.d/cron/run \
       -e "s/<CRON_PERIOD>/$CRON_PERIOD/g" /etc/s6.d/cron/run \
       -e "s/<MEMORY_LIMIT>/$MEMORY_LIMIT/g" /usr/local/bin/occ \
       -e "s/<UPLOAD_MAX_SIZE>/$UPLOAD_MAX_SIZE/g" \
           /nginx/conf/nginx.conf /php/etc/php-fpm.conf \
       -e "s/<MEMORY_LIMIT>/$MEMORY_LIMIT/g" /php/etc/php-fpm.conf

# Allow PHP-FPM processes to access environment variables without explicitly
# naming them
echo "clear_env = no" >> /php/etc/php-fpm.conf

# Change the config file to be on the persisted data location
ln -sf /var/lib/nextcloud/config/config.php /nextcloud/config/config.php

# Link the apps2 dir into the nextcloud dir
ln -sf /var/lib/nextcloud/apps2 /nextcloud

# Create folders for app data if they don't already exist
mkdir -p /var/lib/nextcloud/apps2 /var/lib/nextcloud/config \
    /var/lib/nextcloud/data /var/lib/nextcloud/session

echo "Updating permissions..."
for dir in /nextcloud /var/lib/nextcloud /php /nginx /tmp /etc/s6.d; do
  if find "${dir}" ! -user "${UID}" -o ! -group "${GID}" | grep -E '.' -q ; then
    echo "Updating permissions in ${dir}..."
    chown -R "${UID}:${GID}" "${dir}"
  else
    echo "Permissions in ${dir} are correct."
  fi
done
echo "Done updating permissions."

config_file="/var/lib/nextcloud/config/config.php"
config_file_md5="${config_file}.template.md5"
if [ ! -f "${config_file}" ]; then
    # New installation, run the setup
    /usr/local/bin/setup.sh
else
    # Check if the checksum of the config template has changed
    if ! md5sum -cs "${config_file_md5}" 2>/dev/null ; then
        # Config template has changed, take backup of existing config
        cp "${config_file}" "${config_file}.$(date --utc +"%Y%m%d%H%M%S")"
        # Re-run the config script
        echo "Configuration template changed, updating config..."
        /usr/local/bin/arkivum-config.sh
    fi
    # Run any upgrade tasks for NextCloud
    occ upgrade
fi
# Record the checksum of the config template for next time
md5sum "/nextcloud/config/config.php.template" > "${config_file_md5}"

# Disables the "deleted files app"

occ app:disable files_trashbin

exec su-exec "${UID}:${GID}" /bin/s6-svscan /etc/s6.d
