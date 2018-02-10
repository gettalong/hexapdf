const readline = require('readline');
const fs = require('fs');
var PDFDocument = require('pdfkit');

var top_margin = 72 + 0.5 * 72;
var bottom_margin = 842 - 72 - 0.5 * 72;
var margins = {top: 0, bottom: 0, left: 72, right: 72};
var pdf = new PDFDocument({size: 'A4', autoFirstPage: false, margins: margins});
var y = 842;
var font = process.argv[4] || 'Times-Roman';

pdf.pipe(fs.createWriteStream(process.argv[3]));
const rl = readline.createInterface({
  input: fs.createReadStream(process.argv[2])
});

pdf.font(font).fontSize(12).lineGap(2);
rl.on('line', function (line) {
  if (y > bottom_margin) {
    pdf.addPage()
      .font(font)
      .fontSize(12)
      .lineGap(2);
    y = top_margin;
  }

  pdf.text(line, 72, y, {lineBreak: false});
  y += 14;
});

rl.on('close', function () {
  pdf.end();
});
