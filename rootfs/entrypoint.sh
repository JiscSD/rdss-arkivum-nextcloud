#!/bin/sh

PHP_CONF_DIR="/etc/php/7.0"
PHP_FPM_DIR="${PHP_CONF_DIR}/fpm"
PHP_MODS_AVAILABLE="${PHP_CONF_DIR}/mods-available"


configure_directories()
{
    # Create folders for app data if they don't already exist
    mkdir -p /var/lib/nextcloud/apps2 /var/lib/nextcloud/config \
        /var/lib/nextcloud/data /var/lib/nextcloud/session
    # Update permissions on nextcloud folders
    echo "Updating permissions..."
    for dir in /nextcloud /var/lib/nextcloud /tmp; do
        if find "${dir}" ! -user "${UID}" -o ! -group "${GID}" | grep -E '.' -q ; then
            echo "Updating permissions in ${dir}..."
            chown -R "${UID}:${GID}" "${dir}"
        else
            echo "Permissions in ${dir} are correct."
        fi
    done
    echo "Done updating permissions."
}

configure_nextcloud()
{
    # Update various config files with environment variable values
    sed -i -e "s/<MEMORY_LIMIT>/$MEMORY_LIMIT/g" /usr/local/bin/occ

    # Change the config file to be on the persisted data location
    ln -sf /var/lib/nextcloud/config/config.php /nextcloud/config/config.php

    # Link the apps2 dir into the nextcloud dir
    ln -sf /var/lib/nextcloud/apps2 /nextcloud

    # Read current NextCloud version and store in version file
    nc_version="$(grep 'OC_Version = ' /nextcloud/version.php | sed -r 's#.+\(([0-9,]+)\).+#\1#' | tr ',' '.')"
    echo "${nc_version}" > /var/lib/nextcloud/config/version

    config_file="/var/lib/nextcloud/config/config.php"
    config_file_md5="${config_file}.template.md5"
    env_md5="/var/lib/nextcloud/config/env.md5"
    if [ ! -f "${config_file}" ]; then
        # New installation, run the setup
        /usr/local/bin/nextcloud-setup
    else
        # No need to run setup but do we need to update the config?
        update_config=0
        # Check if the installed version of NextCloud has changed
        # shellcheck disable=SC2016
        conf_version="$(php -r \
            'include "/var/lib/nextcloud/config/config.php"; echo $CONFIG["version"];')"
        if [ "$nc_version" != "$conf_version" ] ; then
            echo "Nextcloud version ${nc_version} doesn't match config version ${conf_version}, updating config..."
            update_config=1
        elif ! md5sum -cs "${config_file_md5}" 2>/dev/null ; then
            echo "Configuration template changed, updating config..."
            update_config=1
        elif [ "$(env | md5sum)" != "$(cat "${env_md5}" 2>/dev/null)" ] ; then
            echo "Environment has changed, updating config..."
            update_config=1
        fi
        if [ $update_config -eq 1 ] ; then
            # Take backup of existing config
            cp "${config_file}" "${config_file}.$(date --utc +"%Y%m%d%H%M%S")"
            # Re-run the config script
           /usr/local/bin/nextcloud-config
        fi
        # Run any upgrade tasks for NextCloud
        occ upgrade
    fi
    # Record the checksum of the config template for next time
    md5sum "/nextcloud/config/config.php.template" > "${config_file_md5}"
    # Record the checksum of the env for next time
    env | md5sum > "${env_md5}"

    # Disables the "deleted files app"
    occ app:disable files_trashbin

    # Configure Shibboleth integration, if enabled
    if [ -n "${SHIBBOLETH_AUTHENTICATION}" ] ; then
        echo "Shibboleth enabled, configuring..."
        /usr/local/bin/nextcloud-shibboleth
    fi
}

configure_nginx()
{
    # Make nginx run as nextcloud user
    sed -i -e 's/user www-data;/user nextcloud;/' /etc/nginx/nginx.conf
}

configure_php()
{
    # Update various config files with environment variable values
    sed -i -e "s/<APC_SHM_SIZE>/$APC_SHM_SIZE/g" "${PHP_MODS_AVAILABLE}/apcu.ini" \
       -e "s/<OPCACHE_MEM_SIZE>/$OPCACHE_MEM_SIZE/g" \
           "${PHP_MODS_AVAILABLE}/opcache.ini" \
       -e "s/<MEMORY_LIMIT>/$MEMORY_LIMIT/g" "${PHP_FPM_DIR}/php-fpm.conf" \
       -e "s/<UPLOAD_MAX_SIZE>/$UPLOAD_MAX_SIZE/g" \
           /etc/nginx/nginx.conf "${PHP_FPM_DIR}/php-fpm.conf" \
       -e "s#/run/php/#/run/#" "${PHP_FPM_DIR}/php-fpm.conf" \
       -e "s/error_reporting =.*=/error_reporting = E_ALL/g" "${PHP_FPM_DIR}/php.ini" \
       -e "s/display_errors =.*/display_errors = stdout/g" "${PHP_FPM_DIR}/php.ini"
}

configure_users()
{
    # Use NextCloud defaults if GID and UID are not given
    GID=${GID:-991}
    UID=${UID:-991}

    # Ensure nextcloud user exists for given uid and group id
    getent group "${GID}" || addgroup --system --gid "${GID}" nextcloud
    getent passwd "${UID}" || \
        adduser --ingroup nextcloud --uid "${UID}" --system \
                --no-create-home --shell /bin/false nextcloud
}

configure_users
configure_directories
configure_php
configure_nginx
configure_nextcloud

# Start supervisord and services
/usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
