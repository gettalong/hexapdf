#!/bin/bash

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 rubies bench_dir [bench_opts...]"
  exit 1
fi

RUBY_VERSIONS=$1
BENCH_DIR=$(echo $2 | tr -d '/')
shift 2

cd $BENCH_DIR &>/dev/null

FILTER_SCRIPT='
case $_
when /^Using ruby ([\d.]+)(?:.*?([MY]JIT)|)/ then cur_ruby = $1 + ($2 ? "-#{$2.downcase}" : "");
when /^\| (?:ERR )?hexapdf(?:\s+([^\s|]+)|)/ then
  special = $1
  puts $_.sub(/hexapdf( \w+)?/, "hexapdf #{cur_ruby}").sub(/^(\|.*?\|)/, "\\1 #{special}")
else puts $_
end
$stdout.flush
'

eval "$(rbenv init -)"
for RUBY_VERSION in $RUBY_VERSIONS; do
  if [[ ${RUBY_VERSION: -1} = y ]]; then
    rbenv shell ${RUBY_VERSION%y}
    export RUBYOPT=--yjit
  elif [[ ${RUBY_VERSION: -1} = m ]]; then
    rbenv shell ${RUBY_VERSION%m}
    export RUBYOPT=--mjit
  else
    rbenv shell $RUBY_VERSION
    unset RUBYOPT
  fi

  echo "Using $(ruby -v)"
  ./script.sh "${@}"
done | ruby -n -e "${FILTER_SCRIPT}" |
    tee >(ruby ../generate_plot_data.rb > /tmp/plot_${BENCH_DIR}.data 2>/dev/null)

gnuplot -p plot.cfg 2>/dev/null
