#!/bin/bash

. $(dirname $0)/../common_benchmark.sh

FILES=($BMDIR/*.pdf)

benchmark_help $1 <<EOF
Usage: $(basename $0) [PDF files...]"

PDF files  - One or more PDF files
             Default: All PDF files in the benchmark directory
EOF

OUT_FILE=/tmp/bench-result.pdf

if [ $# -ne 0 ]; then
  FILES=("$@");
fi

hpopt="ruby -I${BMDIR}/../../lib ${BMDIR}/../../bin/hexapdf -f optimize "
bench_header
for file in "${FILES[@]}"; do
  file_name=$(basename $file)
  bench_cmd "hexapdf     | $file_name" $hpopt "${file}" --no-compact --object-streams=preserve --xref-streams=preserve --streams=preserve --no-optimize-fonts ${OUT_FILE}
  bench_cmd "hexapdf C   | $file_name" $hpopt "${file}" --compact --object-streams=preserve --xref-streams=preserve --streams=preserve --no-optimize-fonts ${OUT_FILE}
  bench_cmd "hexapdf CS  | $file_name" $hpopt "${file}" ${OUT_FILE}
  bench_cmd "hexapdf CSP | $file_name" $hpopt "${file}" --compress-pages ${OUT_FILE}
  bench_cmd "origami     | $file_name" ruby $BMDIR/origami.rb "${file}" ${OUT_FILE}
  bench_cmd "combinepdf  | $file_name" ruby $BMDIR/combine_pdf.rb "${file}" ${OUT_FILE}
  bench_cmd "pdftk C?    | $file_name" pdftk "${file}" output ${OUT_FILE}
  bench_cmd "qpdf C      | $file_name" qpdf "${file}" ${OUT_FILE}
  bench_cmd "qpdf CS     | $file_name" qpdf "${file}" --object-streams=generate ${OUT_FILE}
  bench_cmd "smpdf CSP   | $file_name" smpdf "${file}" -o ${OUT_FILE}
  bench_separator
done
