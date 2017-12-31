<?php

require_once('tcpdf/tcpdf.php');

$pdf = new TCPDF('P', 'pt', array($argv[2], 1000), true, 'UTF-8', false);
$pdf->SetMargins(0, 0, 0, 0);
$pdf->SetPrintHeader(false);
$pdf->SetPrintFooter(false);

$pdf->SetAutoPageBreak(TRUE);

if ($argc == 5) {
  //Activate the following line, then run as root once to generate the needed files
  //$font_name = TCPDF_FONTS::addTTFfont($argv[4], '', '', 32);
  $font_name = 'dejavusans';
} else {
  $font_name = 'times';
}
$pdf->setFontSubsetting(true);
$pdf->SetFont($font_name, '', 10, '', true);

$pdf->AddPage();

$pdf->setCellHeightRatio(1.12);
// Using the complete string leads to very long runtimes, splitting the string into
// individual lines and only breaking them is much faster with TCPDF
$utf8text = file_get_contents($argv[1], false);
$pieces = explode("\n", $utf8text);
foreach ($pieces as $text) {
  $pdf->Write(2, $text, '', 0, '', false, 0, false, false, 0);
  $pdf->Ln();
}

if (substr($argv[3], 0, 1) !== '/') {
  $file = __DIR__ . '/' . $argv[3];
} else {
  $file = $argv[3];
}

$pdf->Output($file, 'F');
