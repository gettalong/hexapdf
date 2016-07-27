# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/font_loader'
require 'hexapdf/document'

describe HexaPDF::FontLoader::Standard14 do
  before do
    @doc = HexaPDF::Document.new
  end

  it "loads the font if it is a standard PDF built-in font" do
    wrapper = @doc.fonts.load("Times")
    assert_equal("Times-Roman", wrapper.wrapped_font.font_name)
    wrapper = @doc.fonts.load("Helvetica", variant: :bold)
    assert_equal("Helvetica-Bold", wrapper.wrapped_font.font_name)
  end

  it "returns nil for unknown fonts" do
    assert_nil(HexaPDF::FontLoader::Standard14.call(@doc, "Unknown"))
  end
end
