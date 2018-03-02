/* The jPDFWriter library from Qoppa Software is needed.
 * See https://www.qoppa.com/pdfwriter */
import java.awt.Graphics2D;
import java.awt.print.PageFormat;
import java.awt.print.Paper;
import java.util.stream.Stream;
import java.nio.file.Files;
import java.nio.file.Paths;

import com.qoppa.pdfWriter.PDFDocument;
import com.qoppa.pdfWriter.PDFGraphics;
import com.qoppa.pdfWriter.PDFPage;

public class JPDFWriter
{
  public static void main (String [] args)
  {
    try
    {
      float bottom_margin = 842 - 72 - 0.5f * 72;
      float top_margin = 72 + 0.5f * 72;
      float y = 842;

      if (args.length == 3) {
        throw new Exception("No TrueType support");
      }

      PDFDocument pdf = new PDFDocument();
      PageFormat format = createPageFormat();
      try (Stream<String> lines = Files.lines(Paths.get(args[0]))) {
        PDFPage page = pdf.createPage(format);
        Graphics2D canvas = page.createGraphics();

        for (String line : (Iterable<String>) lines::iterator) {
          if (y > bottom_margin) {
            if (y != 842) {
              pdf.addPage(page);
            }
            page = pdf.createPage(format);
            canvas = page.createGraphics();
            canvas.setFont(PDFGraphics.TIMESROMAN.deriveFont(12f));
            y = top_margin;
          }
          if (!line.isEmpty()) {
            canvas.drawString(line, 72, y);
          }
          y += 14;
        }
        pdf.addPage(page);
      }
      pdf.saveDocument(args[1]);
    }
    catch (Throwable t)
    {
        t.printStackTrace();
        System.exit(1);
    }
  }

  private static PageFormat createPageFormat() {
    Paper paper = new Paper();
    paper.setSize(596, 842);
    paper.setImageableArea(0, 0, 596, 842);
    PageFormat format = new PageFormat();
    format.setPaper(paper);
    return format;
  }

}
