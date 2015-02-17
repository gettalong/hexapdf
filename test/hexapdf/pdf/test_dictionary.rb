# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/dictionary'

describe HexaPDF::PDF::Dictionary do

  def deref(obj)
    obj
  end

  before do
    @test_class = Class.new(HexaPDF::PDF::Dictionary)
    @test_class.define_field(:Boolean, type: [TrueClass, FalseClass], default: false, version: '1.3')
    @test_class.define_field(:Array, type: 'Array', required: true, default: [], indirect: true)
    @test_class.define_field(:TestClass, type: @test_class)

    @dict = @test_class.new({:Array => [3, 4], :Other => 5, :Object => HexaPDF::PDF::Object.new(:obj)},
                            document: self)
  end

  describe "class methods" do
    it "allows defining fields and retrieving their info" do
      refute_nil(@test_class.field(:Boolean))
      assert_equal([TrueClass, FalseClass], @test_class.field(:Boolean).type)
      assert_equal(:'1.3', @test_class.field(:Boolean).version)
      assert_equal(false, @test_class.field(:Boolean).dupped_default)
      refute(@test_class.field(:Boolean).required?)

      assert(@test_class.field(:Array).required?)
      assert_equal([Array], @test_class.field(:Array).type)
      assert_equal([], @test_class.field(:Array).dupped_default)
      assert(@test_class.field(:Array).indirect)
    end

    it "can retrieve fields from parent classes" do
      @inherited_class = Class.new(@test_class)

      assert(@inherited_class.field(:Boolean))
      refute(@inherited_class.field(:Unknown))
    end
  end

  it "fails initialization if the value is not a hash" do
    assert_raises(HexaPDF::Error) { HexaPDF::PDF::Dictionary.new(:Name) }
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

end
