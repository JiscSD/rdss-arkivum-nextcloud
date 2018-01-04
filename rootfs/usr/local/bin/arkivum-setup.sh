#!/bin/sh

# Take external storage definitions from environment variable. This is expected
# to be a string of the format "<storage-name>:<storage-path>", for example
#
# documents:/mnt/documents music:/mnt/music
#
# Whitespace may be used to separate each storage location config.
#
EXTERNAL_STORAGES="${EXTERNAL_STORAGES}"

# STAGE 1: PRE-INSTALL #########################################################

# Fill in minimial config params if they're missing
export ADMIN_USER="${ADMIN_USER:-'admin'}"
export ADMIN_PASSWORD="${ADMIN_PASSWORD:-'admin'}"

# Edit installer script to use DB_PORT for dbport value
cp '/usr/local/bin/installer.sh' '/usr/local/bin/installer.sh.orig' && \
< '/usr/local/bin/installer.sh.orig' \
    tr '\n' '\r' | \
    sed -r "s|'memcache|'skeletondirectory' => '',\\n'memcache|" | \
    sed "s|EOF\\rif \\[|  'dbport'        => '\${DB_PORT}',\\rEOF\\rif \\[|" | \
    tr '\r' '\n' > '/usr/local/bin/installer.sh'

# Base install runs auto-install in background. but we want it in foreground so
# we know when it's finished.
sed -i 's#php index.php &>/dev/null#php index.php#' \
    '/usr/local/bin/installer.sh'

# Wait for database server to be ready, if necessary
if [ "${DB_TYPE}" != "sqlite3" ] ; then
    while [ "$(nc -z "${DB_HOST}" "${DB_PORT}" ; echo "$?")" -ne 0 ] ; do
        2> echo "Waiting for ${DB_TYPE} database to be ready..."
        sleep 2
    done
fi

# STAGE 2: INSTALL #############################################################

# Do the base install
/usr/local/bin/installer.sh

# STAGE 3: POST-INSTALL CONFIG #################################################


# Copy the apps and data dirs to the persisted data location
cp -pr /apps2 /var/lib/nextcloud/ && \
    cp -pr /data /var/lib/nextcloud/ && \
    chown -R nextcloud:nextcloud /var/lib/nextcloud

# Create a backup of the default config
[ -f /var/lib/nextcloud/config/config.php.default ] || \
    cp -p /var/lib/nextcloud/config/config.php \
        /var/lib/nextcloud/config/config.php.default

#
# Replace the default config with our own templated config, keeping any
# auto-generated values like instance id and password salt etc.
#
/usr/local/bin/arkivum-config.sh

# STAGE 4: POST-CONFIG BOOTSTRAP ###############################################

# Enable 'External Storage' plugin
occ "app:enable files_external"

# Enable 'Files Move' plugin
occ "app:enable files_mv"

# Create requested external storage locations
for storage in ${EXTERNAL_STORAGES} ; do
    storage_name="$(echo "${storage}" | cut -d: -f1)"
    storage_dir="$(echo "${storage}" | cut -d: -f2)"
    occ files_external:create \
        --config datadir="${storage_dir}" \
        "${storage_name}" \
        'local' null::null
done

# Add a wildcard record for allowed domains
occ config:system:set trusted_domains 1 --value="*"

# Rescan file system
occ files:scan --all &
