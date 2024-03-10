# # PDF/A Compliance
#
# This example shows how to create a PDF file that is PDF/A compliant.
#
# In this case we are creating a simple invoice, with multiple line
# items that break across the page boundary.
#
# Usage:
# : `ruby pdfa.rb`
#
require 'hexapdf'

HexaPDF::Composer.create('pdfa.pdf') do |composer|
  composer.document.task(:pdfa)
  composer.document.config['font.map'] = {
    'Lato' => {
      none: '/usr/share/fonts/truetype/lato/Lato-Regular.ttf',
      bold: '/usr/share/fonts/truetype/lato/Lato-Bold.ttf',
      italic: '/usr/share/fonts/truetype/lato/Lato-Italic.ttf',
      bold_italic: '/usr/share/fonts/truetype/lato/Lato-BoldItalic.ttf',
    },
  }

  company = {
    name: 'Sample Corp Limited',
    address: ["Example Avenue 1", "12345 Runway"],
  }

  # Define all styles
  composer.style(:base, font: 'Lato', font_size: 10, line_spacing: 1.3)
  composer.style(:top, font_size: 8)
  composer.style(:top_box, padding: [100, 0, 0], margin: [0, 0, 10], border: {width: [0, 0, 1]})
  composer.style(:header, font: ['Lato', variant: :bold], font_size: 20, margin: [50, 0, 20])
  composer.style(:line_items, border: {width: 1, color: "eee"}, margin: [20, 0])
  composer.style(:line_item_cell, font_size: 8)
  composer.style(:footer, border: {width: [1, 0, 0], color: "darkgrey"},
                 padding: [5, 0, 0], valign: :bottom)
  composer.style(:footer_heading, font: ['Lato', variant: :bold],
                 font_size: 8, padding: [0, 0, 8])
  composer.style(:footer_text,  font_size: 8, fill_color: "darkgrey")

  # Top part
  composer.box(:container, style: :top_box) do |container|
    container.formatted_text([{text: company[:name], font: ['Lato', variant: :bold]},
                              " - " + company[:address].join(' - ')], style: :top)
  end
  composer.text("Mega Client\nSmall Lane 5\n67890 Noonestown", mask_mode: :box)
  cells = [["Invoice number:", "2024/01"],
           ["Invoice date", "2024-03-10"],
           ["Service date:", "2024-02-01"]]
  composer.table(cells, column_widths: [150, 80], style: {align: :right}) do |args|
    args[] = {cell: {border: {width: 0}, padding: 2}, text_align: :right}
    args[0..-1, 0] = {font: ['Lato', variant: :bold]}
  end

  # Middle part
  composer.text("Invoice - 2024/01", style: :header)
  composer.text("Thank you for your order. Following are the items you purchased:")

  cells = [["Description", "Price", "Amount", "Total"]]
  max = 40
  1.upto(max) do |index|
    cells << ["Sample Item E.g. #{index}", "€ 250,00", index, "€ #{250 * index},00"]
  end
  cells << [nil, nil, nil, "€ #{250 * max * (max + 1) / 2},00"]
  composer.table(cells, column_widths: [250, 80], style: :line_items) do |args|
    args[] = {cell: {border: {width: 0}, padding: 8}, style: :line_item_cell}
    args[0] = {cell: {background_color: "eee"}, font: ["Lato", variant: :bold]}
    args[-1] = {cell: {background_color: "eee", border: {width: [2, 0, 0]}},
                font: ["Lato", variant: :bold]}
    args[0..-1, 1..-1] = {text_align: :right}
  end

  composer.text("Please transfer the total amount via SEPA transfer to the bank " \
                "account below immediately after receiving the invoice - thank you.")

  # Bottom part
  l = composer.document.layout
  cells = [
    [l.text(company[:name], style: :footer_heading),
     l.text(company[:address].join("\n"), style: :footer_text)],
    [l.text('Contact', style: :footer_heading),
     l.text("owner@samplecorp.com\nOwner: Me, Myself, And I", style: :footer_text)],
    [l.text('Bank Account', style: :footer_heading),
     l.text("Sample Corp Bank\nIBAN: SC01 2345 6789 0123 4567\nBIC: SACOZZB123",
            style: :footer_text)],
  ]
  composer.table([cells], cell_style: {border: {width: 0}}, style: :footer)
end
