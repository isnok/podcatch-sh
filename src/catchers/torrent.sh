#!/bin/sh

grep -io 'http://[^ ]*\.\(torrent\|nfo\)' "$1"
