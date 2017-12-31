#!/bin/sh

BMDIR=$(readlink -e $(dirname $0))

trap exit 2

function bench_separator() {
  echo "|--------------------------------------------------------------------|"
}

function bench_header() {
  bench_separator
  printf "| %-28s ||    Time |     Memory |   File size |\n" "$*"
  bench_separator
}

function bench_cmd() {
  cmdname=$1
  FORMAT="| %-28s | %'6ims | %'7iKiB | %'11i |\n"
  shift

  time=$(date +%s%N)
  /usr/bin/time -f '%M' -o /tmp/bench-times "$@" &>/dev/null
  if [ $? -ne 0 ]; then
    cmdname="ERR ${cmdname}"
    time=0
    mem_usage=0
    file_size=0
  else
    time=$(( ($(date +%s%N)-time)/1000000 ))
    mem_usage=$(cat /tmp/bench-times)
    file_size=$(stat -c '%s' $OUT_FILE)
  fi
  printf "$FORMAT" "$cmdname" "$time" "$mem_usage" "$file_size"
}

function benchmark_help() {
  if [[ "$1" = '-h' ]]; then
    cat
    exit 0
  fi
}
