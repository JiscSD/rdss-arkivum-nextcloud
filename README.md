NextCloud Docker Container
===========================

Provides a [NextCloud](https://nextcloud.com/) Docker image based on [wonderfall/nextcloud](https://hub.docker.com/r/wonderfall/nextcloud/) with the following modifications:

* Added support for setting the `dbport` via environment variable `DB_PORT`
* The `files_external` plugin is enabled by default
* The [files_mv](https://github.com/eotryx/oc_files_mv/) plugin has been added and enabled
* The default skeleton files have been removed
* A trusted domain of `*` is added (you should use firewall to restrict access)

NextCloud is exposed on port 8888.

Building
---------

The build uses `make`. By default the `build` goal is executed. This also executes the `build-files-move-app` and `build-nextcloud-image` goals. The `clean` goal can be used to remove built files.

The build accepts the following build parameters:

| Parameter | Description | Default Value |
|---|---|---|
| `IMAGE_TAG_NAME` | The image name to tag the built Docker image with. | `arkivum/nextcloud` |
| `IMAGE_TAG_VERSION` | The version to tag the built Docker image with. | `latest` |

For example:

	make IMAGE_TAG_NAME="myorg/custom-nextcloud" IMAGE_TAG_VERSION="2.1"

Environment Variables
-----------------------

The following environment variables are supported:

| Variable | Description | Default Value |
|---|---|---|
| `SCAN_IN_FOREGROUND` | If set to `"true"`, the initial scan of configured file systems will be run as a foreground task, otherwise the scan will be performed as a background task. Running in the foreground will block and prevent NextCloud startup from completing until the scan is finished. | Undefined, causing the scan to be run in the background. |
| `DB_PORT` | Specifies the port to use to connect to the MySQL database server. | `3306` |
| `EXTERNAL_STORAGES` | Specifies the external storage location(s) that should be added as part of the set up. See [External Storage](#external-storage) below. | `""` |
| `HTTP_PROTOCOL` | Overrides NextCloud's own detection of what scheme it should use. Set to `https` if proxying NextCloud behind a HTTPS server. | `http` |
| `NC_LOG_LEVEL` | The level to log messages for. Valid values are one of the following numbers: <ul><li>0: DEBUG - all activity, the most detailed logging</li><li>1: INFO - activity such as user logins and file activities, plus warnings, errors and fatal errors</li><li>2: WARN - operations succeed, but with warnings of potential problems, plus errors and fatal errors</li><li>3: ERROR - an operation fails, but other services and operations continue, plus fatal errors</li><li>4: FATAL - the server stops</li></ul> | `1` |
| `NC_MAIL_DOMAIN` | The domain to use when sending mails from NextCloud. | `localhost` |
| `NC_MAIL_FROM_ADDRESS` | The `from` address to send emails from, without the "@" or domain | `nextcloud-noreply` |
| `NC_MAIL_DEBUG_ENABLED` | Whether or not to enable debugging for sending mail. Set to `true` to enable. |`false` |
| `NC_MAIL_HOST` | The SMTP host to use when sending mail. | `localhost` |
| `NC_MAIL_PASSWORD` | The SMTP password to use when sending mail. | none |
| `NC_MAIL_PORT` | The SMTP port to use when sending mail. | `25` |
| `NC_MAIL_SECURE` | What security mechanism to use when sending mail. Valid values are `ssl`, `tls` or none. | none |
| `NC_MAIL_TIMEOUT` | The timeout to use when sending mail, in seconds. | `10` |
| `NC_MAIL_USER` | The SMTP username to use when sending mail | none |
| `NEXTCLOUD_HOST` | Overrides NextCloud's own detection of what its hostname is. Use if using a proxy and you're not getting the right URLs. | `'nextcloud.example.ac.uk'` |
| `NEXTCLOUD_PORT` | Overrides NextCloud's own detection of what its port is. Use if using a proxy and you're not getting the right URLs. | `'8888'` |
| `PROXY_HOST` | The hostname of the HTTP proxy server in front of NextCloud. Used for reverse proxying. | `''` |
| `REDIS_HOST` | The hostname of the Redis server to use for caching. | `redis` |
| `REDIS_PORT` | The port of the Redis server to use for caching. | `6379` |

External Storage
-----------------

To automatically configure external storage locations for NextCloud during setup, use the `EXTERNAL_STORAGES` environment variable. The value of this variable must be a space-separated string, with pairs of storage location names and paths. For example:

	docker run \
		--env EXTERNAL_STORAGES="docs:/mnt/docs music:/mnt/music" \
		--volume /home/rl/Documents:/mnt/docs \
		--volume /home/rl/Music:/mnt/music \
		arkivum/nextcloud

The above would instantitate the NextCloud container with two external storage locations defined: one for `docs` and one for `music`. In this example, volume mounts have been used to map folders on the host system to the folders in the container that have been referenced in the `EXTERNAL_STORAGES` value, creating external storage locations in NextCloud for the mounted paths on the host system.

This image only supports the creation of "local" external storage locations during setup. If the location you wish to use is remote, mount it on the docker host using normal mount operations (e.g. `mount -t cifs`) and then use that mounted directory as the host path for the docker volume mount.

If you wish to reference the external locations using Docker volumes, you can use the following command to create the volume in Docker:

	docker volume create --opt type=none --opt o=bind --opt device=/home/rl/Music my_music
	
Do this for each external location and you can then reference them by name instead:

	docker run \
		--env EXTERNAL_STORAGES="docs:/mnt/docs music:/mnt/music" \
		--volume my_docs:/mnt/docs \
		--volume my_music:/mnt/music \
		arkivum/nextcloud

Mail Settings
--------------

NextCloud occasionally needs to send an email, such as when a user shares a location with another user or requests a password reset.

The `NC_MAIL_*` environment variables are used to configure the SMTP settings to allow it to do this. For example, to use Google Mail:

	docker run \
		--env NC_MAIL_DOMAIN=gmail.com" \
		--env NC_MAIL_FROM_ADDRESS=nextcloud-test" \
		--env NC_MAIL_HOST=smtp.gmail.com" \
		--env NC_MAIL_PORT=587" \
		--env NC_MAIL_SECURE=tls" \
		--env NC_MAIL_USER=nextcloud-test@gmail.com" \
		--env NC_MAIL_PASSWORD=supersecret" \
		arkivum/nextcloud

Note that unauthenticated mail sending is not supported, so you must always specify the `NC_MAIL_USER` and `NC_MAIL_PASSWORD` for NextCloud to be able to send any mail messages.

Redis Settings
---------------

NextCloud is configured to use Redis for caching to improve perfomance. To configure the hostname and port to use for the Redis server, use the `REDIS_HOST` and `REDIS_PORT` environment variables:

	docker-run \
		--env REDIS_HOST=redis-master \
		--env REDIS_PORT=6380 \
		arkivum/nextcloud

Although NextCloud supports it, it is not currently possible to specify more than one host for NextCloud to connect to. This is on the assumption that any clustering will be done behind a single DNS hostname, so is better handled at the infrastructure layer than in the application.

Usage with Docker Compose
--------------------------

An example Docker Compose config for this image is [provided here](docker-compose.yml), which configures NextCloud to use the provided MySQL service. This is useful for development and testing purposes.

