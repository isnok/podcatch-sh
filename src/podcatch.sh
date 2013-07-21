#!/bin/sh
#
# podcatch.sh - An attempt on catching casts with a few shell scripts.
#
# Now including some good practises and paranoia hints found here:
#
#    - http://www.ooblick.com/text/sh/
#
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
    ${ERROR_LOG:="/dev/null"} \
    ${LAST_FETCH:="last-fetched-feed.txt"} \
    ${LAST_PARSE:="last-parsed"}

export LINKS_DOWNED LINKS_FAILED
export LOGFILE FETCH_LOG ERROR_LOG
export LAST_FETCH LAST_PARSE

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
: ${FEEDER:="$here/grabfeed.sh"}
: ${SMARTDL:="$here/smartdl.sh"}
: ${DONESCRIPT:="$here/done.sh"}
export PARSERSHS SMARTDL DONESCRIPT

# set download root and make it an absolute path
: ${DLROOT:="/tmp/incoming"} ${LISTDIR:="$here/../cfg"}
DLROOT="$(prepend_if_relative "$PWD" "$DLROOT")"
unset here

# options for behaviour control ('sh-bools')
# here, these can be set via command line args
: ${initignoring:=false}
: ${fetchfeed:=true}
: ${reuseparse:=false}
: ${downloadepisodes:=true}
export initignoring fetchfeed reuseparse downloadepisodes

# define some helper functions:
log () {
    echo "$(date) $@" | tee -a "$LOGFILE"
}

err () {
    echo "$(date) $@" | tee -a "$LOGFILE" "$ERROR_LOG" 1>&2
}

usage () {
    cat <<EOT
$self - a shell scripted podcatcher for openwrt devices

usage: $self [args/castlists]

The arguments are processed in the order they are given.
All oter arguments not listed below are treated as castlists.
'all' a is a special castlist, instructing to fetch all castlists.
'all' is the default behaviour if no args are given.

To change behaviour of $self use:

    -ne|--no-episodes   don't download episodes
    -nf|--no-feeds      don't download feeds (reuse last fetched version)
    -np|--no-parse      reuse last parsed feed (implies -nf)
    -da|--download-all  reset all -n options (default)
    -if|--init-fetched  if a new feed is found, initialize it's episodes as fetched
    -iw|--init-wanted   if a new feed is found, download all of it's episodes (default)
    -h|--help           print this help

Note that if you use one of these, you should also specify a castlist.

Argument combos that drove development:

    $self -ne all  # fetch-and-parse-only on all feeds (almost-dry-run, inits new casts)
    $self -np all  # continue all without re-fetching and re-parsing
    $self -nf -ne jtv  # re-parse the previously fetched feeds from \$LISTDIR/jtv.lst
    $self -if cczwei -ne chaos -h -da casts # you get the idea...

EOT
}

log "[$self] starting up (pid $$)"

bye () {
    status="${1:-$?}"
    set +e
    if [ "$status" -gt 0 ]; then
        err "[$self] exit status $status! :-("
    else
        log "[$self] all finished, no errors! :-)"
    fi
    exit $status
}

trap bye HUP INT KILL

##
#  all set! let's start up the fun.
##

dl_workdir () {
    DLWORKDIR="$(prepend_if_relative "$DLROOT" "$1")"
    log "[chdir] ($castlist:${linecnt:-start}) $DLWORKDIR"
    mkdir -p "$DLWORKDIR"
    cd "$DLWORKDIR"
}

set_parsers () {
    parsers="$(echo -n $1 | sed -e 's/^ *//' -e 's/  */ /g' -e 's/ *$//')"
    log "[parsers] ($castlist:$linecnt) $parsers"
}

inspect_line () {
    if echo "$1" | grep -q '^[ \t]*\(#.*\)\{0,1\}$'; then
        echo comment
    elif echo "$1" | grep -q ' ---> '; then
        echo feed
    elif [ ! "${1##DLDIR=}" = "$1" ]; then
        echo workdir
    elif [ ! "${1##PARSERS:}" = "$1" ]; then
        echo parsers
    else
        echo unknown
    fi
}

parse_feed_line () {
    url=$(echo -n "$1" | sed -n "s/^[ \t]*\([^ \t].*[^ \t]\)[ \t]*--->.*/\1/p")
    destination=$(echo -n "$1" | sed -n "s/.*--->[ \t]*\([^ \t].*[^ \t]\)[ \t]*$/\1/p")
    if [ "${destination##/}" = "$destination" ]; then
        destination="$DLWORKDIR/$destination"
    fi
    log "[feed] ($castlist:$linecnt) $(basename "$url") --> $(basename "$destination")"
}

process_line () {
    line_type="$(inspect_line "$1")"
    case "$line_type" in
        comment|ignore)
            #log "[process] $line"
            ;;
        workdir)
            dl_workdir "${line##DLDIR=}"
            ;;
        parsers)
            set_parsers "${line##PARSERS:}"
            ;;
        feed)
            castcnt=$((1+$castcnt))
            parse_feed_line "$line"
            "$FEEDER" "$url" "$destination" $parsers 2>&1 |
                tee -a "$LOGFILE" ||
                err "[$self] ($castlist:$linecnt) $FEEDER failed ($?) :-?"
            ;;
        *)
            err "[$self] ($castlist:$linecnt) $line_type -> buggy cfg?"
            ;;
    esac
}

process_list () {
    castlist="$(basename "$1")"
    dl_workdir "."
    linecnt=0
    while read line; do
        linecnt=$((1+$linecnt))
        process_line "$line"
    done < "$1"
}

process_lists () {
    listcnt=$#
    while [ $# -gt 0 ]; do
        curcnt=$((1+$listcnt-$#))
        log "[process_list] ($curcnt/$listcnt) start: $1"
        if [ -r "$1" ]; then
            process_list "$1"
        else
            log "[process_list] ($curcnt/$listcnt) access error: $1"
        fi
        shift
    done
}

handle_arg () {
    arg="$1"
    case "$arg" in
        -nf|--no-feeds)
            log "[args] set fetch-feed: false"
            export fetchfeed=false
            ;;
        -np|--no-parse)
            log "[args] set fetch-feed, parse-feed: false"
            export fetchfeed=false parsefeed=false
            ;;
        -ne|--no-episodes)
            log "[args] set fetch-episodes: false"
            export downloadepisodes=false
            ;;
        -da|--download-all)
            log "[args] set download-*: true"
            export fetchfeed=true parsefeed=true downloadepisodes=true
            ;;
        -if|--init-fetched)
            log "[args] init new feeds as: fetched"
            export initignoring=true
            ;;
        -iw|--init-wanted)
            log "[args] init new feeds as: wanted"
            export initignoring=false
            ;;
        -h|--help)
            usage
            ;;
        all)
            process_lists "$LISTDIR"/*.lst
            ;;
        *)
            process_lists "$LISTDIR/$arg.lst"
            ;;
    esac
}

castcnt=0
if [ $# = 0 ]; then
    log "[script] no args -> process_all"
    process_lists "$LISTDIR"/*.lst
else
    while [ $# -gt 0 ]; do
        handle_arg "$1"
        shift
    done
fi
bye
