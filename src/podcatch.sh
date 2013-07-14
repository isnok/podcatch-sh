#!/bin/sh
#
# podcatch.sh - An attempt on catching casts with a few shell scripts.
#
# Now including some good practises and paranoia hints found here:
#
#    - http://www.ooblick.com/text/sh/
#
IFS=
PATH=/bin:/usr/bin
set -e

if [ $# -gt 2 ] && [ x"$1" = x-c ]; then
    CONFIG="$2"
    export CONFIG
    source "$CONFIG"
    shift 2
fi

#
# Set some (probably) sane defaults, derived from config values
#
here="$(dirname $0)"
if [ x"${here##/}" = x"$here" ]; then
    here="$PWD/$here"  # try to make a relative path absolute
fi
#
# the cast list directory
: ${LISTDIR:="$here/../cfg"}
#
# the other scripts
: ${FEEDER:="$here/grabfeed.sh"}
: ${PARSERSHS:="$here/catchers"}
: ${SMARTDL:="$here/smartdl.sh"}
: ${DONESCRIPT:="$here/done.sh"}
export PARSERSHS SMARTDL DONESCRIPT
#
# the location to where logs are written
: ${LOGDIR:="$here/.."}  # by default the root of the git repository
unset here
#
# logfile, list of newly downloaded files and error log
: ${LOGFILE:="$LOGDIR/podcatch.log"}
: ${FETCH_LOG:="$LOGDIR/podcatch-fetched.m3u"}
: ${ERROR_LOG:="$LOGDIR/podcatch-errors.log"}
export LOGFILE FETCH_LOG ERROR_LOG
#
# initial values for behaviour control options
# (all 'sh-boolean' and accessible via arguments - see end of script)
#: ${preservetemp:=false}
: ${initignoring:=false}
: ${fetchfeed:=true}
: ${parsefeed:=true}
: ${downloadepisodes:=true}
export initignoring fetchfeed parsefeed downloadepisodes
#
# set download root and make it an absolute path
: ${DLROOT:="/tmp/incoming"}
if [ x"${DLROOT##/}" = x"$DLROOT" ]; then
    DLROOT="$PWD/$DLROOT"
fi
DLWORKDIR="$DLROOT"

# define some helper functions:
touch "$LOGFILE"
log () {
    echo "$(date) $@" | tee -a "$LOGFILE"
}

err () {
    touch "$ERROR_LOG"
    echo "$(date) $@" | tee -a "$LOGFILE" "$ERROR_LOG" 1>&2
}

usage () {
    self=$(basename $0)
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

log "[podcatch] running at pid $$, tmpdir: $TMPDIR"

bye () {
    status="${1:-$?}"
    set +e
    if [ "$status" -gt 0 ]; then
        err "[podcatch] exit $status"
    else
        log "[podcatch] done"
    fi
    exit $status
}

trap bye HUP INT KILL

##
#  all set! let's start up the fun.
##

set_workdir () {
    if [ x"${1##/}" = x"$1" ]; then
        DLWORKDIR="$DLROOT/$1"  # make relative path absolute
    else
        DLWORKDIR="$1"
    fi
    log "[chdir] $DLWORKDIR"
    mkdir -p "$DLWORKDIR"
    cd "$DLWORKDIR"
}
set_workdir "$DLROOT"

set_parsers () {
    parsers=$(echo -n $1 | sed -e 's/^ *//' -e 's/  */ /g' -e 's/ *$//')
    log "[parsers] $parsers"
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

parse_line () {
    url=$(echo -n "$1" | sed -n "s/^[ \t]*\([^ \t].*[^ \t]\)[ \t]*--->.*/\1/p")
    destination=$(echo -n "$1" | sed -n "s/.*--->[ \t]*\([^ \t].*[^ \t]\)[ \t]*$/\1/p")
    if [ "${destination##/}" = "$destination" ]; then
        destination="$DLWORKDIR/$destination"
    fi
    log "[parse_line@$linecnt] $url ---> $destination"
}

process () {
    linecnt=0
    while read line; do
        linecnt=$((1+$linecnt))
        case $(inspect_line "$line") in
            comment|ignore)
                #log "[process @ $linecnt] $line"
                ;;
            workdir)
                log "[process@$linecnt] $line"
                set_workdir "${line##DLDIR=}"
                ;;
            parsers)
                log "[process@$linecnt] $line"
                set_parsers "${line##PARSERS:}"
                ;;
            feed)
                castcnt=$((1+$castcnt))
                parse_line "$line"
                "$FEEDER" "$url" "$destination" $parsers 2>&1 |
                    tee -a "$LOGFILE" ||
                    err "[process@$linecnt] $FEEDER failed ($?) :-?"
                ;;
            *)
                err "[process@$linecnt] $1 is buggy cfg? $line"
                ;;
        esac
    done < "$1"
}

process_lists () {
    listcnt=$#
    while [ $# -gt 0 ]; do
        curcnt=$((1+$listcnt-$#))
        log "[process_list] ($curcnt/$listcnt) start: $1"
        if [ -r "$1" ]; then
            process "$1"
        else
            log "[process_list] ($curcnt/$listcnt) access error: $1"
        fi
        shift
    done
}

castcnt=0
if [ $# = 0 ]; then
    log "[script] no args -> process_all"
    process_lists "$LISTDIR"/*.lst
else
    while [ $# -gt 0 ]; do
        arg="$1"
        shift
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
    done
fi
bye
