#!/bin/sh
#
# done.sh - the callback script of smartdl.sh
#
IFS=
PATH=/bin:/usr/bin
set -e

: ${CONFIG:=$PWD/podcatch-config.sh}
if [ -r "$CONFIG" ]; then
    . "$CONFIG"
fi

self="$(basename "$0")"

check_files_writable () {
    for file in "$@"; do
        test -w "$1" ||
        test -w "$(dirname "$1")" ||
        {
            echo "[$self] not writable: $1" 1>&2
            exit 1
        }
    done
}

check_files_writable \
    ${LOGFILE:="/dev/stdout"} \
    ${FETCH_LOG:="/dev/null"} \
    ${LINKS_DOWNED:="/dev/null"} \
    ${LINKS_FAILED:="/dev/null"} \
    ${ERROR_LOG:="/dev/null"}

log () {
    echo "$(date) $@" >> "$LOGFILE"
}

err () {
    echo "$(date) $@" | tee -a "$ERROR_LOG" >> "$LOGFILE"
}

usage () {
    cat <<EOT
$self - on finish reporter for smartdl background downloads

usage: $self <success|exit_status> <link> [downloaded file(s)]

    $self is not intended to be used interactively, but
    invoking it without any args will bring up this info text.

examples:

    $self success http://www.example.com/file.mpg /foo/file.mpg
    $self fail http://www.example.com/404.jpg

EOT
}

if [ $# = 0 ]; then
    usage
    exit
fi

##
#  all set! let's start it up!
##

if [ $# -lt 2 ]; then
    err "[$self] called with wrong arg count: $# ($@)"
    exit 1
fi
status="$1"
shift
link="$1"
if [ -z "$link" ]; then
    err "[$self] got empty link -> bug?"
    exit 1
fi
shift

if [ d"$status" = dsuccess ]; then
    log "[$self] success: $link"
    echo "$link" >> "$LINKS_DOWNED"
    while [ $# -gt 0 ]; do  # consume other args
        if [ -n "$1" ]; then
            echo "$1" >> "$FETCH_LOG"
            log "[$self] downloaded: $1"
        else
            err "[$self] got empty additional link -> bug?"
        fi
        shift
    done
    exit
elif ! echo x"$status" | grep -v "^x[1-9][0-9]*$" > /dev/null; then
    if grep -q "$link" "$LINKS_FAILED"; then
        echo "$link" >> "$LINKS_DOWNED"
        err "[$self] failed again: $link -> giving up"
    else
        echo "$link" >> "$LINKS_FAILED"
        err "[$self] first fail: $link -> $LINKS_FAILED"
    fi
    exit $status
else
    err "[$self] first arg was garbage: $status"
    exit 1
fi
