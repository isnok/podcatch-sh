#!/bin/sh
#
# newcast.sh - a helper to find/develop the right catcher for your cast.
#
IFS=
PATH=/bin:/usr/bin
set -e

# the link harvester scripts
: ${PARSERSHS=$(dirname $0)/catchers}
if [ ! x"${PARSERSHS##/}" = x"$PARSERSHS" ]; then
    PARSERSHS="$PWD/$PARSERSHS"
fi

echo "available parsers: " $PARSERSHS/*.sh

TMPDIR=/tmp/newcast.sh

tmp_feed=$TMPDIR/newcast.feed
echo "[cast] $1"
rm -f $tmp_feed
mkdir -p $TMPDIR
wget "$1" -O "$tmp_feed"

ls $PARSERSHS/*.sh | while read full_path; do
    script=$(basename $full_path)
    parser="${script%%.sh}"
    echo
    echo "==> trying parser: $parser" 1>&2
    tmp=$TMPDIR/$parser.parsed
    $SHELL "$PARSERSHS/$parser.sh" "$tmp_feed" > $tmp || continue
    if [ -s $tmp ]; then
        echo "--> $parser results: $(wc -l $tmp)"
        if [ $(cat $tmp | wc -l) -gt 5 ]; then
            head -n2 $tmp
            echo "..."
            tail -n2 $tmp
        else
            cat $tmp
        fi
    fi
done > $TMPDIR/parser-results.txt
shift

echo "==> feed and parsing results were stored in $TMPDIR"
cat $TMPDIR/parser-results.txt

#cnt_parsers () {
    #echo
    #for parser in $1; do
        #echo -n "Give non-zero string to inspect '$parser': "
        #read answer
        #if [ -n "$answer" ]; then
            #more "$TMPDIR/$parser.parsed"
            #echo "==> config line would look somethig like this:"
            #echo "$2 ---$parser--> download_dir"
            ##echo -n "Press Enter to continue."
            ##read waitforenter
        #fi
    #done
#}
