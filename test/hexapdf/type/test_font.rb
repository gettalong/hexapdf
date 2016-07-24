# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/type/font'

describe HexaPDF::Type::Font do
  before do
    @doc = HexaPDF::Document.new
    cmap = @doc.add({}, stream: <<-EOF)
      2 beginbfchar
      <20> <0041>
      <22> <0042>
      endbfchar
    EOF
    @font = @doc.add({Type: :Font, BaseFont: :TestFont, ToUnicode: cmap})
  end

  it "must always be an indirect" do
    assert(@font.must_be_indirect?)
  end

  describe "to_utf" do
    it "uses the /ToUnicode CMap if it is available" do
      assert_equal("A", @font.to_utf8(32))
      assert_equal("B", @font.to_utf8(34))
      assert_equal("", @font.to_utf8(0))
    end

    it "returns an empty string if no /ToUnicode CMap is available" do
      @font.delete(:ToUnicode)
      assert_equal("", @font.to_utf8(32))
    end
  end
end
