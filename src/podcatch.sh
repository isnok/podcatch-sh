#!/bin/sh
#
# podcatch.sh - an attempt on catching casts with a shell script
#
# Designed for minimal dependencies:
# wget (and not even sed)
#
# TODO:
#
# * empty line behaviour in dontfetch
# * convenient way(s) to add new casts
#

# assumed static values:
FETCHDTXT=podcatch-dontfetch.txt
FAILEDTXT=podcatch-failed.txt
LASTFETCH=last-feed-fetched.txt
LASTPARSE=last-parsed-feed.txt

# setup some directories:
LISTDIR="$(dirname $0)/../cfg"
PLUGDIR="$(dirname $0)/../src/catchers"

# create a directory for temporary files
TMPDIR="$PWD/$(mktemp -d castget-XXXXXX)"

be_alive () {
    touch "$TMPDIR/podcatch.alive"
}

cleanup () {
    status=$?
    log "[script] cleanup $TMPDIR && exit $status"
    rm -rvf "$TMPDIR"
    exit $status
}

trap cleanup HUP INT KILL

# logfile should of course be writable
LOGFILE="$PWD/podcatch.log"

log () {
    echo "$(date) $1" | tee -a "$LOGFILE"
    be_alive || cleanup
}


log "[script] running at pid $$, tmpdir: $TMPDIR" || exit
echo -n $$ > "$TMPDIR/podcatch.pid"

# set initial value for the DLDIR and options
DLROOT=.
uselast=""
downloadepisodes=true
initignoring=false

usage () {
    self=$(basename $0)
    cat <<EOF
$self - a shell scripted podcatcher for openwrt devices

usage: $self [args/castlists]

The arguments are processed in the order they are given.
All arguments not listed below are treated as castlists.
The castlists directory is configured in $self itself.
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

EOF
}

set_dlroot () {
    DLROOT="$1"
    log "[set_dlroot] $1"
}

# a helper function
line_count () {
    wc -l "$1" | sed 's/^ *\([0-9][0-9]*\) .*$/\1/'
}

fetch_episode () {
    log "[fetch_episode:$castcnt] ($epicnt/$epiall) $1"
    if [ -f "$(basename $1)" ]; then
        wget_args="-c"
    fi
    wget $wget_args "$1"
    wget_status=$?
    if [ $wget_status = 0 ]; then
        episode_fetched "$1"
    else
        if [ -z "$wget_args" ]; then
            episode_failed "$wget_status" "$1"
        else
            continued_fetch "$wget_status" "$1"
        fi
    fi
}

episode_fetched () {
    log "[episode_fetched] $1"
    echo "$1" >> $FETCHDTXT
}

episode_failed () {
    log "[episode_failed] exit status: $1 - $2"
    # if no file was created, we issue a warning
    if [ ! -f "$(basename $2)" ]; then
        log "[episode_failed] file $(basename $2) was not even created :-("
    fi
}

continued_fetch () {
    log "[continued_fetch] exit status: $1 - $2"
    #echo "$1" >> $FETCHDTXT
    if grep -q "$2" $FAILEDTXT; then
        log "[continued_fetch] happened before -> giving up"
        echo "$2" >> $FETCHDTXT
    else
        log "[continued_fetch] first time -> $FAILEDTXT"
        echo "$2" >> $FAILEDTXT
    fi
}

catch_episodes () {
    if [ "$(cat $1)" ]; then
        epiall=$(line_count $1)
        log "[catch_episodes:$castcnt] $epiall new episode(s): $(basename $1) -> $2"
        epicnt=0
        while read episode; do
            epicnt=$((1+$epicnt))
            cd "$2"
            fetch_episode "$episode"
            cd $OLDPWD
        done < "$1"
        log "[catch_episodes:$castcnt] finished catching $epiall episode(s) to $2"
    else
        log "[catch_episodes:$castcnt] nothing new -> no action"
    fi
}

cnt_name () {
    echo "$(basename $1) $(wc -l "$1" | sed 's/^ *\([0-9][0-9]*\) .*$/{\1}/')"
}

calc_catch () {
    if [ -f "$2" ]; then
        if [ "$(cat $2)" ]; then
            grep -v -f "$2" "$1" > "$3"
            #grep -v -x -f "$2" "$1" > "$3"
        else
            cp -v "$1" "$3"
        fi
    else
        if $initignoring; then
            log "[calc_catch:$castcnt] bootstrap $FETCHDTXT from $(basename $1)"
            cp -v "$1" "$2"
            touch "$3"
        else
            log "[calc_catch:$castcnt] bootstrap using empty $FETCHDTXT"
            touch "$2"
            cp -v "$1" "$3"
        fi
    fi
    log "[calc_catch:$castcnt] $(cnt_name $1) - $(cnt_name $2) = $(cnt_name $3)"
}

