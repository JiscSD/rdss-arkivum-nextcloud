#!/bin/sh

# Ensure nextcloud user exists for given uid and group id
getent group "${GID}" || addgroup -S -g "${GID}" nextcloud
getent passwd "${UID}" || adduser -G nextcloud -u "${UID}" -S -H -s /bin/false nextcloud

# Call the base run.sh
/usr/local/bin/base-run.sh
