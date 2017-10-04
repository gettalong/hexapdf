# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/layout/inline_box'

describe HexaPDF::Layout::InlineBox do
  before do
    @box = HexaPDF::Layout::InlineBox.create(width: 10, height: 15, style: {margin: [15, 10]})
  end

  it "draws the wrapped box at the correct position" do
    canvas = Object.new
    block = ->(c, x, y) do
      assert_equal(canvas, c)
      assert_equal(10, x)
      assert_equal(15, y)
    end
    @box.box.stub(:draw, block) do
      @box.draw(canvas, 0, 0)
    end
  end

  it "returns true if the inline box is empty with no drawing operations" do
    assert(@box.empty?)
    refute(HexaPDF::Layout::InlineBox.create(width: 10, height: 15) {}.empty?)
  end

  describe "valign" do
    it "has a default value of :baseline" do
      assert_equal(:baseline, @box.valign)
    end

    it "can be changed on creation" do
      box = HexaPDF::Layout::InlineBox.create(width: 10, height: 15, valign: :test)
      assert_equal(:test, box.valign)
    end
  end

  it "returns the width including margins" do
    assert_equal(30, @box.width)
  end

  it "returns the height including margins" do
    assert_equal(45, @box.height)
  end

  it "returns 0 for x_min" do
    assert_equal(0, @box.x_min)
  end

  it "returns width for x_max" do
    assert_equal(@box.width, @box.x_max)
  end
end
