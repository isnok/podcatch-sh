#!/bin/sh
#
# archive.sh - a convenience feature for podcatching via shell
#
# logging is disabled/defunct because busybox' cp doesn't implement -v
#
IFS=
PATH=/bin

: ${INCOMING:=/tmp/incoming}
: ${ARCHIVE:=/tmp/archive}

mkdir -p "$ARCHIVE"
cp -rl "$INCOMING"/* "$ARCHIVE" &> /dev/null
