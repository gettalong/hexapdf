#!/usr/bin/env php

<?php

require_once('tcpdf/tcpdf.php');

$pdf = new TCPDF('P', 'pt', 'A4', true, 'UTF-8', false);
$pdf->SetMargins(72, 72 + 0.5 * 36, 0);
$pdf->SetPrintHeader(false);
$pdf->SetPrintFooter(false);

$pdf->SetAutoPageBreak(TRUE, 72 + 0.5 * 36);

if ($argc == 4) {
  //Activate the following line, then run as root once to generate the needed files
  //$font_name = TCPDF_FONTS::addTTFfont($argv[3], '', '', 32);
  $font_name = 'dejavusans';
} else {
  $font_name = 'times';
}
$pdf->setFontSubsetting(true);
$pdf->SetFont($font_name, '', 12, '', true);
$pdf->AddPage();
$pdf->setCellHeightRatio(1.2);

$handle = fopen($argv[1], 'r');
while (($line = fgets($handle)) !== false) {
  $pdf->Cell(0, 0, $line, 0, 1, 'L', false, '', 0, false, 'T', 'T');
}
fclose($handle);

if (substr($argv[2], 0, 1) !== '/') {
  $file = __DIR__ . '/' . $argv[2];
} else {
  $file = $argv[2];
}

$pdf->Output($file, 'F');
