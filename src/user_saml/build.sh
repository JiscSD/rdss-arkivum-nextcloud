#!/bin/bash

BUILD_OWNER="${BUILD_OWNER:-$UID:$GID}"

# user_saml build needs rsync
apt-get -qq update && apt-get -qq install -y rsync && rm -rf /var/lib/apt/lists/*

# Create the build dir, in case it doesn't already exist
mkdir -p /build/

# Checkout and build the `user_saml` NextCloud plugin
git clone --branch qa/jisc https://github.com/lower29/user_saml.git \
    /tmp/user_saml/ \
  && cd /tmp/user_saml && make appstore

# Extract the built tarball to the build directory
tar xzf /tmp/user_saml/build/artifacts/user_saml-*.tar.gz -C  /build/

# Chown build output to the right owner
chown -R "${BUILD_OWNER}" /build/*
