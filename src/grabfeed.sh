#!/bin/sh
#
# grabfeed.sh - Grab a feed url to a directory.
#
IFS=
PATH=/bin:/usr/bin
set -e

: ${CONFIG:=$PWD/podcatch-config.sh}
if [ -r "$CONFIG" ]; then
    . "$CONFIG"
    export CONFIG
fi

self=$(basename "$0")

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
    ${ERROR_LOG:="/dev/null"} \
    ${LAST_FETCH:="last-fetched-feed.txt"} \
    ${LAST_PARSE:="last-parsed"}

export LINKS_DOWNED LINKS_FAILED
export LOGFILE FETCH_LOG ERROR_LOG

prepend_if_relative () {
    if [ x"${2##/}" = x"$2" ]; then
        echo "$1/$2"  # try to make a relative path absolute
    else
        echo "$2"
    fi
}

# Set some (probably) sane defaults,
here="$(dirname "$0")"
here="$(prepend_if_relative "$PWD" "$here")"
: ${PARSERSHS:="$here/catchers"}
: ${SMARTDL:="$here/smartdl.sh"}
: ${DONESCRIPT:="$here/done.sh"}
export DONESCRIPT
unset here

# options for behaviour control ('sh-bools')
# for now, these can only be set via the environment
: ${initignoring:=false}
: ${fetchfeed:=true}
: ${reuseparse:=false}
: ${downloadepisodes:=true}

log () {
    echo "$(date) $@"
}

err () {
    echo "$(date) $@" | tee -a "$ERROR_LOG" 1>&2
}

usage () {
    cat <<EOT
$self - a shell scripted feed grabber

usage: $self [feed] [destination] [parser(s)]

    grab one (probably not initialized) feed
    to a destination directory using parser(s)

    no args yield this usage text.

EOT
}

if [ $# = 0 ]; then
    usage
    exit
fi

##
#  all set! let's start up the fun.
##

destination="."
feed="$1"
shift
if [ -z "$feed" ]; then
    err "[$self] empty feed -> bug?"
    exit 1
fi
log "[$self] feed: $feed"

if [ $# -gt 0 ]; then
    destination="$1"
    shift
fi
if [ -z "$destination" ]; then
    err "[$self] empty destination -> bug?"
    exit 1
elif ! mkdir -p "$destination"; then
    err "[$self] could not create destination: $destination"
    exit 1
elif ! [ -w "$destination" ]; then
    err "[$self] destination not writable: $destination"
    exit 1
fi

lastfeed="$(prepend_if_relative "$destination" "$LAST_FETCH")"
lastparse="$(prepend_if_relative "$destination" "$LAST_PARSE")"
dontfetch="$(prepend_if_relative "$destination" "$LINKS_DOWNED")"
failedlst="$(prepend_if_relative "$destination" "$LINKS_FAILED")"

log "[$self] destination: $(prepend_if_relative "$PWD" "$destination")"

log "[$self] parsers: ${@:-everything}"

bye () {
    status="${1:-$?}"
    set +e
    if [ "$status" -gt 0 ]; then
        err "[$self] error ($status) - $feed"
    else
        log "[$self] finished: $feed"
    fi
    exit $status
}

trap bye HUP INT KILL

##
#  fetch feed
##

# check reuse
if $fetchfeed; then
    rm -f "$lastfeed"
else
    if [ -r "$lastfeed" ]; then
        log "[$self] reusing $lastfeed"
    else
        err "[$self] cannot reuse $lastfeed"
        rm -f "$lastfeed"
    fi
fi

if [ ! -f "$lastfeed" ]; then
    log "[$self] $feed"
    if wget "$feed" -O "$lastfeed"; then
        log "[$self] success: $(wc $lastfeed)"
    else
        err "[$self] failed to fetch feed :-("
        bye 1
    fi
fi

##
#  parse feed
##

# check reuse
if ! $reuseparse; then
    rm -f "$lastparse"-*.txt
fi

# how to apply one parser
parse_feed () {
    parsed="$lastparse-$1.txt"

    # log reuse
    if [ -r "$parsed" ]; then
        log "[$self] reusing $parsed"
    elif $reuseparse; then
        err "[$self] cannot reuse $parsed"
        rm -f "$parsed"
    fi

    parser="$PARSERSHS/$1.sh"
    if ! [ -x "$parser" ]; then
        err "[$self] not executable: $parser -> ignoring"
        touch "$parsed"
    fi

    if [ -r "$parsed" ]; then
        return
    fi
    "$parser" "$lastfeed" > "$parsed" || true
    log "[$self] filtered: $1 -> $(wc -l "$parsed")"
}

# harvest links (apply parsers)
if [ $# = 0 ]; then
    parse_feed everything
else
    while [ $# -gt 0 ]; do
        parse_feed "$1"
        shift
    done
fi

harvested="$(sort "$lastparse"-*.txt | uniq)"
if [ -z "$harvested" ]; then
    log "[$self] no links harvested -> ???"
    bye 1
fi
harvestedcnt="$(echo "$harvested" | wc -l)"

# check for new cast (via dontfetch)
if ! [ -r "$dontfetch" ]; then
    if $initignoring; then
        log "[$self] init $dontfetch from $lastparse"
        cat "$lastparse"-* "$dontfetch" | sort | uniq > "$dontfetch"
    else
        log "[$self] init with empty $dontfetch"
        touch "$dontfetch"
    fi
fi

# filter harvested links
if [ -s "$dontfetch" ]; then
    needfetch="$(echo -n "$harvested" | grep -v -f "$dontfetch" || true)"
    #needfetch="$(echo -n "$harvested" | grep -v -x -f "$dontfetch" || true)"
else
    needfetch="$harvested"
fi

if [ -z "$needfetch" ]; then
    #log "[$self] nothing new"
    bye
fi
fetchcnt="$(echo "$needfetch" | wc -l)"

##
#  download episodes
##
log "[$self] harvested {$harvestedcnt} - dontfetch {$(wc -l "$dontfetch" | cut -d" " -f1)} = needfetch {$fetchcnt}"

if ! $downloadepisodes; then
    log "[$self] skipping download of $fetchcnt new episodes"
    bye
fi

curfetch=0
echo "$needfetch" | while read link; do
    curfetch=$((1+$curfetch))
    log "[$self] ($curfetch/$fetchcnt) $link --> $destination"

    cd "$destination"
    set +e
    "$SMARTDL" "$link"
    status=$?
    set -e
    cd "$OLDPWD"

    #if [ $status = 0 ]; then
    #    log "[$self] $link"
    #elif [ $status = 23 ]; then
    #    log "[$self] $link"
    #else
    #    log "[$self] downloader exit: $status"
    #fi
done
bye
