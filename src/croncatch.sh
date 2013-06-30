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


RUN_DIR=/mnt/brueckencache/podcatch
PODCATCH=src/podcatch.sh
ARCHIVE=$RUN_DIR/src/archive.sh

log () {
    echo "$(date) [cron] $1" >> "$RUN_DIR/podcatch.log"
}
# log or die (test writable and so on...)
log "starting up (at pid $$)" || exit

disk_drive=/mnt/brueckencache/incoming/podcasts
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

mark () {
    ls -rtl "$1" | grep -v croncatch.watch > "$1/croncatch.watch"
}

mark_hasnt_changed () {
    test "$(ls -rtl "$1" | grep -v croncatch.watch)" = "$(cat $1/croncatch.watch)"
}

kill_stale () {
    kill $1
    killall wget
    sleep 1
    if still_running $1; then
        log "killing $1 failed: retrying -9"
        kill -9 $1
        sleep 1
    else
        log "killed: $1"
    fi
    killall -9 wget
    sleep 1
}

tidy_up () {
    if still_running $1; then
        kill_stale $1
        # for the case we killed a stalled download,
        # we continue this time (full fetch next time)
        PODCATCH="$PODCATCH -np all"
    fi
    if [ -d "$2" ]; then
        if rm -r "$2"; then
            log "removed: $2"
        else
            log "removing $2 failed: $?"
        fi
    else
        log "removed by auto-magic: $2"
    fi
}

log "checking tmpdir(s): $RUN_DIR/castget-*"
for dir in $RUN_DIR/castget-*; do
    if [ "$dir" = "$RUN_DIR/castget-*" ]; then
        log "no tempdirs in $RUN_DIR"
        break
    fi
    pid=$(cat $dir/podcatch.pid)
    if [ ! -f "$dir/croncatch.watch" ]; then
        log "mark $dir (pid: $pid)"
        mark "$dir"
    else
        if mark_hasnt_changed "$dir"; then
            log "stale dir: $dir (pid: $pid) -> will tidy up"
            tidy_up "$pid" "$dir"
        else
            log "pid $pid is still alive: new mark $dir"
            mark "$dir"
        fi
    fi
done

if [ -n "$(pidof podcatch.sh)" ]; then
    log "podcatch.sh is still running -> just archiving"
    $ARCHIVE
else
    log "launching: $RUN_DIR $ $PODCATCH || true && $ARCHIVE &"
    cd "$RUN_DIR" && $PODCATCH || true && $ARCHIVE &
fi
