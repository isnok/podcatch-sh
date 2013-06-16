podcatch-sh
===========

A pure posix shell script podcatcher / rss-reader(-simulation) / feedgrabber / auto-downloader suite.

Help text of podcatch.sh:
    podcatch.sh - a shell scripted podcatcher for openwrt devices

    usage: podcatch.sh [args/castlists]

    The arguments are processed in the order they are given.
    All arguments not listed below are treated as castlists.
    The castlists directory is configured in podcatch.sh itself.
    'all' a is a special castlist, instructing to fetch all castlists.
    'all' is the default behaviour if no args are given.

    To change behaviour of podcatch.sh use:

        -ne|--no-episodes   don't download episodes
        -nf|--no-feeds      don't download feeds (reuse last fetched version)
        -np|--no-parse      reuse last parsed feed (implies -nf)
        -da|--download-all  reset all -n options (default)
        -if|--init-fetched  if a new feed is found, initialize it's episodes as fetched
        -iw|--init-wanted   if a new feed is found, download all of it's episodes (default)
        -h|--help           print this help

    Note that if you use one of these, you should also specify a castlist.

    Argument combos that drove development:

        podcatch.sh -ne all  # fetch-and-parse-only on all feeds (almost-dry-run, inits new casts)
        podcatch.sh -np all  # continue all without re-fetching and re-parsing
        podcatch.sh -nf -ne jtv  # re-parse the previously fetched feeds from $LISTDIR/jtv.lst
        podcatch.sh -if cczwei -ne chaos -h -da casts # you get the idea...

Tested on and developed to work on: OpenWrt 12.09 (BusyBox v1.19.4)
