#!/bin/sh
#
# done.sh - the callback script of smartdl.sh
#
IFS=
PATH=/bin:/usr/bin
set -e

#
# some environmental config
#
# all infos are sent to
: ${LOGFILE:="/dev/stdout"}
# fetched files are appended to
: ${FETCH_LOG:="/dev/null"}
# and fetched links are appended to
: ${LINKS_DOWNED:="/dev/null"}
# failed links are kept in
: ${LINKS_FAILED:="/dev/null"}
# and global feedback on errors is given to
: ${ERROR_LOG:="/dev/null"}

touch "$LOGFILE"
log () {
    echo "$(date) $@" >> "$LOGFILE"
}

err () {
    touch "$ERROR_LOG"
    echo "$(date) $@" | tee -a "$ERROR_LOG" >> "$LOGFILE"
}

usage () {
    self=$(basename $0)
    cat <<EOT
$self - on finish reporter for smartdl background downloads

usage: $self <success|fail> <link> [downloaded file(s)]

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
    err "[done] was called with wrong arg count ($#): $@"
    exit 1
fi
outcome="$1"
shift
link="$1"
shift

if [ x"$outcome" = xsuccess ]; then
    log "[download_finished] $link"
    echo "$link" >> "$LINKS_DOWNED"
    while [ $# -gt 0 ]; do
        if [ -z "$1" ]; then
            err "[downloaded_file] caught empty string!"
        else
            log "[downloaded_file] $1"
            echo "$1" >> "$FETCH_LOG"
        fi
        shift
    done
elif [ x"$outcome" = xfail ]; then
    if grep -q "$link" "$LINKS_FAILED"; then
        err "[download_failed] $link -> giving up"
        echo "$link" >> "$LINKS_DOWNED"
    else
        err "[download_failed] $link -> $LINKS_FAILED"
        echo "$link" >> "$LINKS_FAILED"
    fi
else
    err "[done] first arg was garbage: $@"
fi
