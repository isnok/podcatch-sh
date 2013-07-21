#!/bin/sh

grep -io 'http://[^ "<]*\.\(aaf\|3gp\|3g2\|asx\|vob\|gif\|asf\|flv\|mkv\|mpe\|rm\|ogv\|xvid\|mp4\|avi\|mpg\|mpeg\|wmv\|m4v\|swf\|mov\|divx\)' "$1"
