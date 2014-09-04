# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/parser'
require 'hexapdf/pdf/document'
require 'stringio'

class PDFParserTest < Minitest::Test

  def setup
    @io = StringIO.new
    @io.string = <<EOF
%PDF-1.7

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
0 5
0000000000 65535 f 
0000000010 00000 n 
0000000028 00000 n 
0000000104 00015 n 
0000000000 65535 f 
trailer
<< /Test (now) >>
startxref
184
%%EOF
EOF
    @parser = HexaPDF::PDF::Parser.new(@io)
  end

  def test_parse_indirect_object
    object, oid, gen, stream = @parser.parse_indirect_object
    assert_equal(1, oid)
    assert_equal(0, gen)
    assert_equal(5, object)
    assert_nil(stream)

    object, oid, gen, stream = @parser.parse_indirect_object
    assert_equal(2, oid)
    assert_equal(0, gen)
    assert_equal([5, 6, {Length: 10}, "name", "Nov shmoz ka pop."], object)
    assert_nil(stream)

    object, oid, gen, stream = @parser.parse_indirect_object
    assert_equal(3, oid)
    assert_equal(15, gen)
    assert_kind_of(HexaPDF::PDF::Stream, stream)
    assert_equal({Length: 10, Hallo: 6}, object)
  end

  def text_startxref_offset
    assert_equal(174, @parser.startxref_offset)

    @io.string = "startxref\n5"
    assert_raises(HexaPDF::MalformedPDFError) { @parser.startxref_offset }

    @io.string = "somexref\n5\n%%EOF"
    assert_raises(HexaPDF::MalformedPDFError) { @parser.startxref_offset }
  end

  def test_file_header_version
    assert_equal('1.7', @parser.file_header_version)
    @io.string = "%PDF-1\n"
    assert_raises(HexaPDF::MalformedPDFError) { @parser.file_header_version }
  end

  def test_xref_table_q
    assert(@parser.xref_table?(@parser.startxref_offset))
    refute(@parser.xref_table?(53))
  end

  def test_parse_xref_table
    table = @parser.parse_xref_table(@parser.startxref_offset)
    assert_equal({Test: 'now'}, table.trailer)
    assert_equal(HexaPDF::PDF::XRefTable::FREE_ENTRY, table[0, 65535])
    assert_equal(HexaPDF::PDF::XRefTable::FREE_ENTRY, table[4, 65535])
    assert_equal(10, table[1])
  end

end
