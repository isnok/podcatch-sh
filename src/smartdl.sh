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

resume=false
link="$1"
if [ "$link" = -c ]; then
    resume=true
    link="$2"
fi

if [ -z "$link" ]; then
    exit
fi

# to start off, the available download-helpers can be configured here:
TORRENTCLIENT="ctorrent"
YOUTUBEHELPER=youtube-dl
CLASSICLOADER=wget

download_classic () {
    if $resume; then
        $CLASSICLOADER -c "$1"
    else
        $CLASSICLOADER "$1"
    fi
}


is_torrent () {
    test ! "${1%%.torrent}" = "$1"
}

download_torrent () {
    $CLASSICLOADER "$1" || true
    if [ -x "$(which $TORRENTCLIENT)" ]; then
        $TORRENTCLIENT -dd -e 0 -X "/mnt/brueckencache/podcatch/src/done.sh" "$(basename $1)"
    else
        echo "[torrent] failing silently... :-)"
    fi
}


is_tube () {
    echo $1 | grep -q "\(youtube\|vimeo\|\)"
}

download_tube () {
    if [ -x "$(which $YOUTUBEHELPER)" ]; then
        if $resume; then
            $YOUTUBEHELPER -c "$1"
        else
            $YOUTUBEHELPER "$1"
        fi
    else
        echo "[youtube] failing silently... :-)"
    fi
}

if is_torrent "$link"; then
    download_torrent "$link"
elif is_tube "$link"; then
    download_tube "$link"
else
    download_classic "$link"
fi
# we have kept the downloaders (if available) the last executed command
exit $?
