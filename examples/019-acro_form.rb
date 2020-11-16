# # PDF Forms
#
# PDF files can be used for interactive forms, containing various types of form
# fields. HexaPDF supports the creation and processing of these forms.
#
# This example show-cases how to create the various form field types and their
# possible standard appearances.
#
# Usage:
# : `ruby acro_form.rb`
#

require 'hexapdf'

doc = HexaPDF::Document.new
page = doc.pages.add
canvas = page.canvas

canvas.font("Helvetica", size: 36)
canvas.text("Form Example", at: [50, 750])
form = doc.acro_form(create: true)

canvas.font_size(16)
canvas.text("Check boxes", at: [50, 650])
[:check, :circle, :cross, :diamond, :square, :star].each_with_index do |symbol, index|
  cb = form.create_check_box("Checkbox #{index}")
  widget = cb.create_widget(page, Rect: [200 + 50 * index, 640, 240 + 50 * index, 680])
  widget.background_color(1 - 0.05 * index)
  widget.marker_style(style: symbol, color: [0.166 * index, 0, 1 - 0.166 * index],
                      size: 7 * index)
  cb.field_value = true
end

canvas.text("Radio buttons", at: [50, 550])
rb = form.create_radio_button("Radio")
[:check, :circle, :cross, :diamond, :square, :star].each_with_index do |symbol, index|
  widget = rb.create_widget(page, value: :"button#{index}",
                            Rect: [200 + 50 * index, 540, 240 + 50 * index, 580])
  widget.background_color(1 - 0.05 * index)
  widget.marker_style(style: symbol, color: [0.166 * index, 0, 1 - 0.166 * index],
                      size: 7 * index)
end
rb.field_value = :button0

canvas.text("Text fields", at: [50, 450])

canvas.text("Single line", at: [70, 420])
tx = form.create_text_field("Single Line")
widget = tx.create_widget(page, Rect: [200, 415, 500, 435])
tx.set_default_appearance_string(font_size: 16)
tx.field_value = "A sample test string!"

canvas.text("Comb", at: [70, 390])
tx = form.create_comb_text_field("Comb field", 10)
widget = tx.create_widget(page, Rect: [200, 370, 500, 405])
widget.border_style(color: [30, 128, 0], width: 1)
tx.set_default_appearance_string(font_size: 16)
tx.text_alignment(:center)
tx.field_value = 'Hello'

doc.write('acro_form.pdf', optimize: true)
