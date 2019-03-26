# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/font/cmap/writer'

describe HexaPDF::Font::CMap::Writer do
  before do
    @cmap_data = <<~EOF
      /CIDInit /ProcSet findresource begin
      12 dict begin
      begincmap
      /CIDSystemInfo
      << /Registry (Adobe)
      /Ordering (UCS)
      /Supplement 0
      >> def
      /CMapName /Adobe-Identity-UCS def
      /CMapType 2 def
      1 begincodespacerange
      <0000> <FFFF>
      endcodespacerange
      2 beginbfchar
      <0060><0090>
      <3A51><d840dc3e>
      endbfchar
      2 beginbfrange
      <0000><005E><0020>
      <1379><137B><90fe>
      endbfrange
      endcmap
      CMapName currentdict /CMap defineresource pop
      end
      end
    EOF
    @mapping = []
    0x00.upto(0x5e) {|i| @mapping << [i, 0x20 + i] }
    @mapping << [0x60, 0x90]
    0x1379.upto(0x137B) {|i| @mapping << [i, 0x90FE + i - 0x1379] }
    @mapping << [0x3A51, 0x2003E]
  end

  describe "create_to_unicode_cmap" do
    it "creates a correct CMap file" do
      assert_equal(@cmap_data, HexaPDF::Font::CMap.create_to_unicode_cmap(@mapping))
    end

    it "works if the last item is a range" do
      @mapping.pop
      @cmap_data.sub!(/2 beginbfchar/, '1 beginbfchar')
      @cmap_data.sub!(/<3A51><d840dc3e>\n/, '')
      assert_equal(@cmap_data, HexaPDF::Font::CMap.create_to_unicode_cmap(@mapping))
    end

    it "works with only ranges" do
      @mapping.delete_at(-1)
      @mapping.delete_at(0x5f)
      @cmap_data.sub!(/\n2 beginbfchar.*endbfchar/m, '')
      assert_equal(@cmap_data, HexaPDF::Font::CMap.create_to_unicode_cmap(@mapping))
    end

    it "returns an empty CMap if the mapping is empty" do
      assert_equal(@cmap_data.sub(/\d+ beginbfchar.*endbfrange/m, ''),
                   HexaPDF::Font::CMap.create_to_unicode_cmap([]))
    end
  end
end
