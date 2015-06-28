# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/object'
require 'hexapdf/pdf/reference'

describe HexaPDF::PDF::Object do

  describe "initialize" do
    it "uses a simple value as is" do
      obj = HexaPDF::PDF::Object.new(5)
      assert_equal(5, obj.value)
    end

    it "reuses the data object of a HexaPDF::PDF::Object" do
      obj = HexaPDF::PDF::Object.new(5)
      assert_same(obj.data, HexaPDF::PDF::Object.new(obj).data)
    end

    it "uses a provided PDFData structure" do
      obj = HexaPDF::PDF::PDFData.new(5)
      assert_equal(obj, HexaPDF::PDF::Object.new(obj).data)
    end
  end

  describe "getters and setters" do
    before do
      @obj = HexaPDF::PDF::Object.new(5)
    end

    it "can get/set oid" do
      @obj.oid = 7
      assert_equal(7, @obj.oid)
    end

    it "can get/set gen" do
      @obj.gen = 7
      assert_equal(7, @obj.gen)
    end

    it "can get/set the value" do
      @obj.value = :test
      assert_equal(:test, @obj.value)
    end
  end

  describe "empty" do
    it "works for nil values" do
      assert(HexaPDF::PDF::Object.new(nil).empty?)
    end

    it "works for empty values" do
      assert(HexaPDF::PDF::Object.new("").empty?)
      assert(HexaPDF::PDF::Object.new(:"").empty?)
      assert(HexaPDF::PDF::Object.new([]).empty?)
      assert(HexaPDF::PDF::Object.new({}).empty?)
    end
  end

  describe "validation" do
    it "allows nesting validate calls" do
      nested_klass = Class.new(HexaPDF::PDF::Object)
      nested_klass.define_validator do |obj, &block|
        block.call("error", false)
      end
      klass = Class.new(HexaPDF::PDF::Object)
      klass.define_validator do |obj, &block|
        nested_klass.new(5).validate do |msg, correctable|
          block.call("nested:#{msg}", correctable)
        end
      end
      obj = klass.new(5)
      obj.validate do |msg, correctable|
        assert_equal("nested:error", msg)
        refute(correctable)
      end
    end

    it "allows adding and retrieving class level validators for instance methods" do
      klass = Class.new(HexaPDF::PDF::Object)
      klass.define_validator(:validate_me)
      assert_equal([:validate_basic_object, :validate_me], klass.each_validator.to_a)
    end

    it "allows adding and retrieving arbitrary class level validators" do
      klass = Class.new(HexaPDF::PDF::Object)
      validate_me = lambda {|obj, auto_correct:|}
      klass.define_validator(&validate_me)
      assert_equal([:validate_basic_object, validate_me], klass.each_validator.to_a)
    end

    it "uses validators defined for the class or one of its superclasses" do
      klass = Class.new(HexaPDF::PDF::Object)
      klass.define_validator(:validate_me)
      subklass = Class.new(klass)
      subklass.define_validator(:validate_me_too)
      assert_equal([:validate_basic_object, :validate_me, :validate_me_too],
                   subklass.each_validator.to_a)
    end

    it "invokes the validators correctly via #validate" do
      invoked = {}
      klass = Class.new(HexaPDF::PDF::Object)
      klass.send(:define_method, :validate_me) do |&block|
        invoked[:method] = true
        block.call("error", true)
      end
      klass.define_validator(:validate_me)
      klass.define_validator do |obj|
        assert_kind_of(HexaPDF::PDF::Object, obj)
        invoked[:block] = true
      end
      assert(klass.new(:test).validate)
      assert_equal({method: true, block: true}, invoked)

      invoked = {}
      refute(klass.new(:test).validate(auto_correct: false))
      assert_equal({method: true}, invoked)

      invoked = {}
      klass.send(:undef_method, :validate_me)
      klass.send(:define_method, :validate_me) do |&block|
        invoked[:klass] = true
        block.call("error", false)
      end
      refute(klass.new(:test).validate(auto_correct: true))
      assert_equal({klass: true}, invoked)
    end
  end

  it "can represent itself during inspection" do
    obj = HexaPDF::PDF::Object.new(5, oid: 5)
    assert_match(/\[5, 0\].*value=5/, obj.inspect)
  end

  it "can be compared to another object" do
    obj = HexaPDF::PDF::Object.new(5, oid: 5)

    assert_equal(obj, HexaPDF::PDF::Object.new(obj))
    refute_equal(obj, HexaPDF::PDF::Object.new(5, oid: 5))
    refute_equal(obj, HexaPDF::PDF::Object.new(6, oid: 5))
    refute_equal(obj, HexaPDF::PDF::Object.new(5, oid: 1))
    refute_equal(obj, HexaPDF::PDF::Object.new(5, oid: 5, gen: 1))
  end

  it "works correctly as hash key, is interchangable in this regard with Reference objects" do
    hash = {}
    hash[HexaPDF::PDF::Reference.new(1)] = :one
    hash[HexaPDF::PDF::Object.new(:val, oid: 2)] = :two
    assert_equal(:one, hash[HexaPDF::PDF::Reference.new(1, 0)])
    assert_equal(:one, hash[HexaPDF::PDF::Object.new(:data, oid: 1)])
    assert_equal(:two, hash[HexaPDF::PDF::Reference.new(2)])
    assert_equal(:two, hash[HexaPDF::PDF::Object.new(:data, oid: 2)])
  end

  it "can be sorted together with Reference objects" do
    a = HexaPDF::PDF::Object.new(:data, oid: 1)
    b = HexaPDF::PDF::Object.new(:data, oid: 1, gen: 1)
    c = HexaPDF::PDF::Reference.new(5, 7)
    assert_equal([a, b, c], [b, c, a].sort)
  end

  it "validates that the object is indirect if it must be indirect" do
    doc = Object.new
    def doc.add(obj) obj.oid = 1 end
    obj = HexaPDF::PDF::Object.new(6, document: doc)

    obj.validate
    assert_equal(0, obj.oid)

    obj.must_be_indirect = true
    obj.validate
    assert_equal(1, obj.oid)
  end
end
