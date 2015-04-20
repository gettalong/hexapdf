# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/dictionary'

describe HexaPDF::PDF::Dictionary do

  def deref(obj)
    obj
  end

  def add(obj)
    HexaPDF::PDF::Object.new(obj, oid: 1)
  end

  def delete(obj)
  end

  def wrap(obj, type:)
    type.new(obj, document: self)
  end

  before do
    @test_class = Class.new(HexaPDF::PDF::Dictionary)
    @test_class.define_field(:Boolean, type: [TrueClass, FalseClass], default: false, version: '1.3')
    @test_class.define_field(:Array, type: Array, required: true, default: [])
    @test_class.define_field(:TestClass, type: @test_class, indirect: true)

    @dict = @test_class.new({:Array => [3, 4], :Other => 5, :Object => HexaPDF::PDF::Object.new(:obj)},
                            document: self)
  end

  describe "Field" do
    before do
      @field = @test_class.define_field(:Int, type: ['Integer', Integer])
    end

    it "maps string types to constants" do
      assert_equal([Integer, Integer], @field.type)
    end

    it "is used correctly by define_field" do
      assert_kind_of(HexaPDF::PDF::Dictionary::Field, @field)
    end

    it "does not allow any conversion" do
      x = '5'
      refute(@field.convert?(x))
      assert_same(x, @field.convert(x, self))
    end
  end

  describe "DictionaryField" do
    before do
      @field = @test_class.define_field(:SampleDict, type: @test_class)
    end

    it "additionally adds Hash as allowed type" do
      assert_equal([@test_class, Hash], @field.type)
    end

    it "is used correctly by define_field" do
      assert_kind_of(HexaPDF::PDF::Dictionary::DictionaryField, @field)
    end

    it "allows conversion from nil" do
      assert(@field.convert?(nil))
      obj = @field.convert(nil, self)
      assert_kind_of(@test_class, obj)
      assert_equal(self, obj.document)
    end

    it "allows conversion from a hash" do
      assert(@field.convert?({}))
      obj = @field.convert({Test: :value}, self)
      assert_kind_of(@test_class, obj)
      assert_equal(self, obj.document)
      assert_equal(:value, obj.value[:Test])
    end

    it "allows conversion from a Dictionary" do
      assert(@field.convert?(HexaPDF::PDF::Dictionary.new({})))
      obj = @field.convert(HexaPDF::PDF::Dictionary.new({Test: :value}), self)
      assert_kind_of(@test_class, obj)
      assert_equal(self, obj.document)
      assert_equal(:value, obj.value[:Test])
    end
  end

  describe "StringField" do
    before do
      @field = @test_class.define_field(:String, type: String)
      @bin_field = @test_class.define_field(:Binary, type: HexaPDF::PDF::Dictionary::PDFByteString)
    end

    it "additionally adds String as allowed type if not already present" do
      assert_equal([String], @field.type)
      assert_equal([HexaPDF::PDF::Dictionary::PDFByteString, String], @bin_field.type)
    end

    it "is used correctly by define_field" do
      assert_kind_of(HexaPDF::PDF::Dictionary::StringField, @field)
      assert_kind_of(HexaPDF::PDF::Dictionary::StringField, @bin_field)
    end

    it "allows conversion to UTF-8 string from binary" do
      assert(@field.convert?('test'.b))
      refute(@bin_field.convert?('test'.b))

      str = @field.convert("\xfe\xff\x00t\x00e\x00s\x00t".b, self)
      assert_equal('test', str)
      assert_equal(Encoding::UTF_8, str.encoding)
      str = @field.convert("Testing\x9c\x92".b, self)
      assert_equal("Testing\u0153\u2122", str)
      assert_equal(Encoding::UTF_8, str.encoding)
    end
  end

  describe "DateField" do
    before do
      @field = @test_class.define_field(:Date, type: HexaPDF::PDF::Dictionary::PDFDate)
    end

    it "additionally adds String/Time/Date/DateTime as allowed types" do
      assert_equal([HexaPDF::PDF::Dictionary::PDFDate, String, Time, Date, DateTime], @field.type)
    end

    it "is used correctly by define_field" do
      assert_kind_of(HexaPDF::PDF::Dictionary::DateField, @field)
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

  describe "class methods" do
    it "allows defining fields and retrieving their info" do
      field = @test_class.field(:Boolean)
      refute_nil(field)
      assert_equal(:'1.3', field.version)
      assert_equal(false, field.default)
      refute(field.required?)

      field = @test_class.field(:Array)
      assert(field.required?)
      assert_equal([], field.default)

      assert(@test_class.field(:TestClass).indirect)
    end

    it "can retrieve fields from parent classes" do
      @inherited_class = Class.new(@test_class)

      assert(@inherited_class.field(:Boolean))
      refute(@inherited_class.field(:Unknown))
    end

    it "can iterate over all fields" do
      @inherited_class = Class.new(@test_class)
      @inherited_class.define_field(:Inherited, type: [Array, Symbol])
      assert_equal([:Boolean, :Array, :TestClass, :Inherited], @inherited_class.each_field.map {|k,v| k})
    end

    it "allows field access without subclassing" do
      refute(HexaPDF::PDF::Dictionary.field(:Test))
      assert_equal([], HexaPDF::PDF::Dictionary.each_field.to_a)
    end

  end

  describe "value=" do
    it "fails if the value is not a hash" do
      assert_raises(HexaPDF::Error) { HexaPDF::PDF::Dictionary.new(:Name) }
    end

    it "sets the default value for a required field that has one" do
      @test_class.define_field(:Type, type: Symbol, required: true, default: :MyType)
      obj = @test_class.new(nil)
      assert_equal(:MyType, obj.value[:Type])
    end
  end

  describe "[]" do
    it "allows retrieving set field values" do
      assert_equal([3, 4], @dict[:Array])
      assert_equal(5, @dict[:Other])
    end

    it "uses a default value if no value is set" do
      assert_equal(false, @dict[:Boolean])
      @dict.value[:Boolean] = true
      assert_equal(true, @dict[:Boolean])
    end

    it "wraps nil/Hash values in specific subclasses" do
      @dict.value[:TestClass] = nil
      assert_kind_of(@test_class, @dict[:TestClass])
      assert_equal([], @dict[:TestClass][:Array])

      @dict.value[:TestClass] = {Array: [1, 2]}
      assert_kind_of(@test_class, @dict[:TestClass])
      assert_equal([1, 2], @dict[:TestClass][:Array])

      @dict.value[:TestClass] = HexaPDF::PDF::Object.new([1, 2])
      refute_kind_of(@test_class, @dict[:TestClass])
      assert_equal([1, 2], @dict[:TestClass])
    end

    it "fetches the value out of a HexaPDF::PDF::Object" do
      assert_equal(:obj, @dict[:Object])
    end
  end

  describe "[]=" do
    it "directly stores the value if the stored value is no HexaPDF::PDF::Object" do
      @dict[:Array] = [4, 5]
      assert_equal([4, 5], @dict.value[:Array])

      @dict[:NewValue] = 7
      assert_equal(7, @dict.value[:NewValue])
    end

    it "stores the value inside the current value HexaPDF::PDF::Object but only if the given one is not such an object" do
      @dict[:Object] = [4, 5]
      assert_equal([4, 5], @dict.value[:Object].value)

      @dict[:Object] = temp = HexaPDF::PDF::Object.new(:other)
      assert_equal(temp, @dict.value[:Object])
    end

    it "doesn't store the value inside subclasses of HexaPDF::PDF::Object but directly as stored value" do
      @dict[:TestClass][:Array] = [4, 5]
      assert_kind_of(@test_class, @dict[:TestClass])
      @dict[:TestClass] = [4, 5]
      assert_equal([4, 5], @dict[:TestClass])
    end

    it "raises an error if the key is not a symbol object" do
      assert_raises(HexaPDF::Error) { @dict[5] = 6 }
    end
  end

  describe "validate_fields" do
    before do
      @test_class.define_field(:Inherited, type: [Array, Symbol], required: true, indirect: false)
      @obj = @test_class.new({Array: [], Inherited: :symbol}, document: self)
    end

    it "checks for the required fields w/wo auto_correct" do
      assert(@obj.validate(auto_correct: false))
      assert_equal({Array: [], Inherited: :symbol}, @obj.value)

      @obj.value.delete(:Array)
      refute(@obj.validate(auto_correct: false))
      assert(@obj.validate(auto_correct: true))
      assert_equal({Array: [], Inherited: :symbol}, @obj.value)

      @obj.value.delete(:Inherited)
      refute(@obj.validate(auto_correct: true))
    end

    it "checks for the correct type of a set field" do
      @obj.value[:Inherited] = 'string'
      refute(@obj.validate(auto_correct: false))

      @obj.value[:Inherited] = HexaPDF::PDF::Object.new(:symbol)
      assert(@obj.validate(auto_correct: false))

      @obj.value[:Inherited] = Class.new(Array).new([5])
      assert(@obj.validate(auto_correct: false))
    end

    it "checks whether a field needs to be indirect w/wo auto_correct" do
      @obj.value[:Inherited] = HexaPDF::PDF::Object.new(:test, oid: 1)
      refute(@obj.validate(auto_correct: false))
      assert(@obj.validate(auto_correct: true))
      assert_equal(:test, @obj.value[:Inherited])

      @obj.value[:TestClass] = {}
      refute(@obj.validate(auto_correct: false))
      assert(@obj.validate(auto_correct: true))
      assert_equal(1, @obj.value[:TestClass].oid)

      @obj.value[:TestClass] = HexaPDF::PDF::Object.new({})
      assert(@obj.validate(auto_correct: true))
      assert_equal(1, @obj.value[:TestClass].oid)
    end
  end

  describe "delete" do
    it "deletes an entry from the underlying hash value and returns its value" do
      assert_equal(5, @dict.delete(:Other))
      refute(@dict.value.key?(:Other))
    end

    it "returns nil if no entry with the given name exists" do
      assert_nil(@dict.delete(:SomethingUnknown))
    end
  end

  describe "to_hash" do
    it "returns a shallow copy of the value" do
      obj = @dict.to_hash
      refute_equal(obj.object_id, @dict.value.object_id)
      assert_equal(obj, @dict.value)
    end
  end

end
