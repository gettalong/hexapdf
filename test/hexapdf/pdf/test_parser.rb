# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/parser'
require 'stringio'

describe HexaPDF::PDF::Parser do

  before do
    set_string(<<EOF)
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
212
%%EOF
EOF
  end

  def set_string(str)
    @parser = HexaPDF::PDF::Parser.new(StringIO.new(str), self)
  end

  def unwrap(obj)
    return obj unless obj.kind_of?(HexaPDF::PDF::Reference)
    section, _ = @parser.parse_xref_section_and_trailer(@parser.startxref_offset)
    @parser.parse_indirect_object(section[obj.oid, obj.gen].pos).first
  end

  def wrap(obj, type: nil, subtype: nil, oid: nil, gen: nil, stream: nil)
    klass = stream.nil? ? HexaPDF::PDF::Object : HexaPDF::PDF::Stream
    wrapped = klass.new(obj)
    wrapped.oid = oid if oid
    wrapped.gen = gen if gen
    wrapped
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
      assert_kind_of(HexaPDF::PDF::StreamData, stream)
      assert_equal([:Fl], stream.filter)
      assert_equal([{}], stream.decode_parms)
      assert_equal({Length: HexaPDF::PDF::Reference.new(1, 0), Hallo: 6, Filter: :Fl, DecodeParms: {}}, object)
    end

    it "fails if the oid, gen or 'obj' keyword is invalid" do
      set_string("a 0 obj\n5\nendobj")
      assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object }
      set_string("1 a obj\n5\nendobj")
      assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object }
      set_string("1 0 dobj\n5\nendobj")
      assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object }
    end

    it "fails if endobj is missing or mangled" do
      set_string("1 0 obj\n<< >>\nendobjd\n")
      assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object }
      set_string("1 0 obj\n<< >>")
      assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object }
    end

    it "fails if the value of a stream is not a dictionary" do
      set_string("1 0 obj\n(fail)\nstream\nendstream\nendobj\n")
      assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object }
    end

    it "fails if the 'stream' keyword isn't followed by EOL" do
      set_string("1 0 obj\n<< >>\nstream endstream\nendobj\n")
      assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object(0) }
    end

    it "fails if the 'endstream' keyword is missing" do
      set_string("1 0 obj\n<< >>\nstream\nendobj\n")
      assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object(0) }
    end

    it "fails if there is data between 'endstream' and 'endobj'" do
      set_string("1 0 obj\n<< >>\nstream\nendstream\ntest\nendobj\n")
      assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_indirect_object(0) }
    end
  end

  describe "load_object" do

    before do
      @entry = HexaPDF::PDF::XRefSection.in_use_entry(2, 0, 29)
    end

    it "can load an indirect object" do
      obj = @parser.load_object(@entry)
      assert_kind_of(HexaPDF::PDF::Object, obj)
      assert_equal(5, obj.value[0])
      assert_equal(2, obj.oid)
      assert_equal(0, obj.gen)
    end

    it "can load a free object" do
      obj = @parser.load_object(HexaPDF::PDF::XRefSection.free_entry(0, 0))
      assert_kind_of(HexaPDF::PDF::Object, obj)
      assert_nil(obj.value)
    end

    it "fails if the xref entry type is invalid" do
      assert_raises(HexaPDF::Error) { @parser.load_object(HexaPDF::PDF::XRefSection::Entry.new(:invalid)) }
    end

    it "fails if the xref entry type is :compressed because this is not yet implemented" do
      assert_raises(RuntimeError) { @parser.load_object(HexaPDF::PDF::XRefSection::Entry.new(:compressed)) }
    end

    it "fails if the object/generation numbers don't match" do
      assert_raises(HexaPDF::MalformedPDFError) do
        @entry.gen = 2
        @parser.load_object(@entry)
      end
    end
  end

  describe "startxref_offset" do
    it "returns the correct offset" do
      assert_equal(212, @parser.startxref_offset)
    end

    it "ignores garbage at the end of the file" do
      set_string("startxref\n5\n%%EOF" + "\nhallo"*150)
      assert_equal(5, @parser.startxref_offset)
    end

    it "uses the last startxref if there are more than one in the last ~1000 byte" do
      set_string("startxref\n5\n%%EOF\n\nsome garbage\n\nstartxref\n555\n%%EOF\n")
      assert_equal(555, @parser.startxref_offset)
    end

    it "fails if the %%EOF marker is missing" do
      set_string("startxref\n5")
      assert_raises(HexaPDF::MalformedPDFError) { @parser.startxref_offset }
    end

    it "fails if the startxref keyword is missing" do
      set_string("somexref\n5\n%%EOF")
      assert_raises(HexaPDF::MalformedPDFError) { @parser.startxref_offset }
    end
  end

  describe "file_header_version" do
    it "returns the correct version" do
      assert_equal('1.7', @parser.file_header_version)
    end

    it "fails if the header is mangled" do
      set_string("%PDF-1\n")
      assert_raises(HexaPDF::MalformedPDFError) { @parser.file_header_version }
    end

    it "ignores junk at the beginning of the file and correctly calculates offset" do
      set_string("junk" * 200 + "\n%PDF-1.4\n")
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
      assert_equal(HexaPDF::PDF::XRefSection.free_entry(0, 65535), section[0, 65535])
      assert_equal(HexaPDF::PDF::XRefSection.free_entry(3, 65535), section[3, 65535])
      assert_equal(HexaPDF::PDF::XRefSection.in_use_entry(1, 0, 10), section[1])
    end

    it "works for an empty section" do
      set_string("xref\n0 0\ntrailer\n<</Name /Value >>\n")
      _, trailer = @parser.parse_xref_section_and_trailer(0)
      assert_equal({Name: :Value}, trailer)
    end

    it "fails if the xref keyword is missing/mangled" do
      set_string("xTEf\n0 d\n0000000000 00000 n \ntrailer\n<< >>\n")
      assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_xref_section_and_trailer(0) }
    end

    it "fails if a sub section header is mangled" do
      set_string("xref\n0 d\n0000000000 00000 n \ntrailer\n<< >>\n")
      assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_xref_section_and_trailer(0) }
    end

    it "fails if there is no trailer" do
      set_string("xref\n0 1\n0000000000 00000 n \n")
      assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_xref_section_and_trailer(0) }
    end

    it "fails if the trailer is not a PDF dictionary" do
      set_string("xref\n0 1\n0000000000 00000 n \ntrailer\n(base)")
      assert_raises(HexaPDF::MalformedPDFError) { @parser.parse_xref_section_and_trailer(0) }
    end
  end

  describe "load_revision" do
    it "works for a simple cross-reference section" do
      revision = @parser.load_revision(@parser.startxref_offset)
      assert_equal({Test: 'now'}, revision.trailer.value)
      assert_equal(10, revision.object(1).value)
    end
  end

end
