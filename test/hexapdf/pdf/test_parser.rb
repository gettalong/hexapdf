# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/parser'
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
0 4
0000000000 65535 f 
0000000010 00000 n 
0000000028 00000 n 
0000000000 65535 f 
3 1
0000000555 00000 n 
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

    # Test invalid objects
    @io.string = "1 0 obj\n<< >>\nendobjd\n"
    assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object(0) }
    @io.string = "1 0 obj\n<< /name ] >>\nendobj\n"
    assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object(0) }
    @io.string = "1 0 obj\n<< /name other >>\nendobj\n"
    assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object(0) }
    @io.string = "1 0 obj\n<< (string) (key) >>\nendobj\n"
    assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object(0) }
    @io.string = "1 0 obj\n<< /NoValueForKey >>\nendobj\n"
    assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object(0) }

    # Test invalid object streams
    @io.string = "1 0 obj\n(fail)\nstream\nendstream\nendobj\n"
    assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object(15) }
    @io.string = "1 0 obj\n(fail)\nstream\nendstream\nendobj\n"
    assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object(0) }
    @io.string = "1 0 obj\n<< >>\nstream endstream\nendobj\n"
    assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object(0) }
    @io.string = "1 0 obj\n<< >>\nstream\nendobj\n"
    assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object(0) }
  end

  def test_startxref_offset
    assert_equal(184, @parser.startxref_offset)

    @io.string = "startxref\n5\n%%EOF" + "\nhallo"*150
    assert_equal(5, @parser.startxref_offset)

    @io.string = "startxref\n5"
    assert_raises(HexaPDF::MalformedPDFError) { @parser.startxref_offset }

    @io.string = "somexref\n5\n%%EOF"
    assert_raises(HexaPDF::MalformedPDFError) { @parser.startxref_offset }
  end

  def test_file_header_version
    assert_equal('1.7', @parser.file_header_version)

    @io.string = "%PDF-1\n"
    @parser = HexaPDF::PDF::Parser.new(@io)
    assert_raises(HexaPDF::MalformedPDFError) { @parser.file_header_version }
  end

  def test_file_header_retrieval
    @io.string = "junk" * 200 + "\n%PDF-1.4\n"
    @parser.send(:retrieve_pdf_header_offset_and_version)
    assert_equal('1.4', @parser.file_header_version)
    assert_equal(801, @parser.instance_variable_get(:@header_offset))
  end

  def test_xref_table_q
    assert(@parser.xref_table?(@parser.startxref_offset))
    refute(@parser.xref_table?(53))
  end

  def test_parse_xref_table
    table = @parser.parse_xref_table(@parser.startxref_offset)
    assert_equal({Test: 'now'}, table.trailer)
    assert_equal(HexaPDF::PDF::XRefTable::FREE_ENTRY, table[0, 65535])
    assert_equal(HexaPDF::PDF::XRefTable::FREE_ENTRY, table[3, 65535])
    assert_equal(10, table[1])

    # Test invalid xref table
    @io.string = "xref\n0 d\n0000000000 00000 n \n"
    assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_xref_table(15) }
    assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_xref_table(0) }
    @io.string = "xref\n0 1\n0000000000 00000 n \n"
    assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_xref_table(0) }
    @io.string = "xref\n0 1\n0000000000 00000 n \ntrailer\n(base)"
    assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_xref_table(0) }
  end

end
