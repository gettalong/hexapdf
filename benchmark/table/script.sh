#!/bin/bash

. $(dirname $0)/../common_benchmark.sh

ROWS=(10 100 1000 10000)

bench_parse_opts "$@" <<EOF
$(bench_help "[rows]")

rows     - A space separated string of row numbers
           Default: "${ROWS[@]}"
EOF
set -- "${BENCH_ARGS[@]}"

OUT_FILE=/tmp/bench-result.pdf
IMAGE=$(readlink -e $BMDIR/../../examples/machupicchu.jpg)

if [[ $# -ge 1 ]]; then
  ROWS=($1)
  shift
fi

bench_header
for row in "${ROWS[@]}"; do
    bench_cmd "hexapdf   | ${row}" ruby $BMDIR/hexapdf.rb $row $IMAGE ${OUT_FILE}
    bench_cmd "prawn     | ${row}" ruby $BMDIR/prawn.rb $row $IMAGE ${OUT_FILE}
    bench_cmd "reportlab | ${row}" python3 $BMDIR/rlcli.py $row $IMAGE ${OUT_FILE}
    bench_cmd "fpdf2     | ${row}" python3 $BMDIR/fpdf2.py $row $IMAGE ${OUT_FILE}
    bench_separator
done
