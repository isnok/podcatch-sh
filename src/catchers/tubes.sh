#!/bin/sh

# matches youtube links
grep -io 'http://[^ "<]*\.\(com/.*v[/=][a-zA-Z0-9_-]\{10,12\}\)' "$1"
