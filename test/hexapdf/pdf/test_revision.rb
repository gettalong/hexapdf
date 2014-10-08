# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/revision'
require 'hexapdf/pdf/object'
require 'hexapdf/pdf/xref_table'
require 'stringio'

describe HexaPDF::PDF::Revision do

  before do
    @xref_table = HexaPDF::PDF::XRefTable.new
    @xref_table[2, 0] = HexaPDF::PDF::XRefTable.entry(:used, pos: 5000)
    @xref_table[3, 0] = HexaPDF::PDF::XRefTable.entry(:free)
    @obj = HexaPDF::PDF::Object.new(:val, oid: 1, gen: 0)
    @ref = HexaPDF::PDF::Reference.new(1, 0)

    @loader = Object.new
    def @loader.load_object_from_io(ref, entry)
      if entry.type == :free
        HexaPDF::PDF::Object.new(nil, oid: ref.oid, gen: ref.gen)
      else
        HexaPDF::PDF::Object.new(:Test, oid: ref.oid, gen: ref.gen)
      end
    end
    @rev = HexaPDF::PDF::Revision.new(@loader, xref_table: @xref_table)
  end

  it "needs store as first parameter on initialization" do
    rev = HexaPDF::PDF::Revision.new(nil)
    assert_equal({}, rev.trailer)
    assert_equal(nil, rev.xref_table)
  end

  it "takes an xref table and/or a trailer on initialization" do
    rev = HexaPDF::PDF::Revision.new(nil, trailer: {hello: 'you'}, xref_table: @xref_table)
    assert_equal({hello: 'you'}, rev.trailer)
    assert_equal(@xref_table, rev.xref_table)
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

    it "loads an object that is defined in the cross-reference table" do
      obj = @rev.object(HexaPDF::PDF::Reference.new(2, 0))
      assert_equal(:Test, obj.value)
      assert_equal(2, obj.oid)
      assert_equal(0, obj.gen)
    end

    it "loads an object that is defined in the cross-reference table by using only the object number" do
      obj = @rev.object(2)
      refute_nil(obj)
    end

    it "loads free entries in the cross-reference table as special PDF null objects" do
      obj = @rev.object(HexaPDF::PDF::Reference.new(3, 0))
      assert_nil(obj.value)
    end
  end

  it "deletes objects via delete" do
    @rev.add(@obj)
    @rev.delete(HexaPDF::PDF::Reference.new(1, 1))
    assert(@rev.object?(@ref))
    @rev.delete(@ref)
    refute(@rev.object?(@ref))

    ref = HexaPDF::PDF::Reference.new(3, 0)
    assert(@rev.object?(ref))
    @rev.delete(3)
    refute(@rev.object?(ref))
  end

  describe "object iteration" do
    it "iterates only the available objects via each_available" do
      assert_equal([], @rev.each_available.to_a)

      @rev.add(@obj)
      other = HexaPDF::PDF::Object.new(:Test2, oid: 313, gen: 2)
      @rev.add(other)
      assert_equal([@obj, other], @rev.each_available.to_a)
    end

    it "iterates over all objects via each" do
      @rev.add(@obj)
      assert_equal([@obj, HexaPDF::PDF::Object.new(:Test, oid: 2, gen: 0),
                   HexaPDF::PDF::Object.new(nil, oid: 3, gen: 0)], @rev.each.to_a)
    end
  end

  it "works without a cross-reference table" do
    rev = HexaPDF::PDF::Revision.new(@loader)
    rev.add(@obj)
    assert_equal(@obj, rev.object(@ref))
    assert(rev.object?(@ref))
    assert_equal([@obj], rev.each.to_a)
    rev.delete(@ref)
    refute(rev.object?(@ref))
  end

end
