#!/bin/sh
#
# croncatch.sh - a cron launcher
#
# assures not to launch a second instance
# checks disk use percentage (no launch above 90%)
# changes to an appropriate working directory
# and runs the script (with args in the future?)
#
# Ideas:
# the disk space detection could also be useful
# in the script itself. (but it uses sed...)
#
# Reminder:
# 23 * * * * /foo/hourly-task -nao
# * 23 * * * /every/minute/from/eleven -to midnight
# 23 23 * * * /daily/job -ff
# 05,23,42 * * * * /almost/20-min-wise
# */15 * * * * /launch --every-15-minutes
#
IFS=" "
PATH=/bin:/usr/bin
set -e

: ${CONFIG:=/etc/podcatch-config.sh}
if [ -r "$CONFIG" ]; then
    . "$CONFIG"
    export CONFIG
fi

#
# prepare environment / configure podcatch
#
: ${LISTDIR:="/mnt/brueckencache/podcatch/cfg"}
# the default download destination
: ${DLROOT:="/mnt/brueckencache/incoming/podcasts"}
export LISTDIR DLROOT
#
# the other scripts
: ${SCRIPTDIR:="/mnt/brueckencache/podcatch/src"}
: ${PODCATCH:="$SCRIPTDIR/podcatch.sh"}

: ${FEEDER:="$SCRIPTDIR/grabfeed.sh"}
: ${PARSERSHS:="$SCRIPTDIR/catchers"}
: ${SMARTDL:="$SCRIPTDIR/smartdl.sh"}
: ${DONESCRIPT:="$SCRIPTDIR/done.sh"}
export FEEDER PARSERSHS SMARTDL DONESCRIPT
#
# the location to where loSCRIPTDIR are written
: ${LOGDIR:="/mnt/brueckencache/podcatch"}
export LOGDIR
#
# logfile, list of newly downloaded files and error log
: ${LOGFILE:="$LOGDIR/podcatch.log"}
: ${FETCH_LOG:="$LOGDIR/podcatch-fetched.m3u"}
: ${ERROR_LOG:="$LOGDIR/podcatch-errors.log"}
export LOGFILE FETCH_LOG ERROR_LOG
#
# initial values for behaviour control options (see $FEEDER)
: ${initignoring:="false"}
: ${fetchfeed:="true"}
: ${parsefeed:="true"}
: ${downloadepisodes:="true"}
export initignoring fetchfeed parsefeed downloadepisodes

# archive and local values
: ${ARCHIVER:="$SCRIPTDIR/archive.sh"}
: ${INCOMING:="/mnt/brueckencache/incoming"}
: ${ARCHIVE:="/mnt/brueckencache/archive"}
export INCOMING ARCHIVE

WATCHLIST="/tmp/croncatch.watch"

self="$(basename "$0")"
log () {
    echo "$(date) [$self] $1" | tee -a "$LOGFILE"
}

log "starting up (at pid $$)"

disk_drive=$DLROOT
disk_limit=90

percent_disk_usage () {
    df "$1" | sed -n "s/.*[^0-9]\([0-9][0-9]*\)%.*/\1/p"
}

disk_usage=$(percent_disk_usage $disk_drive)
log "storage in use: $disk_usage% of $disk_drive"

if [ $disk_usage -gt $disk_limit ]; then
    log "disk usage = $disk_usage% > $disk_limit% = limit -> not launching"
    exit 0
fi

grep_pid () {
    ps | grep "^ *$1 "
}

still_running () {
    grep_pid $1 | grep -q "podcatch.sh"
}

kill_stale () {
    kill $1
    killall wget
    sleep 3
    if still_running $1; then
        log "killing $1 failed: retrying -9"
        kill -9 $1
        sleep 1
    else
        log "killed: $1"
    fi
    killall -9 wget
    sleep 1
    # for the case we killed a stalled download,
    # we continue this time (full fetch next time)
    rm -f "$WATCHLIST"
    PODCATCH="$PODCATCH -np all"
}

if pids=$(pidof podcatch.sh grabfeed.sh smartdl.sh); then
    log "found running pids: $pids"
    touch "$WATCHLIST"
    if [ x"pids" = x"$(cat "$WATCHLIST")" ]; then
        for pid in $pids; do
            kill_stale $pid
        done
    else
        echo "$pids" > "$WATCHLIST"
    fi
fi

if [ -n "$(pidof podcatch.sh grabfeed.sh smartdl.sh)" ]; then
    log "something is still running -> just archiving"
    "$ARCHIVER"
else
    log "launching: $PODCATCH && $ARCHIVER &"
    $PODCATCH || true && "$ARCHIVER" &
fi
