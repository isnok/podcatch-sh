#!/bin/sh
#
# smartdl.sh - a torrent-aware wrapper for wget
#
# i'll try this approach:
#
# leave the pluggability of podcatch.sh as is (feed parsing only),
# and instead of adding a new plugin slot for torrent/*tube type downloads,
# i'd like to try out how far auto-detection from the link scales.
# it's gonna be a nice ~/bin script anyway.
#
IFS=
PATH=/bin:/usr/bin
set -e

# to ease things for now, we only support downloading the
# first command line argument to the current directory.
#
# to start off, the available download-helpers can be configured here:

# the callback companion
: ${DONESCRIPT:="$(dirname $0)/done.sh"}
# and vars to be carried over to it
: ${FETCH_LOG:="/dev/null"}
: ${ERROR_LOG:="/dev/null"}
: ${LINKS_DOWNED:="/dev/null"}
: ${LINKS_FAILED:="/dev/null"}
export FETCH_LOG LINKS_DOWNED ERROR_LOG LINKS_FAILED

TORRENTCLIENT="ctorrent -d -e 2"
#YOUTUBEHELPER="youtube-dl -c -t"

# and wrappers for using it
finished () {
    "$DONESCRIPT" success "$@"
}

failed () {
    "$DONESCRIPT" fail "$1"
}

# we will end up launching the function: download_$(inspect_link)
inspect_link () {
    if [ -z "$1" ]; then
        echo nothing
    elif [ ! "${1%%.torrent}" = "$1" ]; then
        echo torrent
    elif [ ! "${1##http://www.youtube.com/}" = "$1" ]; then
        echo tube
    else
        echo classic
    fi
}

download_nothing () {
    err "[download] empty link -> bug?"
    set +e
    false
}

download_classic () {
    # the default way to download anything non-exceptionally
    link="$1"
    localname="$(basename $link)"
    if [ -f $localname ]; then
        resume=true
    fi
    log "[wget] $link --> $localname"
    set +e
    if $resume; then
        wget -c "$link" -O "$localname" &&
            finished "$link" "$PWD/$localname" ||
            failed "$link"
    else
        #echo wget "$link" -O "$localname" &&
        #    finished "$link" "$PWD/$localname" ||
        #    failed "$link"
        wget "$link" -O "$localname" &&
            finished "$link" "$PWD/$localname"
            # just fail on continue seems okay for now
    fi
}

download_torrent () {
    localtorrent="$(basename $1)"
    mkdir -p torrents
    cd torrents
    rm -f "$localtorrent"
    wget "$1" -O "$localtorrent"
    cd ..
    if which $TORRENTCLIENT; then
        DONECALL="$DONESCRIPT success $1 $localtorrent &d/${localtorrent%%.torrent}"
        set +e
        if pidof podcatch.sh | grep -q " "; then
            log "[torrent] delaying $localtorrent ($(pidof podcatch.sh))"
        else
            log "[torrent] $TORRENTCLIENT -X '$DONECALL' torrents/$localtorrent"
            $TORRENTCLIENT -X "LOGFILE='$LOGFILE' $DONECALL torrents/$localtorrent" || failed "$1" &
        fi
        bye 23  # download deferred...
    else
        err "[torrent] ctorrent not available to further process $localtorrent"
        finished "$1" "$localtorrent"
    fi
}

download_tube () {
    if which $YOUTUBEHELPER; then
        log "[tubes] $YOUTUBEHELPER $1"
        set +e
        echo $YOUTUBEHELPER "$1" && finished "$1" "$PWD (new tube stuff)" || failed "$1"
    else
        err "[tubes] youtube-dl unavailable"
        finished "$1" "no youtube-dl :-("
    fi
}

log () {
    echo "$(date) $@"
}

err () {
    touch "$ERROR_LOG"
    echo "$(date) $@" | tee -a "$ERROR_LOG" 1>&2
}

usage () {
    self=$(basename $0)
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

log "[smartdl] startup: $PWD"

bye () {
    status="${1:-$?}"
    set +e
    if [ $status = 0 ]; then
        log "[smartdl] done"
    elif [ $status = 23 ]; then
        log "[smartdl] done ;-)"
    else
        err "[smartdl] exit $status"
    fi
    exit $status
}

trap bye HUP INT KILL

##
#  all set! let's start it up!
##

linktype="$(inspect_link $1)"
log "[link_type] $linktype: $1"
download_$linktype "$1"
bye $?
