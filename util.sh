#!/bin/bash

timed_quiet() {
    echo -n "$1...    "
    shift
    local START=$(date +%s.%N)
    $* 2>/dev/null >/dev/null
    local END=$(date +%s.%N)
    echo `echo $END - $START | bc` s
}

timed_set() {
    echo -n "$1...    "
    shift
    local OUTVAR=$1
    shift
    local START=$(date +%s.%N)
    export $OUTVAR="$($*)"
    local END=$(date +%s.%N)
    echo `echo $END - $START | bc` s
}

url_from_multiaddr() {
    host=$(echo "$1" | cut -d/ -f3)
    port=$(echo "$1" | cut -d/ -f5)
    protocol=$(echo $1 | cut -d/ -f6)
    echo -n $protocol://$host:$port
}
