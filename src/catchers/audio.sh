#!/bin/sh

grep -io 'http://[^ ]*\.\(mp3\|ogg\)' "$1"
