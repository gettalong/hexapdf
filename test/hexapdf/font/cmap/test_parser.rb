# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/font/cmap/parser'

describe HexaPDF::Font::CMap::Parser do
  describe "::parse" do
    it "parses CMap data correctly" do
      data = <<EOF
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
2 beginbfrange
<0000> <005E> <0020>
<005F> <0061> [ <00660066> <00660069> <00660066006C> ]
endbfrange
1 beginbfchar
<3A51> <D840DC3E>
endbfchar
endcmap
CMapName currentdict /CMap defineresource pop
end
end
EOF
      cmap = HexaPDF::Font::CMap.parse(data)
      assert_equal("Adobe", cmap.registry)
      assert_equal("UCS", cmap.ordering)
      assert_equal(0, cmap.supplement)
      assert_equal("Adobe-Identity-UCS", cmap.name)
      ((0x20.chr)..(0x7e.chr)).each_with_index do |str, index|
        assert_equal(str, cmap.to_unicode(index))
      end
      assert_equal("ff", cmap.to_unicode(0x5F))
      assert_equal("fi", cmap.to_unicode(0x60))
      assert_equal("ffl", cmap.to_unicode(0x61))
      assert_equal("\xD8\x40\xDC\x3E".encode("UTF-8", "UTF-16BE"), cmap.to_unicode(0x3A * 256 + 0x51))
    end

    it "fails if there is an invalid token inside the bfrange operator" do
      assert_raises(HexaPDF::Error) do
        HexaPDF::Font::CMap.parse("1 beginbfrange <0000> <0001> 5 endbfrange")
      end
    end

    it "fails if the CMap is not correctly structured" do
      assert_raises(HexaPDF::Error) do
        HexaPDF::Font::CMap.parse("1 beginbfchar <0000> <0001>")
      end
    end
  end
end
