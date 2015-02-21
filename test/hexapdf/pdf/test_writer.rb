# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/writer'
require 'hexapdf/pdf/document'
require 'stringio'

describe HexaPDF::PDF::Writer do

  before do
    @std_input_io = StringIO.new(<<EOF.force_encoding(Encoding::BINARY))
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
<</Size 3
>>
startxref
54
%%EOF
2 0 obj
<</Length 10
>>stream
Some data!
endstream
endobj
xref
2 1
0000000163 00000 n 
trailer
<</Size 3
/Prev 54
>>
startxref
221
%%EOF
xref
0 0
trailer
<</Prev 219>>
startxref
296
%%EOF
EOF

    @compressed_input_io = StringIO.new(<<EOF.force_encoding(Encoding::BINARY))
%PDF-1.7
%\xCF\xEC\xFF\xE8\xD7\xCB\xCD
5 0 obj
<</Type /ObjStm
/N 1
/First 4
/Filter /FlateDecode
/Length 15
/DecodeParms null
>>stream
x\xDA3T0P04P\x00\x00\x04\xA1\x01#
endstream
endobj
2 0 obj
20
endobj
3 0 obj
<</Size 3
/Type /XRef
/W [1 1 2]
/Index [0 4 5 1]
/Filter /FlateDecode
/DecodeParms <</Columns 4
/Predictor 12
>>
/Length 31
>>stream
x\xDAcb`\xF8\xFF\x9F\x89\x89\x95\x91\x91\xE9\x7F?\x03\x03\x13\x83\x10\x88\xC8a`\x00\x00C.\x04\x1E
endstream
endobj
startxref
166
%%EOF
2 0 obj
<</Length 10
>>stream
Some data!
endstream
endobj
4 0 obj
<</Size 3
/Prev 166
/Type /XRef
/W [1 2 2]
/Index [2 1 4 1]
/Filter /FlateDecode
/DecodeParms <</Columns 5
/Predictor 12
>>
/Length 20
>>stream
x\xDAcbd\xACd``b`\xB0b`\x00\x00\x054\x00\xBA
endstream
endobj
startxref
435
%%EOF
EOF
  end

  def assert_document_conversion(input_io)
    document = HexaPDF::PDF::Document.new(io: input_io)
    output_io = StringIO.new(''.force_encoding(Encoding::BINARY))
    writer = HexaPDF::PDF::Writer.new(document, output_io)
    writer.write
    assert_equal(input_io.string, output_io.string)
  end

  it "writes a complete document" do
    assert_document_conversion(@std_input_io)
    assert_document_conversion(@compressed_input_io)
  end

  it "raises an error if two xref streams are in one revision" do
    document = HexaPDF::PDF::Document.new()
    document.add(Type: :XRef)
    document.add(Type: :XRef)
    assert_raises(HexaPDF::Error) { HexaPDF::PDF::Writer.new(document, StringIO.new).write }
  end

  it "raises an error if no xref stream is in a revision but object streams are" do
    document = HexaPDF::PDF::Document.new()
    document.add(Type: :ObjStm)
    assert_raises(HexaPDF::Error) { HexaPDF::PDF::Writer.new(document, StringIO.new).write }
  end

end
