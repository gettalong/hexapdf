# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/reference'

describe HexaPDF::PDF::Reference do

  it "correctly assigns oid and gen on initialization" do
    r = HexaPDF::PDF::Reference.new(5, 7)
    assert_equal(5, r.oid)
    assert_equal(7, r.gen)
  end

  it "raises an error when invalid objects are supplied on initialization" do
    assert_raises(HexaPDF::Error) { HexaPDF::PDF::Reference.new(5.0, 7) }
  end

  it "is comparable to itself" do
    assert_equal(HexaPDF::PDF::Reference.new(5, 7), HexaPDF::PDF::Reference.new(5, 7))
    refute_equal(HexaPDF::PDF::Reference.new(5, 7), HexaPDF::PDF::Reference.new(5, 8))
    refute_equal(HexaPDF::PDF::Reference.new(5, 7), HexaPDF::PDF::Reference.new(4, 7))
  end

  it "behaves correctly as hash key" do
    h = {}
    h[HexaPDF::PDF::Reference.new(5, 7)] = true
    assert(h.has_key?(HexaPDF::PDF::Reference.new(5, 7)))
    refute(h.has_key?(HexaPDF::PDF::Reference.new(5, 8)))
  end

  it "shows oid and gen on inspection" do
    assert_match(/\[5, 7\]/, HexaPDF::PDF::Reference.new(5, 7).inspect)
  end

end
