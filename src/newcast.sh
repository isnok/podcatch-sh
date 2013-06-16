#!/bin/sh
#
# newcast.sh - a helper to find/develop the right catcher for your cast.
#

PLUGDIR=$(dirname $0)/catchers # the catcher scripts

# create a directory for temporary files
TMPDIR=$(mktemp -dt castget-new-XXXXXX)

# remove previous ones, to ease tab-completion? tried it... sux
#echo "==> cleanup"
#rm -rvf $(ls -d $(dirname $TMPDIR)/castget-new-* | grep -v $TMPDIR)

# might not be needed here:
#alias log='echo'

run_parsers () {
    ls $PLUGDIR/*.sh | while read parser_script; do
        parser=$(basename $parser_script)
        parser="${parser%%.sh}"
        echo $parser
        tmp_parsed="$TMPDIR/$parser.parsed"
        $SHELL "$PLUGDIR/$parser.sh" "$1" > "$tmp_parsed"
    done
}

cnt_parsers () {
    for parser in $1; do
        tmp="$TMPDIR/$parser.parsed"
        echo
        echo "==> $parser: $(wc -l $tmp)"
        if [ -s $tmp ]; then
            echo "--> $2 ---$parser--> download_dir"
            head -n2 $tmp
            echo "..."
            tail -n2 $tmp
        fi
    done
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
}

new_cast () {
    #echo "==> Available parsers:" $PLUGDIR/*.sh
    feed="$1"
    tmp_feed="$TMPDIR/new.feed"
    wget "$feed" -O "$tmp_feed"
    parsers="$(run_parsers $tmp_feed)"
    cnt_parsers "$parsers" "$feed"
    #calc_catch "$2.parsed" "$4/podcatch.dontfetch" "$2.needfetch"
    #catch_episodes "$2.needfetch" "$4"
}

until [ $# = 0 ]; do
    new_cast "$1"
    shift
done
echo "==> last results stored in $TMPDIR"
