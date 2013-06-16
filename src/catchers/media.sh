#!/bin/sh

grep -io 'http://[^ ]*\.\(mp3\|mp4\|avi\|mpg\|mpeg\|wmv\|ogg\)' "$1"