parse_feed () {
    log "[parse_feed:$castcnt] $SHELL $1.sh $(basename $2) | sort | uniq > $(basename $3)"
    $SHELL "$PLUGDIR/$1.sh" "$2" | sort | uniq > "$3"
}


fetch_feed () {
    log "[fetch_feed:$castcnt] $1 -> $(basename $2)"
    wget "$1" -O "$2"
}

catch_cast () {
    mkdir -p "$4"
    if [ -n "$uselast" ]; then
        log "[catch_cast:$castcnt] reusing $LASTFETCH"
        cp -v "$4/$LASTFETCH" "$2.feed"
    else
        fetch_feed "$1" "$2.feed"
        cp -v "$2.feed" "$4/$LASTFETCH"
    fi

    if [ "$uselast" = parsed ]; then
        log "[catch_cast:$castcnt] reusing $LASTPARSE"
        cp -v "$4/$LASTPARSE" "$2.parsed"
    else
        parse_feed "$3" "$2.feed" "$2.parsed"
        cp -v "$2.parsed" "$4/$LASTPARSE"
    fi

    calc_catch "$2.parsed" "$4/$FETCHDTXT" "$2.needfetch"

    if $downloadepisodes; then
        catch_episodes "$2.needfetch" "$4"
    else
        log "[catch_cast:$castcnt] skipping download of $(line_count $2.needfetch) episodes"
    fi
}

inspect_line () {
    if echo "$1" | grep -q '^[ \t]*\(#.*\)\{0,1\}$'; then
        echo comment
    elif echo "$1" | grep -q '...---.*-->[\t ]*.'; then
        echo feed
    elif [ ! "${1##DLDIR=}" = "$1" ]; then
        echo setdldir
    else
        echo unknown
    fi
}

parse_line () {
    url=$(echo -n "$1" | sed -n "s/^[ \t]*\([^ \t].*[^ \t]\)[ \t]*---.*/\1/p")

    catcher=$(echo "$1" | grep -o -- ' ---.*--> ')
    catcher="${catcher## ---}"
    catcher="${catcher%%--> }"

    destination=$(echo -n "$1" | sed -n "s/.*-->[ \t]*\([^ \t].*[^ \t]\)[ \t]*$/\1/p")
    if [ "${destination##/}" = "$destination" ]; then
        destination="$DLROOT/$destination"
    fi
    log "[parse_line@$linecnt] $url ---$catcher--> $destination"
}

process () {
    linecnt=0
    while read line; do
        linecnt=$((1+$linecnt))
        case $(inspect_line "$line") in
            comment|ignore)
                #log "[process @ $linecnt] $line"
                ;;
            feed)
                castcnt=$((1+$castcnt))
                log "[process@$linecnt] start catching cast number $castcnt"
                parse_line "$line"
                tmpname="$TMPDIR/$castcnt-$catcher"
                catch_cast "$url" "$tmpname" "$catcher" "$destination"
                log "[process@$linecnt] done catching cast number $castcnt"
                ;;
            setdldir)
                log "[process@$linecnt] $line"
                set_dlroot "${line##DLDIR=}"
                ;;
            *)
                log "[process@$linecnt] buggy cfg? $line"
                ;;
        esac
    done < "$1"
}

process_list () {
    log "[$1] start processing: $list"
    if [ -r "$2" ]; then
        process "$2"
    else
        log "[$1] cannot access: $2"
    fi
}

process_all () {
    for castlist in "$LISTDIR"/*.lst; do
        process_list process_all "$castlist"
    done
}

castcnt=0
if [ $# = 0 ]; then
    log "[args] no args -> process_all"
    process_all
else
    while [ -n "$1" ]; do
        case "$1" in
            -ne|--no-episodes)
                log "[args] set download-episodes: false"
                downloadepisodes=false
                ;;
            -nf|--no-feeds)
                log "[args] set uselast: feed"
                uselast=feed
                ;;
            -np|--no-parse)
                log "[args] set uselast: parsed"
                uselast=parsed
                ;;
            -da|--download-all)
                log "[args] set download-*: true"
                uselast=""
                downloadepisodes=true
                ;;
            -if|--init-fetched)
                log "[args] init new feeds as: fetched"
                initignoring=true
                ;;
            -iw|--init-wanted)
                log "[args] init new feeds as: wanted"
                initignoring=false
                ;;
            -h|--help)
                usage
                ;;
            all)
                log "[args] start processing: all"
                process_all
                ;;
            *)
                list="$LISTDIR/$1.lst"
                process_list args "$list"
                ;;
        esac
        shift
    done
fi
cleanup
