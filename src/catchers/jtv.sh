# jtv.sh - a more complex catcher for new jtv features

PAGES=$(grep -io "http://juggling.tv/[1-9][0-9]*" "$1")
wget -O- $PAGES | grep -io "http://juggling.tv/download/original/[^ \"<]*\.\(mp4\|avi\|mov\)"
