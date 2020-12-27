#!/bin/sh

BMDIR=$(readlink -e $(dirname $0))
declare -a USED_BENCH_CMDS

trap exit 2

function bench_separator() {
  echo "|--------------------------------------------------------------------|"
}

function bench_header() {
  bench_separator
  printf "| %-28s ||    Time |     Memory |   File size |\n" "$*"
  bench_separator
}

function bench_allowed_cmd() {
  local entry cmdname="$(echo $1 | cut -d\| -f1 | xargs echo)"
  if [ ${#USED_BENCH_CMDS[@]} -eq 0 ]; then return 0; fi
  for entry in "${USED_BENCH_CMDS[@]}"; do
    [[ "$cmdname" =~ "$entry" ]] && return 0;
  done
  return 1
}

function bench_cmd() {
  local FORMAT cmdname="$1" time=$(date +%s%N)
  FORMAT="| %-28s | %'6ims | %'7iKiB | %'11i |\n"
  shift

  if ! bench_allowed_cmd "$cmdname"; then return; fi

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

function bench_parse_opts() {
  local OPTIND BMOPT

  while getopts hb: BMOPT; do
    case $BMOPT in
      b)
        USED_BENCH_CMDS+=("$OPTARG")
        ;;
      h)
        cat
        exit 0
        ;;
      \?)
        echo
        $0 -h
        exit 1
        ;;
    esac
  done
  shift "$((OPTIND - 1))"
  BENCH_ARGS=("$@")
}

function bench_help() {
  cat <<EOF
Usage: $(basename $0) [OPTIONS] $1"

OPTIONS
  -b NAME    If specified, restricts the benchmark to the command
             NAME. May be specified multiple times.
  -h         Shows the help.
EOF
}
