#!/bin/sh

grep -io 'http://[^ "<]*\.\(gif\|tif\|tiff\|ico\|eps\|jpg\|png\|bmp\|svg\|jpeg\)' "$1"
