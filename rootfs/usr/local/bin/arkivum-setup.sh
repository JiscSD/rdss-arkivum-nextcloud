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

# Edit base setup script to use DB_PORT for dbport value
cp '/usr/local/bin/base-setup.sh' '/usr/local/bin/base-setup.sh.orig' && \
< '/usr/local/bin/base-setup.sh.orig' \
    tr '\n' '\r' | \
    sed "s|EOF\\rif \\[|  'dbport'        => '\\${DB_PORT}',\\rEOF\\rif \\[|" | \
    tr '\r' '\n' > '/usr/local/bin/base-setup.sh'

# Base install runs auto-install in background. but we want it in foreground so
# we know when it's finished.
sed -i 's#php index.php &>/dev/null#php index.php#' \
    '/usr/local/bin/base-setup.sh'

# Wait for database server to be ready, if necessary
if [ "${DB_TYPE}" != "sqlite3" ] ; then
    while [ "$(nc -z "${DB_HOST}" "${DB_PORT}" ; echo "$?")" -ne 0 ] ; do
        2> echo "Waiting for ${DB_TYPE} database to be ready..."
        sleep 2
    done
fi

# STAGE 2: INSTALL #############################################################

# Do the base setup
/usr/local/bin/base-setup.sh

# STAGE 3: POST-INSTALL CONFIG #################################################

# Create a backup of the default config
[ -f /config/config.php.default ] || \
    cp -p /config/config.php /config/config.php.default

#
# Replace the default config with our own templated config, keeping any
# auto-generated values like instance id and password salt etc.
#

# Capture existing values from the existing config
# shellcheck disable=SC2016
instance_id="$(php -r \
    'include "/config/config.php"; echo $CONFIG["instanceid"];')"
# shellcheck disable=SC2016
db_user="$(php -r \
    'include "/config/config.php"; echo $CONFIG["dbuser"];')"
# shellcheck disable=SC2016
db_password_crypted="$(php -r \
    'include "/config/config.php"; echo $CONFIG["dbpassword"];')"
# shellcheck disable=SC2016
password_salt="$(php -r \
    'include "/config/config.php"; echo $CONFIG["passwordsalt"];')"
# shellcheck disable=SC2016
secret="$(php -r \
    'include "/config/config.php"; echo $CONFIG["secret"];')"

# Use EnvPlate to process our template and replace the existing config
cp -p /config/config.php.template /config/config.php.new
NC_DB_HOST="${DB_HOST}" \
NC_DB_PORT="${DB_PORT}" \
NC_DB_USER="${db_user}" \
NC_DB_PASSWORD_CRYPTED="${db_password_crypted}" \
NC_INSTANCE_ID="${instance_id}" \
NC_PASSWORD_SALT="${password_salt}" \
NC_SECRET="${secret}" \
    ep /config/config.php.new && \
    mv /config/config.php.new /config/config.php

# STAGE 4: POST-CONFIG BOOTSTRAP ###############################################

# Enable 'External Storage' plugin
occ "app:enable files_external"

# Enable 'Files Move' plugin
occ "app:enable files_mv"

# Create requested external storage locations
for storage in ${EXTERNAL_STORAGES} ; do
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
occ files:scan --all &
