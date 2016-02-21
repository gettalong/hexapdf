# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/parser'
require 'stringio'

describe HexaPDF::Parser do
  before do
    @document = HexaPDF::Document.new
    @document.add(@document.wrap(10, oid: 1, gen: 0))

    create_parser(<<EOF)
%PDF-1.7

1 0 obj
10
endobj

2 0 obj
[ 5 6 <</Length 10 >> (name) <4E6F762073 686D6F7A20	6B612070
6F702E>]
endobj

3 15 obj<< /Length 1 0 R/Hallo 6/Filter /Fl/DecodeParms<<>> >>stream
Hallo PDF!endstream
endobj

4 0 obj
<</Type /XRef /Length 3 /W [1 1 1] /Index [1 1] /Size 2 >> stream
\x01\x0A\x00
endstream
endobj

xref
0 4
0000000000 65535 f 
0000000010 00000 n 
0000000029 00000 n 
0000000000 65535 f 
3 1
0000000556 00000 n 
trailer
<< /Test (now) >>
startxref
308
%%EOF
EOF
  end

  def create_parser(str)
    @parser = HexaPDF::Parser.new(StringIO.new(str), @document)
  end

  describe "parse_indirect_object" do
    it "reads indirect objects sequentially" do
      object, oid, gen, stream = @parser.parse_indirect_object
      assert_equal(1, oid)
      assert_equal(0, gen)
      assert_equal(10, object)
      assert_nil(stream)

      object, oid, gen, stream = @parser.parse_indirect_object
      assert_equal(2, oid)
      assert_equal(0, gen)
      assert_equal([5, 6, {Length: 10}, "name", "Nov shmoz ka pop."], object)
      assert_nil(stream)

      object, oid, gen, stream = @parser.parse_indirect_object
      assert_equal(3, oid)
      assert_equal(15, gen)
      assert_kind_of(HexaPDF::StreamData, stream)
      assert_equal([:Fl], stream.filter)
      assert_equal([{}], stream.decode_parms)
      assert_equal({Length: 10, Hallo: 6, Filter: :Fl, DecodeParms: {}}, object)
    end

    it "handles empty indirect objects by using PDF null for them" do
      create_parser("1 0 obj\nendobj")
      object, * = @parser.parse_indirect_object
      assert_nil(object)
    end

    it "handles keyword stream followed only by CR without LF" do
      create_parser("1 0 obj<</Length 2>> stream\r12\nendstream endobj")
      *, stream = @parser.parse_indirect_object
      assert_equal('12', TestHelper.collector(stream.fiber))
    end

    it "recovers from an invalid stream length value" do
      create_parser("1 0 obj<</Length 4>> stream\n12endstream endobj")
      obj, _, _, stream = @parser.parse_indirect_object
      assert_equal(2, obj[:Length])
      assert_equal('12', TestHelper.collector(stream.fiber))
    end

    it "works even if the keyword endobj is missing or mangled" do
      create_parser("1 0 obj<</Length 4>>5")
      object, * = @parser.parse_indirect_object
      assert_equal({Length: 4}, object)
      create_parser("1 0 obj<</Length 4>>endobjk")
      object, * = @parser.parse_indirect_object
      assert_equal({Length: 4}, object)
    end

    it "fails if the oid, gen or 'obj' keyword is invalid" do
      create_parser("a 0 obj\n5\nendobj")
      exp = assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object }
      assert_match(/No valid object/, exp.message)
      create_parser("1 a obj\n5\nendobj")
      exp = assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object }
      assert_match(/No valid object/, exp.message)
      create_parser("1 0 dobj\n5\nendobj")
      exp = assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object }
      assert_match(/No valid object/, exp.message)
    end

    it "fails if the value of a stream is not a dictionary" do
      create_parser("1 0 obj\n(fail)\nstream\nendstream\nendobj\n")
      exp = assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object }
      assert_match(/stream.*dictionary/, exp.message)
    end

    it "fails if the 'stream' keyword isn't followed by EOL" do
      create_parser("1 0 obj\n<< >>\nstream endstream\nendobj\n")
      exp = assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object(0) }
      assert_match(/stream.*followed by LF/, exp.message)
    end

    it "fails if the 'endstream' keyword is missing" do
      create_parser("1 0 obj\n<< >>\nstream\nendobj\n")
      exp = assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object(0) }
      assert_match(/stream.*followed by.*endstream/i, exp.message)
    end
  end

  describe "load_object" do
    before do
      @entry = HexaPDF::XRefSection.in_use_entry(2, 0, 29)
    end

    it "can load an indirect object" do
      obj = @parser.load_object(@entry)
      assert_kind_of(HexaPDF::Object, obj)
      assert_equal(5, obj.value[0])
      assert_equal(2, obj.oid)
      assert_equal(0, obj.gen)
    end

    it "can load a free object" do
      obj = @parser.load_object(HexaPDF::XRefSection.free_entry(0, 0))
      assert_kind_of(HexaPDF::Object, obj)
      assert_nil(obj.value)
    end

    it "can load a compressed object" do
      def (@document).object(_oid)
        obj = Object.new
        def obj.parse_stream
          HexaPDF::PDF::Type::ObjectStream::Data.new("5 [1 2]", [1, 2], [0, 2])
        end
        obj
      end

      obj = @parser.load_object(HexaPDF::XRefSection.compressed_entry(2, 3, 1))
      assert_kind_of(HexaPDF::Object, obj)
      assert_equal([1, 2], obj.value)
    end

    it "fails if another object is found instead of an object stream" do
      def (@document).object(_oid)
        :invalid
      end
      exp = assert_raises(HexaPDF::MalformedPDFError) do
        @parser.load_object(HexaPDF::XRefSection.compressed_entry(2, 1, 1))
      end
      assert_match(/not an object stream/, exp.message)
    end

    it "fails if the xref entry type is invalid" do
      exp = assert_raises(HexaPDF::MalformedPDFError) do
        @parser.load_object(HexaPDF::XRefSection::Entry.new(:invalid))
      end
      assert_match(/invalid cross-reference type/i, exp.message)
    end

    it "fails if the object/generation numbers don't match" do
      exp = assert_raises(HexaPDF::MalformedPDFError) do
        @entry.gen = 2
        @parser.load_object(@entry)
      end
      assert_match(/oid,gen.*don't match/, exp.message)
    end
  end

  describe "startxref_offset" do
    it "returns the correct offset" do
      assert_equal(308, @parser.startxref_offset)
    end

    it "ignores garbage at the end of the file" do
      create_parser("startxref\n5\n%%EOF" + "\nhallo" * 150)
      assert_equal(5, @parser.startxref_offset)
    end

    it "uses the last startxref if there are more than one" do
      create_parser("startxref\n5\n%%EOF\n\nsome garbage\n\nstartxref\n555\n%%EOF\n")
      assert_equal(555, @parser.startxref_offset)
    end

    it "finds the startxref anywhere in file" do
      create_parser("startxref\n5\n%%EOF" + "\nhallo" * 5000)
      assert_equal(5, @parser.startxref_offset)
      create_parser("startxref\n5\n%%EOF\n" + "h" * 1017)
      assert_equal(5, @parser.startxref_offset)
    end

    it "fails even in big files when nothing is found" do
      create_parser("\nhallo" * 5000)
      exp = assert_raises(HexaPDF::MalformedPDFError) { @parser.startxref_offset }
      assert_match(/end-of-file marker not found/, exp.message)
    end

    it "fails if the %%EOF marker is missing" do
      create_parser("startxref\n5")
      exp = assert_raises(HexaPDF::MalformedPDFError) { @parser.startxref_offset }
      assert_match(/end-of-file marker not found/, exp.message)
    end

    it "fails if the startxref keyword is missing" do
      create_parser("somexref\n5\n%%EOF")
      exp = assert_raises(HexaPDF::MalformedPDFError) { @parser.startxref_offset }
      assert_match(/missing startxref/, exp.message)
    end
  end

  describe "file_header_version" do
    it "returns the correct version" do
      assert_equal('1.7', @parser.file_header_version)
    end

    it "fails if the header is mangled" do
      create_parser("%PDF-1\n")
      exp = assert_raises(HexaPDF::MalformedPDFError) { @parser.file_header_version }
      assert_match(/file header/, exp.message)
    end

    it "ignores junk at the beginning of the file and correctly calculates offset" do
      create_parser("junk" * 200 + "\n%PDF-1.4\n")
      assert_equal('1.4', @parser.file_header_version)
      assert_equal(801, @parser.instance_variable_get(:@header_offset))
    end
  end

  it "xref_section?" do
    assert(@parser.xref_section?(@parser.startxref_offset))
    refute(@parser.xref_section?(53))
  end

  describe "parse_xref_section_and_trailer" do
    it "works on a section with multiple sub sections" do
      section, trailer = @parser.parse_xref_section_and_trailer(@parser.startxref_offset)
      assert_equal({Test: 'now'}, trailer)
      assert_equal(HexaPDF::XRefSection.free_entry(0, 65535), section[0, 65535])
      assert_equal(HexaPDF::XRefSection.free_entry(3, 65535), section[3, 65535])
      assert_equal(HexaPDF::XRefSection.in_use_entry(1, 0, 10), section[1])
    end

    it "works for an empty section" do
      create_parser("xref\n0 0\ntrailer\n<</Name /Value >>\n")
      _, trailer = @parser.parse_xref_section_and_trailer(0)
      assert_equal({Name: :Value}, trailer)
    end

    it "handles xref type=n with offset=0" do
      create_parser("xref\n0 2\n0000000000 00000 n \n0000000000 00000 n \ntrailer\n<<>>\n")
      section, _trailer = @parser.parse_xref_section_and_trailer(0)
      assert_equal(HexaPDF::XRefSection.free_entry(1, 0), section[1])
    end

    it "handles xref type=n with gen>65535" do
      create_parser("xref\n0 2\n0000000000 00000 n \n0000000000 65536 n \ntrailer\n<<>>\n")
      section, _trailer = @parser.parse_xref_section_and_trailer(0)
      assert_equal(HexaPDF::XRefSection.free_entry(1, 65536), section[1])
    end

    it "fails if the xref keyword is missing/mangled" do
      create_parser("xTEf\n0 d\n0000000000 00000 n \ntrailer\n<< >>\n")
      exp = assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_xref_section_and_trailer(0) }
      assert_match(/keyword xref/, exp.message)
    end

    it "fails if a sub section header is mangled" do
      create_parser("xref\n0 d\n0000000000 00000 n \ntrailer\n<< >>\n")
      exp = assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_xref_section_and_trailer(0) }
      assert_match(/invalid cross-reference subsection/i, exp.message)
    end

    it "fails if there is no trailer" do
      create_parser("xref\n0 1\n0000000000 00000 n \n")
      exp = assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_xref_section_and_trailer(0) }
      assert_match(/keyword trailer/i, exp.message)
    end

    it "fails if the trailer is not a PDF dictionary" do
      create_parser("xref\n0 1\n0000000000 00000 n \ntrailer\n(base)")
      exp = assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_xref_section_and_trailer(0) }
      assert_match(/dictionary/, exp.message)
    end
  end

  describe "load_revision" do
    it "works for a simple cross-reference section" do
      xref_section, trailer = @parser.load_revision(@parser.startxref_offset)
      assert_equal({Test: 'now'}, trailer)
      assert(xref_section[1].in_use?)
    end

    it "works for a cross-reference stream" do
      xref_section, trailer = @parser.load_revision(212)
      assert_equal({Size: 2}, trailer)
      assert(xref_section[1].in_use?)
    end

    it "fails if another object is found instead of a cross-reference stream" do
      exp = assert_raises(HexaPDF::MalformedPDFError) { @parser.load_revision(10) }
      assert_match(/not a cross-reference stream/, exp.message)
    end
  end

  describe "with strict parsing enabled" do
    before do
      @document.config['parser.on_correctable_error'] = proc { true }
    end

    it "startxref_offset fails if the startxref is not in the last part of the file" do
      create_parser("startxref\n5\n%%EOF" + "\nhallo" * 5000)
      exp = assert_raises(HexaPDF::MalformedPDFError) { @parser.startxref_offset }
      assert_match(/end-of-file marker not found/, exp.message)
    end

    it "parse_xref_section_and_trailer fails if xref type=n with offset=0" do
      create_parser("xref\n0 2\n0000000000 00000 n \n0000000000 00000 n \ntrailer\n<<>>\n")
      exp = assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_xref_section_and_trailer(0) }
      assert_match(/invalid.*cross-reference entry/i, exp.message)
    end

    it "parse_xref_section_and_trailer fails xref type=n with gen>65535" do
      create_parser("xref\n0 2\n0000000000 00000 n \n0000000000 65536 n \ntrailer\n<<>>\n")
      exp = assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_xref_section_and_trailer(0) }
      assert_match(/invalid.*cross-reference entry/i, exp.message)
    end

    it "parse_indirect_object fails if an empty indirect object is found" do
      create_parser("1 0 obj\nendobj")
      exp = assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object }
      assert_match(/no indirect object value/i, exp.message)
    end

    it "parse_indirect_object fails if keyword stream is followed only by CR without LF" do
      create_parser("1 0 obj<</Length 2>> stream\r12\nendstream endobj")
      exp = assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object }
      assert_match(/not CR alone/, exp.message)
    end

    it "parse_indirect_object fails if the stream length value is invalid" do
      create_parser("1 0 obj<</Length 4>> stream\n12endstream endobj")
      exp = assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object }
      assert_match(/invalid stream length/i, exp.message)
    end

    it "parse_indirect_object fails if the keyword endobj is missing or mangled" do
      create_parser("1 0 obj\n<< >>\nendobjd\n")
      exp = assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object }
      assert_match(/keyword endobj/, exp.message)
      create_parser("1 0 obj\n<< >>")
      exp = assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object }
      assert_match(/keyword endobj/, exp.message)
    end

    it "parse_indirect_object fails if there is data between 'endstream' and 'endobj'" do
      create_parser("1 0 obj\n<< >>\nstream\nendstream\ntest\nendobj\n")
      exp = assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object(0) }
      assert_match(/keyword endobj/, exp.message)
    end

    it "load_revision fails if the cross-reference stream doesn't contain an entry for itself" do
      create_parser("2 0 obj\n<</Type/XRef/Length 3/W [1 1 1]/Size 1>>" <<
                    "stream\n\x01\x0A\x00\nendstream endobj")
      exp = assert_raises(HexaPDF::MalformedPDFError) { @parser.load_revision(0) }
      assert_match(/entry for itself/, exp.message)
    end

  end
end
