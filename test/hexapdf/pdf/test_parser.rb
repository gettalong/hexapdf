# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/parser'
require 'hexapdf/pdf/document'
require 'stringio'

class PDFParserTest < Minitest::Test

  def setup
    @io = StringIO.new
    @parser = HexaPDF::PDF::Parser.new(HexaPDF::PDF::Document.new, @io) # second param needs to be adjusted once it is needed in the parser
  end

  def test_parse_indirect_object
    @io.string = <<EOF
1 0 obj
5
endobj

2 0 obj
[ 5 6 <</Length 10 >> (name) <4E6F762073 686D6F7A20	6B612070
6F702E>]
endobj

3 15 obj
<< /Length 10/Hallo 6 >>
stream
Hallo PDF!
endstream
endobj

xref
3 1
0000000104 00015 n 
trailer
<< >>
startxref
174
%%EOF
EOF
    object = @parser.parse_indirect_object
    assert_equal(1, object.oid)
    assert_equal(0, object.gen)
    assert_equal(5, object.value)

    object = @parser.parse_indirect_object
    assert_equal(2, object.oid)
    assert_equal(0, object.gen)
    assert_equal([5, 6, {Length: 10}, "name", "Nov shmoz ka pop."], object.value)

    object = @parser.parse_indirect_object
    assert_equal(3, object.oid)
    assert_equal(15, object.gen)
    assert_kind_of(HexaPDF::PDF::Stream, object)
    assert_equal({Length: 10, Hallo: 6}, object.dictionary)
  end

end
