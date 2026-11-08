#!/bin/sh
# ===========================================================================
# CouchPotato entrypoint wrapper for the TerraMaster TOS 7 package.
#
# Why this file exists
# --------------------
# The upstream image (linuxserver/couchpotato) boots with the s6-overlay v2
# init /init, which is written for a root container: it copies service
# definitions into /var/run/s6 and drops privileges with s6-setuidgid. With
# user "1000:1000" it cannot spawn anything - measured in the container:
#
#   s6-supervise (child): fatal: unable to exec run: Permission denied
#   s6-supervise couchpotato: warning: unable to spawn ./run
#
# and the container stays "Up" with nothing listening on 5050. TOS forbids
# root containers, so this wrapper skips s6 entirely and runs the very same
# command the s6 service runs, directly as the unprivileged container user:
#
#   python /app/couchpotato/CouchPotato.py \
#       --config_file=/config/config.ini --data_dir=/config/data
#
# Nothing in the image is modified; only the process identity differs.
# ===========================================================================
set -u

CONFIG_DIR=/config
DATA_DIR=$CONFIG_DIR/data

# The platform creates and chowns the mounted application data directory, but
# not the sub-directories CouchPotato expects. Create them idempotently.
mkdir -p "$DATA_DIR/logs" "$DATA_DIR/cache" "$DATA_DIR/database" "$DATA_DIR/custom_plugins"

# CouchPotato caches artwork and metadata below $HOME. Point HOME at the
# persistent volume so a container update does not throw that cache away.
export HOME=$CONFIG_DIR
export TZ="${TZ:-Asia/Shanghai}"
export PYTHONIOENCODING=UTF-8

# -u keeps stdout/stderr unbuffered, so "docker logs" shows startup errors.
exec python -u /app/couchpotato/CouchPotato.py \
  --config_file="$CONFIG_DIR/config.ini" \
  --data_dir="$DATA_DIR"
