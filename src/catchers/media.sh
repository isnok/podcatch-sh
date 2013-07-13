#!/bin/sh

grep -io 'http://[^ ]*\.\(aaf\|3gp\|3g2\|asx\|vob\|gif\|asf\|flv\|mkv\|mpe\|rm\|ogv\|xvid\|mp3\|mp4\|avi\|mpg\|mpeg\|wma\|m3u\|pls\|wmv\|ogg\|m4a\|m4v\|jpg\|png\|bmp\|wav\|flac\|pdf\|txt\|svg\|aac\|swf\|rtf\|ps\|zip\|gz\|bz2\|rar\|tar\|jpeg\|mov\|divx\|torrent\|com/.*v[/=][a-zA-Z0-9_-]\{10,12\}\)' "$1"
