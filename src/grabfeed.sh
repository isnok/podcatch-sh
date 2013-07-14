#!/bin/sh
#
# grabfeed.sh - Grab a feed url to a directory.
#
IFS=
PATH=/bin:/usr/bin
set -e

#
# Set some (probably) sane defaults, derived from environment variables
#
here="$(dirname $0)"
if [ x"${here##/}" = x"$here" ]; then
    here="$PWD/$here"  # try to make a relative path absolute
fi
#
# the directory containing feed parsers
: ${PARSERSHS:="$here/catchers"}
#
# files that hold podcatching state (in destination directory)
: ${LAST_FETCH:=last-fetched-feed.txt}
: ${LAST_PARSE:=last-parsed-feed.txt}
: ${LINKS_DOWNED:=podcatch-dontfetch.txt}
# pass on configuration
export LINKS_DOWNED LINKS_FAILED
export LOGFILE FETCH_LOG ERROR_LOG
#
# the smart downloader scripts
: ${SMARTDL:="$here/smartdl.sh"}
: ${DONESCRIPT:="$here/done.sh"}
export DONESCRIPT
#
# options for behaviour control ('sh-bools')
# for now, these can only be set via the environment
: ${initignoring:=false}
: ${fetchfeed:=true}
: ${parsefeed:=true}
: ${downloadepisodes:=true}
#
# variables understood by $SMARTDL
: ${FETCH_LOG:="$here/grabfeed-fetched.m3u"}
: ${ERROR_LOG:="$here/grabfeed-errors.log"}
#
# make relevant variables available to $SMARTDL:
export FETCH_LOG ERROR_LOG
unset here

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
if [ $# -gt 0 ]; then
    destination="$1"
    shift
    while [ $# -gt 0 ]; do
        parsers="$1\n$parsers"
        shift
    done
fi
: ${parsers:="everything"}
parsers=$(echo -e -n $parsers | tr "\n" ' ' | sed -e 's/^ *//' -e 's/  */ /g' -e 's/ *$//')
log "[grabfeed] starting: $feed --($parsers)--> $destination"

bye () {
    status="${1:-$?}"
    set +e
    if [ "$status" -gt 0 ]; then
        err "[grabfeed] exit $status"
    else
        log "[grabfeed] done"
    fi
    exit $status
}

trap bye HUP INT KILL

mkdir -p "$destination"

lastfeed="$destination/$LAST_FETCH"
lastparse="$destination/$LAST_PARSE"
dontfetch="$destination/$LINKS_DOWNED"
failedlst="$destination/$LINKS_FAILED"

##
#  fetch feed
##

if $fetchfeed; then
    rm -f "$lastfeed"
else
    if [ -r "$lastfeed" ]; then
        log "[fetch_feed] reusing $lastfeed"
    else
        err "[fetch_feed] cannot reuse $lastfeed"
        rm -f "$lastfeed"
    fi
fi

line_count () {
    wc -l "$@" | awk '{ print $1; }'
}

if [ ! -f "$lastfeed" ]; then
    log "[fetch_feed] $feed"
    wget "$feed" -O "$lastfeed" && {
        log "[fetch_feed] success: $(wc $lastfeed)"
    }  || {
        err "[fetch_feed] failed to fetch feed :-("
        bye 1
    }
fi

##
#  parse feed
##

# check reuse
if $parsefeed; then
    rm -f "$lastparse"
else
    if [ -r "$lastparse" ]; then
        log "[parse_feed] reusing $lastparse"
    else
        err "[parse_feed] cannot reuse $lastparse"
        rm -f "$lastparse"
    fi
fi

# apply parsers
if [ ! -f "$lastparse" ]; then
    echo "$parsers" | tr " " "\n" | while read parser; do
        sh "$PARSERSHS/$parser.sh" "$lastfeed"
    done | sort | uniq > "$lastparse"
    log "[parse_feed] harvested $(line_count $lastparse) links"
fi

# check for new cast (via dontfetch)
if [ ! -f "$dontfetch" ]; then
    if $initignoring; then
        log "[init_cast] bootstrap $LINKS_DOWNED from $lastparse"
        cp "$lastparse" "$dontfetch"
    else
        log "[init_cast] bootstrap using empty $LINKS_DOWNED"
        touch "$dontfetch"
    fi
fi

# filter harvested links
if [ -s "$dontfetch" ]; then
    needfetch="$(grep -v -f $dontfetch $lastparse || true)"
    #needfetch="$(grep -v -x -f $dontfetch $lastparse || true)"
elif [ -s "$lastparse" ]; then
    needfetch="$(cat $lastparse)"
else
    needfetch=""
fi

##
#  download episodes
##

if [ -z "$needfetch" ]; then
    log "[calc_catch] nothing new"
    bye 42
else
    newcnt="$(echo $needfetch | line_count)"
fi

if $downloadepisodes; then
    log "[calc_catch] will download $newcnt new links"
else
    log "[calc_catch] skipping download of $newcnt new links"
    bye 42
fi

epicnt=0
echo "$needfetch" | while read link; do
    epicnt=$((1+$epicnt))
    log "[fetch_episode] ($epicnt/$newcnt) $link --> $destination"

    cd "$destination"
    set +e
    "$SMARTDL" "$link"
    status=$?
    set -e
    cd "$OLDPWD"

    if [ $status = 0 ]; then
        log "[episode_fetched] $link"
        echo "$link" >> "$dontfetch"
    elif [ $status = 23 ]; then
        log "[episode_deferred] $link"
    else
        log "[episode_failed] exited $status: $link"
    fi
done
bye
