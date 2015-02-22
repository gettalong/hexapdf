# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/serializer'
require 'hexapdf/pdf/object'

describe HexaPDF::PDF::Serializer do

  before do
    @serializer = HexaPDF::PDF::Serializer.new
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
    assert_serialized("/A;Name_With-Various***Characters?", 'A;Name_With-Various***Characters?'.intern)
    assert_serialized("/1.2", '1.2'.intern)
    assert_serialized("/$$", '$$'.intern)
    assert_serialized("/@pattern", '@pattern'.intern)
    assert_serialized('/.notdef', '.notdef'.intern)
    assert_serialized('/lime#20Green', 'lime Green'.intern)
    assert_serialized('/paired#28#29parentheses', 'paired()parentheses'.intern)
    assert_serialized('/The_Key_of_F#23_Minor', 'The_Key_of_F#_Minor'.intern)
    assert_serialized('/', ''.intern)
    assert_serialized('/H#c3#b6#c3#9fgang', "Hößgang".intern)
  end

  it "serializes arrays" do
    assert_serialized("[-12 2.4321/Name true]", [-12, 2.4321, :Name, true])
    assert_serialized("[]", [])
  end

  it "serializes hashes" do
    assert_serialized("<</hallo 5/other true>>", {hallo: 5, other: true})
    assert_serialized("<<>>", {})
  end

  it "serializes strings" do
    assert_serialized("(Hallo)", "Hallo")
    assert_serialized("(Hallo\r\n\t\\(\\)\\\\)", "Hallo\r\n\t()\\")
    assert_serialized("(\xFE\xFF\x00H\x00a\x00l\x00\f\x00\b\x00\\()".force_encoding('BINARY'), "Hal\f\b(")
  end

  it "serializes HexaPDF objects" do
    assert_serialized("/Name", HexaPDF::PDF::Object.new(:Name))
  end

  it "serializes HexaPDF reference objects" do
    assert_serialized("5 3 R", HexaPDF::PDF::Reference.new(5, 3))
  end

end
