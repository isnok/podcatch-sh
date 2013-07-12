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

# okay, here's the deal:
# in order to "emulate" all of wget the behaviour used in podcatch.sh,
# all we get is one arg (our download) or two (-c and the download).

LOGFILE=/mnt/brueckencache/podcatch/smartdl.log

log () {
    echo "$(date) [smartdl] $@" | tee -a "$LOGFILE"
}

log "startup: $PWD $0 $@"

resume=false
link="$1"
if [ "$link" = -c ]; then
    resume=true
    link="$2"
fi

if [ -z "$link" ]; then
    log "error: empty link"
    exit 1
fi

# to start off, the available download-helpers can be configured here:
TORRENTCLIENT=ctorrent
YOUTUBEHELPER=youtube-dl
CLASSICLOADER=wget

download_classic () {
    if $resume; then
        log "launching: $CLASSICLOADER -c $1"
        $CLASSICLOADER -c "$1"
    else
        log "launching: $CLASSICLOADER $1"
        $CLASSICLOADER "$1"
    fi
}


is_torrent () {
    test ! "${1%%.torrent}" = "$1"
}

download_torrent () {
    $CLASSICLOADER "$1" || true
    if [ -x "$(which $TORRENTCLIENT)" ]; then
        log "launching: $TORRENTCLIENT -dd -e 0 -X '/mnt/brueckencache/podcatch/src/done.sh $1 d:&d t:&t w:&w' $(basename $1)"
        $TORRENTCLIENT -d -e 2 -X "/mnt/brueckencache/podcatch/src/done.sh $1 d:&d t:&t w:&w" "$(basename $1)"
    else
        log "not executable: $TORRENTCLIENT"
    fi
}


is_tube () {
    echo $1 | grep -q "\(youtube\|vimeo\|\)"
}

download_tube () {
    if [ -x "$(which $YOUTUBEHELPER)" ]; then
        if $resume; then
            log "launching: $YOUTUBEHELPER -c $1"
            $YOUTUBEHELPER -c "$1"
        else
            log "launching: $YOUTUBEHELPER $1"
            $YOUTUBEHELPER "$1"
        fi
    else
        log "not executable: $YOUTUBEHELPER"
    fi
}

if is_torrent "$link"; then
    download_torrent "$link"
elif is_tube "$link"; then
    download_tube "$link"
else
    download_classic "$link"
fi
exit_status=$?
log "done: $exit_status"
# we have kept the downloaders (if available) the last executed command
exit $exit_status
