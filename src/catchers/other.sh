#!/bin/sh

grep -io 'http://[^ ]*\.\(m3u\|pls\|sh\|awk\|pl\|py\|erl\|c\|f90\|f95\)' "$1"
