# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/writer'
require 'hexapdf/pdf/document'
require 'stringio'

describe HexaPDF::PDF::Writer do

  it "writes a complete document" do
    input_io = StringIO.new(<<EOF.force_encoding(Encoding::BINARY))
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
    document = HexaPDF::PDF::Document.new(io: input_io)
    output_io = StringIO.new(''.force_encoding(Encoding::BINARY))
    writer = HexaPDF::PDF::Writer.new(document, output_io)
    writer.write
    assert_equal(input_io.string, output_io.string)
  end

end
