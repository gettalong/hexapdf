#!/bin/bash

. $(dirname $0)/../common_benchmark.sh

KEYS=(400 200 100 50)
TTFS=("" "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")

benchmark_help $1 <<EOF
Usage: $(basename $0) [widths] [font files...]"

widths     - A space separated string of page widths
             Default: "${KEYS[@]}"

font files - One or more TrueType font files
             Default: "" ${TTFS[@]}

If an empty string is used for a font file, the benchmark is run using a
built-in PDF font.
EOF

OUT_FILE=/tmp/bench-result.pdf
IN_FILE=$(readlink -e $BMDIR/../raw_text/odyssey.txt)

if [[ $# -ge 1 ]]; then
  KEYS=($1)
  shift
fi

if [[ $# -ge 1 ]]; then
  TTFS=("$@")
fi

bench_header
for ttf in "${TTFS[@]}"; do
  for key in "${KEYS[@]}"; do
    bench_cmd "hexapdf   | ${key} ${ttf: -3}" ruby $BMDIR/hexapdf.rb $IN_FILE $key ${OUT_FILE} $ttf
    bench_cmd "prawn     | ${key} ${ttf: -3}" ruby $BMDIR/prawn.rb $IN_FILE $key ${OUT_FILE} $ttf
    bench_cmd "reportlab | ${key} ${ttf: -3}" python $BMDIR/rlcli.py $IN_FILE $key ${OUT_FILE} $ttf
    bench_cmd "tcpdf     | ${key} ${ttf: -3}" php $BMDIR/tcpdf.php $IN_FILE $key ${OUT_FILE} $ttf
    bench_separator
  done
done
