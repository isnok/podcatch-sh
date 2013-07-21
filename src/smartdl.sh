#!/bin/sh
#
# smartdl.sh - a torrent-aware wrapper for wget
#
# i'll try this approach:
#
# leave the pluggability of podcatch.sh as is (feed parsing only),
# and instead of adding a plugin slot for different download types,
# i'd like to try out how far auto-detection of links scales.
# it's gonna result in a nice ~/bin script anyway.
#
# exit statuses (stati?):
#
#    0: download finished successfully
#    1: an error ocurred (usually while trying to download)
#   23: the download was started as a background job
# else: if a command fails unexpectedly, it's exit status is passed through
#
# to ease things at development start, i'll only implement downloading
# the first command line argument (link) to the current directory.
IFS=" "
PATH=/bin:/usr/bin
set -e

: ${CONFIG:=$PWD/podcatch-config.sh}
if [ -r "$CONFIG" ]; then
    . "$CONFIG"
    export CONFIG
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

: ${SCRIPTDIR:="$(dirname "$0")"}
: ${DONESCRIPT:="$SCRIPTDIR/done.sh"}
export FETCH_LOG LINKS_DOWNED ERROR_LOG LINKS_FAILED

# download-helper configuration
: ${DEFAULTLOADER:="wget"} ${WGET_ARGS:=""}
: ${TORRENTCLIENT:="ctorrent"} ${TORRENT_ARGS:="-e 2 -d"}
: ${YOUTUBEHELPER:="youtube-dl"} ${YOUTUBE_ARGS:="-c -t"}

log () {
    echo "$(date) $@"
}

err () {
    echo "$(date) $@" | tee -a "$ERROR_LOG" 1>&2
}

usage () {
    cat <<EOT
$self - a link type aware downloader script

usage: $self [uri]

    will detect the type of uri and take action accordingly.
    by default this will be to download to the current directory,
    but if the tools are at hand and enabled, they will be used.

    default-downloader: wget
    torrent-downloader: ${TORRENTCLIENT:-"<disabled>"}
    youtube-downloader: ${YOUTUBEHELPER:-"<disabled>"}

    done script: $DONESCRIPT

    invoking $self without any args will bring up this info text.

EOT
}

if [ $# = 0 ]; then
    usage
    exit
fi

bye () {
    status="${1:-$?}"
    set +e
    if [ $status = 0 ]; then
        exit
    elif [ $status = 23 ]; then
        log "[$self] background job: ${!:-none}"
    else
        err "[$self] exit $status"
    fi
    exit $status
}

trap bye HUP INT KILL

##
#  all set! let's start it up!
##

# wrappers for calling $DONESCRIPT
finished () {
    "$DONESCRIPT" success "$@"
}

failed () {
    status=$?
    "$DONESCRIPT" "$status" "$@"
}

# link type detection (to be improved)
link="$1"
if [ -z "$1" ]; then
    link_type=nothing
elif [ ! "${1%%.torrent}" = "$1" ]; then
    link_type=torrent
elif [ ! "${1##http://www.youtube.com/}" = "$1" ]; then
    link_type=youtube
else
    link_type=wget
fi

log "[$self] detected link type: $link_type"

# now define the download methods for these types

download_nothing () {
    err "[$self] empty link -> bug?"
    set +e
    false
}

download_wget () {
    link="$1"
    localname="$(basename "$link")"
    if [ -f "$localname" ]; then
        log "[wget] resuming: $localname"
        WGET_ARGS="-c $WGET_ARGS"
    else
        log "[wget] new file: $localname"
    fi
    set +e
    $DEFAULTLOADER $WGET_ARGS "$link" -O "$localname" &&
            finished "$link" "$PWD/$localname" || failed "$link"
}

download_torrent () {
    mkdir -p torrents
    torrentfile="$(basename "$1")"
    localtorrent="torrents/$(basename "$1")"
    rm -f "$localtorrent"
    $DEFAULTLOADER $WGET_ARGS "$1" -O "$localtorrent" || failed "$1"
    if which ctorrent; then
        DONECALL="$DONESCRIPT success $1 $PWD/$localtorrent $PWD/${torrentfile%%.torrent}"
        set +e
        if pidof "$TORRENTCLIENT" | grep -q " "; then
            log "[torrent] runnning: $(pidof "$TORRENTCLIENT") -> delaying $localtorrent"
        else
            log "[torrent] launching: $TORRENTCLIENT $TORRENT_ARGS $localtorrent"
            TORRENT_ARGS="$TORRENT_ARGS -X 'CONFIG=$CONFIG $DONECALL'"
            "$TORRENTCLIENT" $TORRENT_ARGS "torrents/$localtorrent" ||
                failed "$1" &
        fi
        bye 23  # download deferred...
    else
        err "[torrent] $TORRENTCLIENT not available $localtorrent"
        finished "$1" "$PWD/$localtorrent"  # stops retrying.
    fi
}

download_youtube () {
    if which $YOUTUBEHELPER; then
        log "[youtube] $YOUTUBEHELPER $YOUTUBE_ARGS $1"
        set +e
        "$YOUTUBEHELPER" $YOUTUBE_ARGS "$1" &&
            finished "$1" "$PWD/$("$YOUTUBEHELPER" $YOUTUBE_ARGS "$1")" ||
            failed "$1"
    else
        err "[youtube] no $YOUTUBEHELPER :-("
        failed "$1"
    fi
}

download_$link_type "$1"
bye $?
