# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/reference'

class PDFReferenceTest < Minitest::Test

  include HexaPDF::PDF

  def test_initialize_and_accessors
    r = Reference.new(5, 7)
    assert_equal(5, r.oid)
    assert_equal(7, r.gen)

    assert_raises(HexaPDF::Error) { Reference.new(5.0, 7) }
  end

  def test_equality
    assert_equal(Reference.new(5, 7), Reference.new(5, 7))
    refute_equal(Reference.new(5, 7), Reference.new(5, 8))
    refute_equal(Reference.new(5, 7), Reference.new(4, 7))
  end

  def test_hash
    h = {}
    h[Reference.new(5, 7)] = true
    assert(h.has_key?(Reference.new(5, 7)))
    refute(h.has_key?(Reference.new(5, 8)))
  end

  def test_inspect
    assert_match(/\[5, 7\]/, Reference.new(5, 7).inspect)
  end

end
