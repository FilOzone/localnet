#!/bin/bash

timed_quiet() {
    echo -n "$1...    "
    shift
    local START=$(date +%s.%N)
    $* >/dev/null
    local END=$(date +%s.%N)
    echo `echo $END - $START | bc`s
}

timed_set() {
    echo -n "$1...    "
    shift
    local OUTVAR=$1
    shift
    local START=$(date +%s.%N)
    export $OUTVAR="$($*)"
    local END=$(date +%s.%N)
    echo `echo $END - $START | bc`s
}
