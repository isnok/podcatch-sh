#!/bin/sh

PAGES="$(grep -o "http://[^ <\"]*" "$1" | grep -v "comics=[0-9]*/$")"
wget -O- $PAGES | grep -io "http://[^ ]*\.\(png\|jpg\|jpeg\|gif\|tif\|tiff\|bmp\|svg\|ico\)"
