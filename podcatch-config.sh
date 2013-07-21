#!/bin/sh
#
# podcatch-config.sh - a per-user config file for the podcatch.sh suite
#

# where log information goes:
: ${LOGFILE:="/tmp/podcatch.log"}

# fetched files are appended to:
: ${FETCH_LOG:="/dev/null"}

# fetched links are appended to:
: ${LINKS_DOWNED:="podcatch-dontfetch.txt"}

# failed links are appended to:
: ${LINKS_FAILED:="/dev/null"}

# a secondary channel for errors:
: ${ERROR_LOG:="/dev/null"}

# local directories:
: ${SCRIPTDIR:="$PWD/src"}
: ${LISTDIR:="$PWD/cfg"}
: ${DLROOT:="/tmp/configured_incoming"}

# hard-code default options
#downloadepisodes=false
