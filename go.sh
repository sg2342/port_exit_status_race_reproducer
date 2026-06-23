#!/bin/sh

: "${ERL_AFLAGS:="+S 2:2 +SDcpu 1:1 -noshell -noinput"}"
export ERL_AFLAGS

if [ "$1" -gt 1 ] 2>/dev/null; then
    Workers="$1"
else
    Workers=100
fi

if [ "$2" -gt 1 ] 2>/dev/null; then
    Iterations="$2"
else
    Iterations=10000
fi


uname -a
erl +V
printf 'ERL_AFLAGS="%s"\n\n' "$ERL_AFLAGS"

erlc reproducer.erl

export ABORT_ON_RACE_HIT=1
erl -eval "reproducer:doit($Workers, $Iterations)." -eval "init:stop()."
