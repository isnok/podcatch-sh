#!/bin/sh

grep -io 'http://[^ ]*\.\(mp3\|mp4\|avi\|mpg\|mpeg\|wmv\|ogg\|m4a\|m4v\|jpg\|png\|bmp\|wav\|flac\|pdf\|txt\|svg\|aac\|gif\|swf\|rtf\|ps\|zip\|gz\|bz2\|rar\|tar\|jpeg\|mov\|divx\)' "$1"
