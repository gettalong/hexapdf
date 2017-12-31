use strict;
use warnings;

use PDF::API2;

my $pdf = PDF::API2->new(-file => $ARGV[1]);
$pdf->mediabox('A4');

my $top_margin = 842 - 72 - 0.5 * 72;
my $bottom_margin = 72 + 0.5 * 72;
my $font;

if ($ARGV[2]) {
  $font = $pdf->ttfont($ARGV[2]);
} else {
  $font = $pdf->corefont('Times-Roman');
}
my $y = 0;
my $page;
my $content;

open my $file, $ARGV[0];
while (my $line = <$file>) {
  chomp $line;
  if ($y < $bottom_margin) {
    $page = $pdf->page();
    $content = $page->text();
    $content->font($font, 12);
    $content->lead(14);
    $content->distance(72, $top_margin);
    $y = $top_margin;
  }
  $content->text($line);
  $content->cr();
  $y = $y - 14;
}

$pdf->save();
