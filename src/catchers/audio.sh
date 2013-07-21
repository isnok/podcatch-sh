#!/bin/sh

grep -io 'http://[^ "<]*\.\(mp3\|ogg\|flac\|wav\|au\|la\|pac\|wma\|aiff\|m4a\|m4b\|m4p\)' "$1"
