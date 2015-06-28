# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/revision'
require 'hexapdf/pdf/object'
require 'hexapdf/pdf/reference'
require 'hexapdf/pdf/xref_section'
require 'stringio'

describe HexaPDF::PDF::Revision do

  before do
    @xref_section = HexaPDF::PDF::XRefSection.new
    @xref_section.add_in_use_entry(2, 0, 5000)
    @xref_section.add_free_entry(3, 0)
    @obj = HexaPDF::PDF::Object.new(:val, oid: 1, gen: 0)
    @ref = HexaPDF::PDF::Reference.new(1, 0)

    @loader = lambda do |entry|
      if entry.type == :free
        HexaPDF::PDF::Object.new(nil, oid: entry.oid, gen: entry.gen)
      else
        HexaPDF::PDF::Object.new(:Test, oid: entry.oid, gen: entry.gen)
      end
    end
    @rev = HexaPDF::PDF::Revision.new({}, xref_section: @xref_section, loader: @loader)
  end

  it "needs the trailer as first argument on initialization" do
    rev = HexaPDF::PDF::Revision.new({})
    assert_equal({}, rev.trailer)
  end

  it "takes an xref section and/or a parser on initialization" do
    rev = HexaPDF::PDF::Revision.new({}, loader: @loader, xref_section: @xref_section)
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
      assert_raises(HexaPDF::Error) { @rev.add(HexaPDF::PDF::Object.new(:val, oid: 2)) }
    end

    it "fails if the given object has an object number of zero" do
      assert_raises(HexaPDF::Error) { @rev.add(HexaPDF::PDF::Object.new(:val)) }
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
      obj = @rev.object(HexaPDF::PDF::Reference.new(2, 0))
      assert_equal(:Test, obj.value)
      assert_equal(2, obj.oid)
      assert_equal(0, obj.gen)
    end

    it "loads an object that is defined in the cross-reference section by using only the object number" do
      obj = @rev.object(2)
      refute_nil(obj)
    end

    it "loads free entries in the cross-reference section as special PDF null objects" do
      obj = @rev.object(HexaPDF::PDF::Reference.new(3, 0))
      assert_nil(obj.value)
    end
  end

  describe "delete" do
    it "deletes objects specified by reference" do
      ref = HexaPDF::PDF::Reference.new(3, 0)
      @rev.delete(ref, mark_as_free: false)
      refute(@rev.object?(ref))
    end

    it "deletes objects specified by object number" do
      @rev.delete(3, mark_as_free: false)
      refute(@rev.object?(3))
    end

    it "marks the object as PDF null object when using mark_as_free=true" do
      assert(5000, @rev.object(2).value)
      @rev.delete(2)
      assert(@rev.object(2).empty?)
    end
  end

  describe "object iteration" do
    it "iterates over all objects via each" do
      @rev.add(@obj)
      assert_equal([@obj, HexaPDF::PDF::Object.new(:Test, oid: 2, gen: 0),
                   HexaPDF::PDF::Object.new(nil, oid: 3, gen: 0)], @rev.each.to_a)
    end
  end

  it "works without a cross-reference section" do
    rev = HexaPDF::PDF::Revision.new({})
    rev.add(@obj)
    assert_equal(@obj, rev.object(@ref))
    assert(rev.object?(@ref))
    assert_equal([@obj], rev.each.to_a)
    rev.delete(@ref, mark_as_free: false)
    refute(rev.object?(@ref))
  end

end
