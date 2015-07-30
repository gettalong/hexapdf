# -*- encoding: utf-8 -*-

require 'test_helper'
require 'stringio'
require 'hexapdf/pdf/serializer'
require 'hexapdf/pdf/object'
require 'hexapdf/pdf/stream'

describe HexaPDF::PDF::Serializer do
  before do
    @serializer = HexaPDF::PDF::Serializer.new
  end

  it "allows access to the top serialized object" do
    object = nil
    @serializer.singleton_class.send(:define_method, :serialize_symbol) do |obj|
      object = @object
      "/#{obj}"
    end
    @serializer.serialize(this: :is, null: nil)
    assert_equal({this: :is, null: nil}, object)
  end

  def assert_serialized(result, object)
    assert_equal(result, @serializer.serialize(object))
  end

  it "serializes nil" do
    assert_serialized("null", nil)
  end

  it "serializes true" do
    assert_serialized("true", true)
  end

  it "serializes false" do
    assert_serialized("false", false)
  end

  it "serializes integers" do
    assert_serialized("100", 100)
    assert_serialized("-100", -100)
    assert_serialized("0", 0)
    assert_serialized("1208925819614629174706176", 1208925819614629174706176)
  end

  it "serializes floats with a precision of 4" do
    assert_serialized("1.5", 1.5)
    assert_serialized("-1.5", -1.5)
    assert_serialized("9.1234", 9.1234)
    assert_serialized("9.1235", 9.12345)
    assert_serialized("0.0005", 0.00047)
    assert_serialized("0.0", 0.0)
  end

  it "serializes symbols" do
    assert_serialized("/Name", :Name)
    assert_serialized("/A;Name_With-Various***Chars?", 'A;Name_With-Various***Chars?'.intern)
    assert_serialized("/1.2", '1.2'.intern)
    assert_serialized("/$$", '$$'.intern)
    assert_serialized("/@pattern", '@pattern'.intern)
    assert_serialized('/.notdef', '.notdef'.intern)
    assert_serialized('/lime#20Green', 'lime Green'.intern)
    assert_serialized('/paired#28#29parentheses', 'paired()parentheses'.intern)
    assert_serialized('/The_Key_of_F#23_Minor', 'The_Key_of_F#_Minor'.intern)
    assert_serialized('/', ''.intern)
    assert_serialized('/H#c3#b6#c3#9fgang', "Hößgang".intern)
    assert_serialized('/H#e8lp', "H\xE8lp".force_encoding('BINARY').intern)
  end

  it "serializes arrays" do
    assert_serialized("[-12 2.4321/Name true(345)true]", [-12, 2.4321, :Name, true, '345', true])
    assert_serialized("[]", [])
  end

  it "serializes hashes" do
    assert_serialized("<</hallo 5/other true/name[5]>>", hallo: 5, other: true, name: [5])
    assert_serialized("<<>>", {})
  end

  it "serializes strings" do
    assert_serialized("(Hallo)", "Hallo")
    assert_serialized("(Hallo\\r\n\t\\(\\)\\\\)", "Hallo\r\n\t()\\")
    assert_serialized("(\xFE\xFF\x00H\x00a\x00l\x00\f\x00\b\x00\\()".force_encoding('BINARY'),
                      "Hal\f\b(")
  end

  it "serializes time like objects" do
    assert_serialized("(D:20150416094100)", Time.new(2015, 04, 16, 9, 41, 0, 0))
    assert_serialized("(D:20150416094100+01'00')", Time.new(2015, 04, 16, 9, 41, 0, 3600))
    assert_serialized("(D:20150416094100-01'20')", Time.new(2015, 04, 16, 9, 41, 0, -4800))
    assert_serialized("(D:20150416000000+02'00')", Date.parse("2015-04-16 9:41:00 +02:00"))
    assert_serialized("(D:20150416094100+02'00')", DateTime.parse("2015-04-16 9:41:00 +02:00"))
  end

  it "serializes HexaPDF objects" do
    assert_serialized("/Name", HexaPDF::PDF::Object.new(:Name))
    assert_serialized("/Name", HexaPDF::PDF::Object.new(:Name, oid: 1))
    assert_serialized("<</Name 2 0 R>>",
                      HexaPDF::PDF::Object.new({Name: HexaPDF::PDF::Object.new(5, oid: 2)}, oid: 1))
  end

  it "serializes HexaPDF reference objects" do
    assert_serialized("5 3 R", HexaPDF::PDF::Reference.new(5, 3))
  end

  describe "stream serialization" do
    before do
      @doc = Object.new
      def (@doc).unwrap(obj); obj; end
      def (@doc).config; {chunk_size: 100}; end
      @stream = HexaPDF::PDF::Stream.new({Key: "value", Length: 5}, oid: 2, document: @doc)
    end

    it "serializes streams" do
      @stream.stream = "somedata"
      assert_serialized("<</Key(value)/Length 8>>stream\nsomedata\nendstream", @stream)
      assert_serialized("<</Name 2 0 R>>", HexaPDF::PDF::Object.new(Name: @stream))
    end

    it "serializes stream more efficiently when an IO is provided" do
      @stream.stream = HexaPDF::PDF::StreamData.new(proc { "some" }, length: 6)
      io = StringIO.new(''.b)
      @serializer.serialize_to_io(@stream, io)
      assert_equal("<</Key(value)/Length 6>>stream\nsome\nendstream", io.string)
    end

    it "fails if a stream without object identifier is serialized" do
      @stream.oid = 0
      assert_raises(HexaPDF::Error) { @serializer.serialize(@stream) }
      assert_raises(HexaPDF::Error) { @serializer.serialize(Name: @stream) }
    end
  end
end
