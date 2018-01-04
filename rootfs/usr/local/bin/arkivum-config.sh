#!/bin/sh

#
# Replace the current config with our own templated config, keeping any
# auto-generated values like instance id and password salt etc.
#

# Capture existing values from the existing config
# shellcheck disable=SC2016
instance_id="$(php -r \
    'include "/var/lib/nextcloud/config/config.php"; echo $CONFIG["instanceid"];')"
# shellcheck disable=SC2016
db_user="$(php -r \
    'include "/var/lib/nextcloud/config/config.php"; echo $CONFIG["dbuser"];')"
# shellcheck disable=SC2016
db_password_crypted="$(php -r \
    'include "/var/lib/nextcloud/config/config.php"; echo $CONFIG["dbpassword"];')"
# shellcheck disable=SC2016
password_salt="$(php -r \
    'include "/var/lib/nextcloud/config/config.php"; echo $CONFIG["passwordsalt"];')"
# shellcheck disable=SC2016
secret="$(php -r \
    'include "/var/lib/nextcloud/config/config.php"; echo $CONFIG["secret"];')"

# Use EnvPlate to process our template and replace the existing config
cp -p /nextcloud/config/config.php.template \
    /var/lib/nextcloud/config/config.php.new
NC_DB_USER="${db_user}" \
NC_DB_PASSWORD_CRYPTED="${db_password_crypted}" \
NC_INSTANCE_ID="${instance_id}" \
NC_PASSWORD_SALT="${password_salt}" \
NC_SECRET="${secret}" \
    ep /var/lib/nextcloud/config/config.php.new && \
    mv /var/lib/nextcloud/config/config.php.new /var/lib/nextcloud/config/config.php && \
    echo "Updated NextCloud configuration from template."
