# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/writer'
require 'hexapdf/document'
require 'stringio'

describe HexaPDF::Writer do
  before do
    @std_input_io = StringIO.new(<<~EOF.force_encoding(Encoding::BINARY))
      %PDF-1.7
      %\xCF\xEC\xFF\xE8\xD7\xCB\xCD
      1 0 obj
      10
      endobj
      2 0 obj
      20
      endobj
      xref
      0 3
      0000000000 65535 f 
      0000000018 00000 n 
      0000000036 00000 n 
      trailer
      <</Size 3>>
      startxref
      54
      %%EOF
      2 0 obj
      <</Length 10>>stream
      Some data!
      endstream
      endobj
      xref
      2 1
      0000000162 00000 n 
      trailer
      <</Size 3/Prev 54>>
      startxref
      219
      %%EOF
      3 0 obj
      <</Producer(HexaPDF version 0.16.0)>>
      endobj
      xref
      3 1
      0000000296 00000 n 
      trailer
      <</Prev 219/Size 4/Root<</Type/Catalog>>/Info 3 0 R>>
      startxref
      349
      %%EOF
    EOF

    @compressed_input_io = StringIO.new(<<~EOF.force_encoding(Encoding::BINARY))
      %PDF-1.7
      %\xCF\xEC\xFF\xE8\xD7\xCB\xCD
      5 0 obj
      <</Type/ObjStm/N 1/First 4/Filter/FlateDecode/Length 15>>stream
      x\xDA3T0P04P\x00\x00\x04\xA1\x01#
      endstream
      endobj
      2 0 obj
      20
      endobj
      3 0 obj
      <</Size 6/Type/XRef/W[1 1 2]/Index[0 4 5 1]/Filter/FlateDecode/DecodeParms<</Columns 4/Predictor 12>>/Length 31>>stream
      x\xDAcb`\xF8\xFF\x9F\x89\x89\x95\x91\x91\xE9\x7F\x19\x03\x03\x13\x83\x10\x88he`\x00\x00B4\x04\x1E
      endstream
      endobj
      startxref
      141
      %%EOF
      6 0 obj
      <</Producer(HexaPDF version 0.16.0)>>
      endobj
      2 0 obj
      <</Length 10>>stream
      Some data!
      endstream
      endobj
      4 0 obj
      <</Size 7/Prev 141/Root<</Type/Catalog>>/Info 6 0 R/Type/XRef/W[1 2 2]/Index[2 1 4 1 6 1]/Filter/FlateDecode/DecodeParms<</Columns 5/Predictor 12>>/Length 22>>stream
      x\xDAcbdlg``b`\xB0\x04\x93\x93\x18\x18\x00\f\e\x01[
      endstream
      endobj
      startxref
      448
      %%EOF
    EOF
  end

  def assert_document_conversion(input_io)
    document = HexaPDF::Document.new(io: input_io)
    document.trailer.info[:Producer] = "unknown"
    output_io = StringIO.new(''.force_encoding(Encoding::BINARY))
    HexaPDF::Writer.write(document, output_io)
    assert_equal(input_io.string, output_io.string)
  end

  it "writes a complete document" do
    assert_document_conversion(@std_input_io)
    assert_document_conversion(@compressed_input_io)
  end

  it "writes a document in incremental mode" do
    doc = HexaPDF::Document.new(io: @std_input_io)
    doc.pages.add
    output_io = StringIO.new
    HexaPDF::Writer.write(doc, output_io, incremental: true)
    assert_equal(output_io.string[0, @std_input_io.string.length], @std_input_io.string)
    doc = HexaPDF::Document.new(io: output_io)
    assert_equal(4, doc.revisions.size)
    assert_equal(2, doc.revisions.current.each.to_a.size)
  end

  it "raises an error if no xref stream is in a revision but object streams are" do
    document = HexaPDF::Document.new
    document.add({Type: :ObjStm})
    assert_raises(HexaPDF::Error) { HexaPDF::Writer.new(document, StringIO.new).write }
  end

  it "raises an error if the class is misused and an xref section contains invalid entries" do
    document = HexaPDF::Document.new
    io = StringIO.new
    writer = HexaPDF::Writer.new(document, io)
    xref_section = HexaPDF::XRefSection.new
    xref_section.add_compressed_entry(1, 2, 3)
    assert_raises(HexaPDF::Error) { writer.send(:write_xref_section, xref_section) }
  end

  it "removes the /XRefStm entry in a trailer" do
    io = StringIO.new
    doc = HexaPDF::Document.new
    doc.trailer[:XRefStm] = 1234
    doc.write(io)
    doc = HexaPDF::Document.new(io: io)
    refute(doc.trailer.key?(:XRefStm))
  end
end
