#!/bin/sh

grep -io 'http://[^ <"]*' "$1"
