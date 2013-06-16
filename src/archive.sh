#!/bin/sh
#
# archive.sh - a convenience feature for podcatching via shell
#

INCOMING=/mnt/slugspace/incoming
ARCHIVE=/mnt/slugspace/archive
LOGFILE=/mnt/slugspace/podcatch/archive.log

archive () {
    echo "$(date) [archive] starting"
    cp -rlv $INCOMING/* $ARCHIVE &> $LOGFILE.tmp
    grep -v "^cp: '.*' and '.*' are the same file$" $LOGFILE.tmp
    echo "$(date) [archive] finished"
}

archive &> $LOGFILE.new
cat $LOGFILE.new >> $LOGFILE
rm $LOGFILE.tmp $LOGFILE.new
