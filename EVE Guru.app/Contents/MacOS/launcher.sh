#!/bin/sh

DIR=$(dirname "$(readlink -f "$0")")

export PATH=/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin

exec "$DIR/launcher.nu" "$@"
