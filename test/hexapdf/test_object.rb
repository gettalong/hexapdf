# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/object'
require 'hexapdf/reference'

describe HexaPDF::Object do
  describe "class.deep_copy" do
    it "handles not-duplicatable classes" do
      assert_equal(5, HexaPDF::Object.deep_copy(5))
      assert_equal(5.5, HexaPDF::Object.deep_copy(5.5))
      assert_equal(nil, HexaPDF::Object.deep_copy(nil))
      assert_equal(true, HexaPDF::Object.deep_copy(true))
      assert_equal(false, HexaPDF::Object.deep_copy(false))
      assert_equal(:Name, HexaPDF::Object.deep_copy(:Name))
    end

    it "handles general, duplicatable classes" do
      x = "test"
      assert_equal("test", HexaPDF::Object.deep_copy(x))
      refute_same(x, HexaPDF::Object.deep_copy(x))
    end

    it "handles arrays" do
      x = [5, 6, [1, 2, 3]]
      y = HexaPDF::Object.deep_copy(x)
      x[2][0] = 4
      assert_equal([5, 6, [1, 2, 3]], y)
    end

    it "handles hashes" do
      x = {a: 5, b: 6, c: {a: 1, b: 2}}
      y = HexaPDF::Object.deep_copy(x)
      x[:c][:a] = 4
      assert_equal({a: 5, b: 6, c: {a: 1, b: 2}}, y)
    end

    it "handles PDF references" do
      x = HexaPDF::Reference.new(1, 2)
      assert_same(x, HexaPDF::Object.deep_copy(x))
    end

    it "handles PDF objects" do
      x = HexaPDF::Object.new("test")
      assert_equal("test", HexaPDF::Object.deep_copy(x))

      x.must_be_indirect = true
      assert_same(x, HexaPDF::Object.deep_copy(x))

      x.must_be_indirect = false
      x.oid = 1
      assert_same(x, HexaPDF::Object.deep_copy(x))
    end
  end

  describe "initialize" do
    it "uses a simple value as is" do
      obj = HexaPDF::Object.new(5)
      assert_equal(5, obj.value)
    end

    it "reuses the data object of a HexaPDF::Object" do
      obj = HexaPDF::Object.new(5)
      assert_same(obj.data, HexaPDF::Object.new(obj).data)
    end

    it "uses a provided PDFData structure" do
      obj = HexaPDF::PDFData.new(5)
      assert_equal(obj, HexaPDF::Object.new(obj).data)
    end
  end

  describe "getters and setters" do
    before do
      @obj = HexaPDF::Object.new(5)
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

  describe "null?" do
    it "works for nil values" do
      assert(HexaPDF::Object.new(nil).null?)
    end
  end

  describe "validate" do
    it "invokes perform_validation correctly via #validate" do
      obj = HexaPDF::Object.new(5)
      invoked = {}
      obj.define_singleton_method(:perform_validation) do |&block|
        invoked[:method] = true
        block.call("error", true)
      end
      assert(obj.validate {|*a| invoked[:block] = a})
      assert_equal([:method, :block], invoked.keys)
      assert_equal(["error", true], invoked[:block])

      refute(obj.validate(auto_correct: false))
    end

    it "stops validating on an uncorrectable problem" do
      obj = HexaPDF::Object.new(5)
      invoked = {}
      obj.define_singleton_method(:perform_validation) do |&block|
        invoked[:before] = true
        block.call("error", false)
        invoked[:after] = true
      end
      refute(obj.validate {|*a| invoked[:block] = a})
      refute(invoked.key?(:after))
    end
  end

  it "can represent itself during inspection" do
    obj = HexaPDF::Object.new(5, oid: 5)
    assert_match(/\[5, 0\].*value=5/, obj.inspect)
  end

  it "can be compared to another object" do
    obj = HexaPDF::Object.new(5, oid: 5)

    assert_equal(obj, HexaPDF::Object.new(obj))
    refute_equal(obj, HexaPDF::Object.new(5, oid: 5))
    refute_equal(obj, HexaPDF::Object.new(6, oid: 5))
    refute_equal(obj, HexaPDF::Object.new(5, oid: 1))
    refute_equal(obj, HexaPDF::Object.new(5, oid: 5, gen: 1))
  end

  it "works correctly as hash key, is interchangable in this regard with Reference objects" do
    hash = {}
    hash[HexaPDF::Reference.new(1)] = :one
    hash[HexaPDF::Object.new(:val, oid: 2)] = :two
    assert_equal(:one, hash[HexaPDF::Reference.new(1, 0)])
    assert_equal(:one, hash[HexaPDF::Object.new(:data, oid: 1)])
    assert_equal(:two, hash[HexaPDF::Reference.new(2)])
    assert_equal(:two, hash[HexaPDF::Object.new(:data, oid: 2)])
  end

  it "can be sorted together with Reference objects" do
    a = HexaPDF::Object.new(:data, oid: 1)
    b = HexaPDF::Object.new(:data, oid: 1, gen: 1)
    c = HexaPDF::Reference.new(5, 7)
    assert_equal([a, b, c], [b, c, a].sort)
  end

  describe "deep_copy" do
    it "creates an independent object" do
      obj = HexaPDF::Object.new(a: "mystring", b: HexaPDF::Reference.new(1, 0), c: 5)
      copy = obj.deep_copy
      refute_equal(copy, obj)
      assert_equal(copy.value, obj.value)
      refute_same(copy.value[:a], obj.value[:a])
    end
  end

  it "validates that the object is indirect if it must be indirect" do
    doc = Object.new
    def doc.add(obj) obj.oid = 1 end
    obj = HexaPDF::Object.new(6, document: doc)

    obj.validate
    assert_equal(0, obj.oid)

    obj.must_be_indirect = true
    obj.validate
    assert_equal(1, obj.oid)
  end
end
