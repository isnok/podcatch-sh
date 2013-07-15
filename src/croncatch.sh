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
IFS=
PATH=/bin
set -e

#
# prepare environment / configure podcatch
#
# cast list directory
export LISTDIR=/mnt/brueckencache/podcatch/cfg
# the default download destination
export DLROOT=/mnt/brueckencache/incoming/podcasts
# archive values
export INCOMING=/mnt/brueckencache/incoming
export ARCHIVE=/mnt/brueckencache/archive
#
# the other scripts
SRCDIR=/mnt/brueckencache/podcatch/src
ARCHIVER=$SRCDIR/archive.sh
PODCATCH=$SRCDIR/podcatch.sh
export FEEDER=$SRCDIR/grabfeed.sh
export PARSERSHS=$SRCDIR/catchers
export SMARTDL=$SRCDIR/smartdl.sh
export DONESCRIPT=$SRCDIR/done.sh
#
# the location to where logs are written
export LOGDIR=/mnt/brueckencache/podcatch
#
# logfile, list of newly downloaded files and error log
export LOGFILE=$LOGDIR/podcatch.log
export FETCH_LOG=$LOGDIR/podcatch-fetched.m3u
export ERROR_LOG=$LOGDIR/podcatch-errors.log
#
# initial values for behaviour control options (see $FEEDER)
export initignoring=false
export fetchfeed=true
export parsefeed=true
export downloadepisodes=true

WATCHLIST=/tmp/croncatch.watch

log () {
    echo "$(date) [cron] $1" >> $LOGFILE
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
    rm -f $WATCHLIST
    PODCATCH="$PODCATCH -np all"
}

if pids=$(pidof podcatch.sh grabfeed.sh smartdl.sh); then
    log "found running pids: $pids"
    touch $WATCHLIST
    if [ x"pids" = x"$(cat $WATCHLIST)" ]; then
        for pid in $pids; do
            kill_stale $pid
        done
    else
        echo "$pids" > $WATCHLIST
    fi
fi

if [ -n "$(pidof podcatch.sh grabfeed.sh smartdl.sh)" ]; then
    log "something is still running -> just archiving"
    $ARCHIVER
else
    log "launching: $PODCATCH && $ARCHIVER &"
    $PODCATCH || true && $ARCHIVER &
fi
