#!/bin/bash

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 bench_dir [bench_opts...]"
  exit 1
fi

cd $1
shift

./script.sh "$@" | tee >(ruby ../generate_plot_data.rb > /tmp/plot.data 2>/dev/null)
gnuplot -p plot.cfg 2>/dev/null
