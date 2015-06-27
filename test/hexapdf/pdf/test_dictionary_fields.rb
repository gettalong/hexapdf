# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/dictionary_fields'
require 'hexapdf/pdf/object'
require 'hexapdf/pdf/dictionary'

describe HexaPDF::PDF::DictionaryFields do

  include HexaPDF::PDF::DictionaryFields

  describe "Field" do
    before do
      @field = self.class::Field.new(['Integer', Integer], true, 500, false, '1.2')
    end

    it "allows access to the basic field information" do
      assert(@field.required?)
      assert(@field.default?)
      assert_equal(500, @field.default)
      assert_equal(false, @field.indirect)
      assert_equal('1.2', @field.version)
    end

    it "maps string types to constants" do
      assert_equal([Integer], @field.type)
    end

    it "uses the additional types from a converter" do
      @field = self.class::Field.new(self.class::PDFByteString)
      assert_equal([self.class::PDFByteString, String], @field.type)
    end

    it "does not allow any conversion with the identity converter" do
      x = '5'
      refute(@field.convert?(x))
      assert_same(x, @field.convert(x, self))
    end

    it "can check for a valid object" do
      refute(@field.valid_object?('Test'))
      assert(@field.valid_object?(5))
      assert(@field.valid_object?(HexaPDF::PDF::Object.new(5)))
    end
  end

  describe "DictionaryConverter" do
    before do
      @field = self.class::Field.new(Class.new(HexaPDF::PDF::Dictionary))
      @doc = Minitest::Mock.new
    end

    it "additionally adds Hash as allowed type" do
      assert(@field.type.include?(Hash))
    end

    it "allows conversion from a hash" do
      assert(@field.convert?({}))
      @doc.expect(:wrap, :data, [Hash, Hash])
      @field.convert({Test: :value}, @doc)
      @doc.verify
    end

    it "allows conversion from a Dictionary" do
      assert(@field.convert?(HexaPDF::PDF::Dictionary.new({})))
      @doc.expect(:wrap, :data, [HexaPDF::PDF::Dictionary, Hash])
      @field.convert(HexaPDF::PDF::Dictionary.new({Test: :value}), @doc)
      @doc.verify
    end
  end

  describe "StringConverter" do
    before do
      @field = self.class::Field.new(String)
    end

    it "allows conversion to UTF-8 string from binary" do
      assert(@field.convert?('test'.b))

      str = @field.convert("\xfe\xff\x00t\x00e\x00s\x00t".b, self)
      assert_equal('test', str)
      assert_equal(Encoding::UTF_8, str.encoding)
      str = @field.convert("Testing\x9c\x92".b, self)
      assert_equal("Testing\u0153\u2122", str)
      assert_equal(Encoding::UTF_8, str.encoding)
    end
  end

  describe "PDFByteStringConverter" do
    before do
      @field = self.class::Field.new(self.class::PDFByteString)
    end

    it "additionally adds String as allowed type if not already present" do
      assert_equal([HexaPDF::PDF::Dictionary::PDFByteString, String], @field.type)
    end

    it "allows conversion to a binary string" do
      assert(@field.convert?('test'))
      refute(@field.convert?('test'.b))

      str = @field.convert("test", self)
      assert_equal('test', str)
      assert_equal(Encoding::BINARY, str.encoding)
    end
  end

  describe "DateConverter" do
    before do
      @field = self.class::Field.new(self.class::PDFDate)
    end

    it "additionally adds String/Time/Date/DateTime as allowed types" do
      assert_equal([HexaPDF::PDF::Dictionary::PDFDate, String, Time, Date, DateTime], @field.type)
    end

    it "allows conversion to a Time object from a binary string" do
      date = "D:199812231952-08'00".b
      refute(@field.convert?('test'.b))
      assert(@field.convert?(date))

      obj = @field.convert(date, self)
      assert_equal(1998, obj.year)
      assert_equal(12, obj.month)
      assert_equal(23, obj.day)
      assert_equal(19, obj.hour)
      assert_equal(52, obj.min)
      assert_equal(0, obj.sec)
      assert_equal(-8*60*60, obj.utc_offset)

      date = "D:19981223".b
      obj = @field.convert(date, self)
      assert_equal(1998, obj.year)
      assert_equal(12, obj.month)
      assert_equal(23, obj.day)
      assert_equal(0, obj.hour)
      assert_equal(0, obj.min)
      assert_equal(0, obj.sec)
      assert_equal(0, obj.utc_offset)
    end
  end

end
