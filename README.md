podcatch-sh
===========

A pure posix shell script podcatcher/auto-downloader suite designed for minimal dependencies.

podcatch-sh consists of a set of shell scripts to automate the following processes:

 - newcast.sh: a helper script to find the right parser for your new cast (plus config validation).
 - podcatch.sh: downloads feeds, parses them for episodes and fetches new ones, if there are any.
 - croncatch.sh: a wrapper script for podcatch.sh, that checks for running instances etc before launching.
 - smartdl.sh: a 'smart' downloader for youtube/torrent support (featuring link type autodetection).
 - done.sh: callback-script for parallel/background fetching via smartdl.sh.
 - archive.sh: some simple but effective hard-linking magic (to be extended when the others work fine).

All scripts do minimally require only the set of busybox built-ins, that come with OpenWRT by default.
Lastly ctorrent and youtube-dl have been introduced as optional download helpers, enabling a whole new
range of possibilities on what this script collection can be used for.

Development is ongoing, so check again soon if you are interested!

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
        -kt|--keep-temp     keep the temp directory (for debugging mainly)
        -h|--help           print this help

    Note that if you use one of these, you should also specify a castlist.

    Argument combos that drove development:

        podcatch.sh -ne all  # fetch-and-parse-only on all feeds (almost-dry-run, inits new casts)
        podcatch.sh -np all  # continue all without re-fetching and re-parsing
        podcatch.sh -nf -ne jtv  # re-parse the previously fetched feeds from $LISTDIR/jtv.lst
        podcatch.sh -if cczwei -ne chaos -h -da casts # you get the idea...

Tested and developed to run on: OpenWrt 12.09 (BusyBox v1.19.4)
