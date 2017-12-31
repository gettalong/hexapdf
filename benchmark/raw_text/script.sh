#!/bin/bash

. $(dirname $0)/../common_benchmark.sh

KEYS="1x 5x 10x"
TTFS=("" "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf");

benchmark_help $1 <<EOF
Usage: $(basename $0) [multiplier] [font files...]"

multiplier - A space separated string of multiplier values
             Default: "${KEYS}"

font files - One or more TrueType font files
             Default: "" ${TTFS[@]}

If an empty string is used for a font file, the benchmark is run using a
built-in PDF font.
EOF

OUT_FILE=/tmp/bench-result.pdf
IN_FILE=$BMDIR/odyssey.txt
IN_FILE_5X=/tmp/5odyssey.txt
IN_FILE_10X=/tmp/10odyssey.txt

cat {,,,,}$IN_FILE > $IN_FILE_5X
cat $IN_FILE_5X $IN_FILE_5X > $IN_FILE_10X

declare -A input_files
input_files["1x"]=$IN_FILE
input_files["5x"]=$IN_FILE_5X
input_files["10x"]=$IN_FILE_10X

if [[ $# -ge 1 ]]; then
  KEYS="$1"
  shift
fi

if [[ $# -ge 1 ]]; then
  TTFS=("$@")
fi

bench_header
for ttf in "${TTFS[@]}"; do
  for key in $KEYS; do
    file=${input_files[$key]}
    bench_cmd "hexapdf     | ${key} ${ttf: -3}" ruby $BMDIR/hexapdf.rb $file ${OUT_FILE} $ttf
    bench_cmd "prawn       | ${key} ${ttf: -3}" ruby $BMDIR/prawn.rb $file ${OUT_FILE} $ttf
    bench_cmd "reportlab   | ${key} ${ttf: -3}" python $BMDIR/rlcli.py $file ${OUT_FILE} $ttf
    bench_cmd "reportlab/C | ${key} ${ttf: -3}" python3 $BMDIR/rlcli.py $file ${OUT_FILE} $ttf
    bench_cmd "tcpdf       | ${key} ${ttf: -3}" php $BMDIR/tcpdf.php $file ${OUT_FILE} $ttf
    bench_cmd "PDF::API2   | ${key} ${ttf: -3}" perl $BMDIR/pdfapi.pl $file ${OUT_FILE} $ttf
    bench_separator
  done
done
