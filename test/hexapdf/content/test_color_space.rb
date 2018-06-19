# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/content/color_space'

module CommonColorSpaceTests
  extend Minitest::Spec::DSL

  it "the color object returns the correct color space" do
    assert_equal(@color_space, @color.color_space)
  end

  it "the color space class accepts the color space definition as argument to ::new" do
    assert_equal(1, @color_space.class.method(:new).arity.abs)
  end

  it "the color space responds to :default_color" do
    assert(@color_space.respond_to?(:default_color))
    assert_equal(0, @color_space.method(:default_color).arity)
  end

  it "the color space responds to :color" do
    assert(@color_space.respond_to?(:color))
  end

  it "the color space returns the correct color space family" do
    assert_equal(@color_space_family, @color_space.family)
  end

  it "the color responds to :components" do
    assert(@color.respond_to?(:components))
  end

  it "the color responds to :color_space" do
    assert(@color.respond_to?(:color_space))
  end

  it "the colors are comparable" do
    refute_equal(@color, @other_color)
  end

  it "the components are returned in the correct order" do
    assert_equal(@components, @color_space.color(*@components).components)
  end

end

describe HexaPDF::Content::ColorSpace::Universal do
  include CommonColorSpaceTests

  before do
    @color_space = HexaPDF::Content::ColorSpace::Universal.new([:test])
    @color_space_family = :test
    @color = @color_space.default_color
    @other_color = @color_space.color(128, 5, 6, 7, 8)
    @components = [5, 6, 7, 8]
  end

  it "can be compared to another universal color space" do
    other = HexaPDF::Content::ColorSpace::Universal.new([:other])
    same = HexaPDF::Content::ColorSpace::Universal.new([:test])
    assert_equal(same, @color_space)
    refute_equal(other, @color_space)
  end
end

describe HexaPDF::Content::ColorSpace::DeviceRGB do
  include CommonColorSpaceTests

  before do
    @color_space = HexaPDF::Content::ColorSpace::DeviceRGB.new
    @color_space_family = :DeviceRGB
    @color = @color_space.default_color
    @other_color = @color_space.color(128, 0, 0)
    @components = [0.5, 0.2, 0.3]
  end
end

describe HexaPDF::Content::ColorSpace::DeviceCMYK do
  include CommonColorSpaceTests

  before do
    @color_space = HexaPDF::Content::ColorSpace::DeviceCMYK.new
    @color_space_family = :DeviceCMYK
    @color = @color_space.default_color
    @other_color = @color_space.color(128, 0, 0, 128)
    @components = [0.1, 0.2, 0.3, 0.4]
  end
end

describe HexaPDF::Content::ColorSpace::DeviceGray do
  include CommonColorSpaceTests

  before do
    @color_space = HexaPDF::Content::ColorSpace::DeviceGray.new
    @color_space_family = :DeviceGray
    @color = @color_space.default_color
    @other_color = @color_space.color(128)
    @components = [0.1]
  end
end
