# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/revision'
require 'hexapdf/object'
require 'hexapdf/reference'
require 'hexapdf/xref_section'
require 'stringio'

describe HexaPDF::Revision do
  before do
    @xref_section = HexaPDF::XRefSection.new
    @xref_section.add_in_use_entry(2, 0, 5000)
    @xref_section.add_free_entry(3, 0)
    @obj = HexaPDF::Object.new(:val, oid: 1, gen: 0)
    @ref = HexaPDF::Reference.new(1, 0)

    @loader = lambda do |entry|
      if entry.type == :free
        HexaPDF::Object.new(nil, oid: entry.oid, gen: entry.gen)
      else
        HexaPDF::Object.new(:Test, oid: entry.oid, gen: entry.gen)
      end
    end
    @rev = HexaPDF::Revision.new({}, xref_section: @xref_section, loader: @loader)
  end

  it "needs the trailer as first argument on initialization" do
    rev = HexaPDF::Revision.new({})
    assert_equal({}, rev.trailer)
  end

  it "takes an xref section and/or a parser on initialization" do
    rev = HexaPDF::Revision.new({}, loader: @loader, xref_section: @xref_section)
    assert_equal(:Test, rev.object(2).value)
  end

  it "returns the next free object number" do
    assert_equal(4, @rev.next_free_oid)
    @obj.oid = 4
    @rev.add(@obj)
    assert_equal(5, @rev.next_free_oid)
  end

  describe "add" do
    it "works correctly" do
      @rev.add(@obj)
      assert(@rev.object?(@ref))
    end

    it "also returns the supplied object" do
      assert_equal(@obj, @rev.add(@obj))
    end

    it "fails if the revision already has an object with the same object number" do
      @rev.add(@obj)
      assert_raises(HexaPDF::Error) { @rev.add(@obj) }
      assert_raises(HexaPDF::Error) { @rev.add(HexaPDF::Object.new(:val, oid: 2)) }
    end

    it "fails if the given object has an object number of zero" do
      assert_raises(HexaPDF::Error) { @rev.add(HexaPDF::Object.new(:val)) }
    end
  end

  describe "xref" do
    it "returns the xref structure" do
      assert_equal(@xref_section[2, 0], @rev.xref(HexaPDF::Reference.new(2, 0)))
      assert_equal(@xref_section[2, 0], @rev.xref(2))
    end

    it "returns nil if no xref entry is found" do
      assert_nil(@rev.xref(@ref))
      assert_nil(@rev.xref(1))
    end
  end

  describe "object" do
    it "returns nil if no object is found" do
      assert_nil(@rev.object(@ref))
      assert_nil(@rev.object(1))
    end

    it "returns an object that was added before" do
      @rev.add(@obj)
      assert_equal(@obj, @rev.object(@ref))
      assert_equal(@obj, @rev.object(1))
    end

    it "loads an object that is defined in the cross-reference section" do
      obj = @rev.object(HexaPDF::Reference.new(2, 0))
      assert_equal(:Test, obj.value)
      assert_equal(2, obj.oid)
      assert_equal(0, obj.gen)
    end

    it "loads an object that is defined in the cross-reference section using the object number" do
      obj = @rev.object(2)
      refute_nil(obj)
    end

    it "loads free entries in the cross-reference section as special PDF null objects" do
      obj = @rev.object(HexaPDF::Reference.new(3, 0))
      assert_nil(obj.value)
    end
  end

  describe "update" do
    before do
      @rev.add(@obj)
    end

    it "updates the object if it has the same data instance" do
      x = HexaPDF::Object.new(@obj.data)
      y = @rev.update(x)
      assert_same(x, y)
      refute_same(x, @obj)
      assert_same(x, @rev.object(@ref))
    end

    it "doesn't update the object if it refers to a different data instance" do
      x = HexaPDF::Object.new(:value, oid: 5)
      assert_nil(@rev.update(x))
      x.data.oid = 1
      assert_nil(@rev.update(x))
    end
  end

  describe "delete" do
    before do
      @rev.add(@obj)
    end

    it "deletes objects specified by reference" do
      @rev.delete(@ref, mark_as_free: false)
      refute(@rev.object?(@ref))
      assert(@obj.null?)
      assert_raises(HexaPDF::Error) { @obj.document }
    end

    it "deletes objects specified by object number" do
      @rev.delete(@ref.oid, mark_as_free: false)
      refute(@rev.object?(@ref.oid))
      assert(@obj.null?)
      assert_raises(HexaPDF::Error) { @obj.document }
    end

    it "marks the object as PDF null object when using mark_as_free=true" do
      refute(@obj.null?)
      @rev.delete(@ref)
      assert(@rev.object(@ref).null?)
      assert(@obj.null?)
      assert_raises(HexaPDF::Error) { @obj.document }
    end
  end

  describe "object iteration" do
    it "iterates over all objects via each" do
      @rev.add(@obj)
      obj2 = @rev.object(2)
      obj3 = @rev.object(3)
      assert_equal([@obj, obj2, obj3], @rev.each.to_a)
    end

    it "iterates only over loaded objects" do
      obj = @rev.object(2)
      assert_equal([obj], @rev.each(only_loaded: true).to_a)
    end
  end

  it "works without a cross-reference section" do
    rev = HexaPDF::Revision.new({})
    rev.add(@obj)
    assert_equal(@obj, rev.object(@ref))
    assert(rev.object?(@ref))
    assert_equal([@obj], rev.each.to_a)
    rev.delete(@ref, mark_as_free: false)
    refute(rev.object?(@ref))
  end

  it "can iterate over all modified objects" do
    obj = @rev.object(2)
    assert_equal([], @rev.each_modified_object.to_a)
    obj.value = :Other
    @rev.add(@obj)
    assert_equal([obj, @obj], @rev.each_modified_object.to_a)
  end
end
