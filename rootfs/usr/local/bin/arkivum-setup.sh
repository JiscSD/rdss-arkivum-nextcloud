#!/bin/sh

# Take external storage definitions from environment variable. This is expected
# to be a string of the format "<storage-name>:<storage-path>", for example
#
# documents:/mnt/documents music:/mnt/music
#
# Whitespace may be used to separate each storage location config.
#
EXTERNAL_STORAGES="${EXTERNAL_STORAGES}"

# Fill in minimial config params if they're missing
export ADMIN_USER="${ADMIN_USER:-'admin'}"
export ADMIN_PASSWORD="${ADMIN_PASSWORD:-'admin'}"

# Include DB_PORT in base setup script
cp '/usr/local/bin/base-setup.sh' '/usr/local/bin/base-setup.sh.orig' && \
< '/usr/local/bin/base-setup.sh.orig' \
    tr '\n' '\r' | \
    sed "s#EOF\\rif \\[#  'dbport'        => '\\${DB_PORT}',\\rEOF\\rif \\[#" | \
    tr '\r' '\n' > '/usr/local/bin/base-setup.sh'

# Base install runs auto-install in background. but we want it in foreground so
# we know when it's finished.
sed -i 's#php index.php &>/dev/null#php index.php#' /usr/local/bin/base-setup.sh

# Wait for database server to be ready, if necessary
if [ "${DB_TYPE}" != "sqlite3" ] ; then
    while [ "$(nc -z "${DB_HOST}" "${DB_PORT}" ; echo "$?")" -ne 0 ] ; do
        2> echo "Waiting for ${DB_TYPE} database to be ready..."
        sleep 2
    done
fi

# Remove the default demo files provided with Nextcloud
rm -Rf /nextcloud/core/skeleton/*

# Do the base setup
/usr/local/bin/base-setup.sh

# Enable 'External Storage' plugin
occ "app:enable files_external"

# Enable 'Files Move' plugin
occ "app:enable files_mv"

# Create requested external storage locations
for storage in $EXTERNAL_STORAGES ; do
    storage_name=$(echo "${storage}" | cut -d: -f1)
    storage_dir=$(echo "${storage}" | cut -d: -f2)
    occ files_external:create \
        --config datadir="${storage_dir}" \
        "${storage_name}" \
        'local' null::null
done

# Add a wildcard record for allowed domains
occ config:system:set trusted_domains 1 --value="*"

# Rescan file system
occ files:scan --all
