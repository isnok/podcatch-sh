podcatch-sh
===========

A pure posix shell script podcatcher / rss-reader(-simulation) / feedgrabber / auto-downloader suite.

Help text of podcatch.sh:
    podcatch.sh - a shell scripted podcatcher for openwrt devices

    usage: podcatch.sh [args]

    The args are processed in the order they are given.
    All args not in the list below except 'all' will be treated as castlists.
    The 'all' arg instructs to fetch all castlists. This is the default if no args are given.
    To change behaviour of podcatch.sh use:

        -ne|--no-episodes   don't download episodes
        -nf|--no-feeds      don't download feeds (reuse last fetched version)
        -np|--no-parse      reuse last parsed feed (implies -nf)
        -da|--download-all  reset all -n options (default)
        -if|--init-fetched  if a new feed is found, initialize it's episodes as fetched
        -iw|--init-wanted   if a new feed is found, download all of it's episodes (default)
        -h|--help           print this help

Tested on and developed to work on: OpenWrt 12.09 & BusyBox v1.19.4
