#!/bin/bash

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 bench_dir [bench_opts...]"
  exit 1
fi

BENCH_DIR=$(echo $1 | tr -d '/')

cd $BENCH_DIR &>/dev/null
shift

./script.sh "$@" | tee >(ruby ../generate_plot_data.rb ${BENCH_DIR} > /tmp/plot_${BENCH_DIR}.data 2>/dev/null)
gnuplot -p plot.cfg 2>/dev/null
