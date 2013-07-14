#!/bin/sh

grep -io 'http://[^ ]*\.\(pdf\|txt\|rtf\|ps\|doc\|docx\)' "$1"
