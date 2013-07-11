#!/bin/sh
#
# archive.sh - a convenience feature for podcatching via shell
#
# logging is disabled/defunct because busybox' cp doesn't implement -v

INCOMING=/mnt/brueckencache/incoming
ARCHIVE=/mnt/brueckencache/archive
#LOGFILE=/mnt/brueckencache/podcatch/archive.log

archive () {
    echo "$(date) [archive] starting"
    cp -rl $INCOMING/* $ARCHIVE
    #cp -rlv $INCOMING/* $ARCHIVE &> $LOGFILE.tmp
    #grep -v "^cp: '.*' and '.*' are the same file$" $LOGFILE.tmp
    echo "$(date) [archive] finished"
}

mkdir -p $ARCHIVE
archive # &> $LOGFILE.new
#cat $LOGFILE.new >> $LOGFILE
#rm $LOGFILE.tmp $LOGFILE.new
