#!/bin/bash

. $(dirname $0)/../common_benchmark.sh

PDFCORPUS=($BMDIR/../../pdf_corpus/*)
OUT_FILE=/tmp/bench-result.pdf
BENCH_FORMAT="| %-28s |     %'6i / %'6i   |\n"
RESULT_FILE=pdfcorpus-results.txt

function test_hexa() {
  local name=$1 pdfdir=$2
  local number_of_files=$(ls $pdfdir | wc -l)

  if ! bench_allowed_cmd hexapdf; then return; fi

  echo $name >> $RESULT_FILE
  count=$(ruby $BMDIR/hexapdf.rb $pdfdir "$RESULT_FILE")
  printf "$BENCH_FORMAT" "$name" "$count" "$number_of_files"
}

function test_files() {
  local name=$1 pdfdir=$2 cmd=$3 count=0
  local number_of_files=$(ls $pdfdir | wc -l)
  local cmdname="$(echo $name | cut -d\| -f1 | xargs echo)"

  if ! bench_allowed_cmd "$cmdname"; then return; fi

  echo $name >> $RESULT_FILE
  for file in $pdfdir/*; do
    $(printf "$cmd" "$file" $OUT_FILE) &>/dev/null
    if [ $? -eq 0 -o $? -eq 3 ]; then
      ((count = count + 1))
    else
      echo $file >> $RESULT_FILE
    fi
  done
  printf "$BENCH_FORMAT" "$name" "$count" "$number_of_files"
}

bench_parse_opts "$@" <<EOF
$(bench_help "[CORPUS_DIR...]")

CORPUS_DIR... - The directories containing the PDF corpus files
EOF
set -- "${BENCH_ARGS[@]}"


if [ $# -ne 0 ]; then
  PDFCORPUS=("$@");
fi

cat >$RESULT_FILE <<<""

printf "|------------------------------------------------------|\n"
printf "|                              ||   Succeeded / Total  |\n"
printf "|------------------------------------------------------|\n"
for dir in "${PDFCORPUS[@]}"; do
  dir_name=$(basename $dir)

  test_hexa "hexapdf     | $dir_name" $dir
  test_files "qpdf        | $dir_name" $dir "qpdf %s %s"
  printf "|------------------------------------------------------|\n"
done
