#!/bin/bash

BUILD_OWNER="${BUILD_OWNER:-$UID:$GID}"

# Create the build dir, in case it doesn't already exist
mkdir -p /build/

# Checkout and install the `ocdev` tool
git clone https://github.com/owncloudarchive/ocdev.git /tmp/ocdev/ && \
    cd /tmp/ocdev && python setup.py install

# Checkout and build the `files_mv` NextCloud plugin
git clone https://github.com/eotryx/oc_files_mv.git /tmp/files_mv/ && \
    cd /tmp/files_mv && make appstore_package

# Extract the built tarball to the build directory
tar xzf /tmp/files_mv/build/artifacts/appstore/files_mv.tar.gz -C  /build/

# Chown build output to the right owner
chown -R "${BUILD_OWNER}" /build/*
