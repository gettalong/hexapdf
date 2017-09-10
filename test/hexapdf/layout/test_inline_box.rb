# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/layout/inline_box'

describe HexaPDF::Layout::InlineBox do
  before do
    @box = HexaPDF::Layout::InlineBox.new(10, 15) {|box, canvas| [box, canvas]}
  end

  describe "draw" do
    before do
      @canvas = Object.new
      @canvas.define_singleton_method(:translate) {|x, y, &block| [x, y, block.call] }
    end

    it "returns the value of the drawing block" do
      assert_equal([1, 2, [@box, @canvas]], @box.draw(@canvas, 1, 2))
    end

    it "returns nil if it is just a placeholder box" do
      assert_nil(HexaPDF::Layout::InlineBox.new(10, 15).draw(@canvas, 1, 2))
    end
  end

  it "returns true if the inline box is just a place holder with no drawing operation" do
    refute(@box.placeholder?)
    assert(HexaPDF::Layout::InlineBox.new(10, 15).placeholder?)
  end

  describe "valign" do
    it "has a default value of :baseline" do
      assert_equal(:baseline, @box.valign)
    end

    it "can be changed on creation" do
      box = HexaPDF::Layout::InlineBox.new(10, 15, valign: :test) {}
      assert_equal(:test, box.valign)
    end
  end

  it "returns 0 for x_min" do
    assert_equal(0, @box.x_min)
  end

  it "returns width for x_max" do
    assert_equal(10, @box.x_max)
  end
end
