#!/bin/sh

grep -io 'http://[^ "<]*\.\(zip\|gz\|bz2\|rar\|tar\|tgz\|tbz\|zoo\|ace\|lzma\|7z\)' "$1"
