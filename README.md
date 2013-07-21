podcatch-sh
===========

A pure posix shell script podcatcher/auto-downloader suite designed for minimal dependencies.

podcatch-sh consists of a set of shell scripts to automate the following processes:

 - newcast.sh: a helper script to find the right parsers for your new cast (soon: config validation).
 - podcatch.sh: parses it's configured cast lists and grabs or initializes casts as configured.
 - grabfeed.sh: parses a downloaded feed, calculates new downloads and downloads them (if not disabled).
 - croncatch.sh: a wrapper script for podcatch.sh, that checks for running instances etc before launching.
 - smartdl.sh: a 'smart' downloader that enables youtube/torrent support (via autodetection).
 - done.sh: callback-script for parallel/background fetching via smartdl.sh (not really intercative).
 - archive.sh: simple but effective hard-link magic incoming directory in which files can be deleted.

All scripts do minimally require only the set of busybox built-ins, that come with OpenWRT by default.
ctorrent and youtube-dl have been introduced as optional download helpers, expanding it's usefulness.

Development is ongoing, and at the moment there are some known bugs (log messages getting duplicated)
and probably even more unknown bugs, so check again or give feedback if you are interested in using
these scripts!


Help text of the podcast list downloader script:

    podcatch.sh - a shell scripted podcatcher for openwrt devices

    usage: podcatch.sh [args/castlists]

    The arguments are processed in the order they are given.
    All oter arguments not listed below are treated as castlists.
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


Help text of the script use to download each podcast:

    grabfeed.sh - a shell scripted feed grabber

    usage: grabfeed.sh [feed] [destination] [parser(s)]

        grab one (probably not initialized) feed
        to a destination directory using parser(s)

        no args yield this usage text.

... and finally the help of the script used to download single episodes:

    smartdl.sh - a link type aware downloader script

    usage: smartdl.sh [uri]

        will detect the type of uri and take action accordingly.
        by default this will be to download to the current directory,
        but if the tools are at hand and enabled, they will be used.

        default-downloader: wget
        torrent-downloader: ctorrent
        youtube-downloader: youtube-dl

        done script: src/done.sh

        invoking smartdl.sh without any args will bring up this info text.


Tested and developed to run on: OpenWrt 12.09 (BusyBox v1.19.4)
