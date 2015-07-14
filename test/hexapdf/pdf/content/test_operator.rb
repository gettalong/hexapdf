# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/content/operator'
require 'hexapdf/pdf/content/processor'

describe HexaPDF::PDF::Content::Operator do
  before do
    @processor = HexaPDF::PDF::Content::Processor.new({})
  end

  def call(name, *operands)
    HexaPDF::PDF::Content::Operator.const_get(name).call(@processor, *operands)
  end

  it "saves the graphics state" do
    call(:SaveGraphicsState)
    @processor.graphics_state.line_width = 10
    @processor.graphics_state.restore
    assert_equal(1, @processor.graphics_state.line_width)
  end

  it "restores the graphics state" do
    @processor.graphics_state.save
    @processor.graphics_state.line_width = 10
    call(:RestoreGraphicsState)
    assert_equal(1, @processor.graphics_state.line_width)
  end

  it "concatenates the ctm" do
    call(:ConcatenateMatrix, 1, 0, 0, 1, 5, 10)
    assert_equal(5, @processor.graphics_state.ctm.e)
    assert_equal(10, @processor.graphics_state.ctm.f)
  end

  it "sets the line width" do
    call(:SetLineWidth, 10)
    assert_equal(10, @processor.graphics_state.line_width)
  end

  it "sets the line cap" do
    call(:SetLineCap, HexaPDF::PDF::Content::LineCapStyle::ROUND_CAP)
    assert_equal(HexaPDF::PDF::Content::LineCapStyle::ROUND_CAP,
                 @processor.graphics_state.line_cap_style)
  end

  it "sets the line join" do
    call(:SetLineJoin, HexaPDF::PDF::Content::LineJoinStyle::ROUND_JOIN)
    assert_equal(HexaPDF::PDF::Content::LineJoinStyle::ROUND_JOIN,
                 @processor.graphics_state.line_join_style)
  end

  it "sets the miter limit" do
    call(:SetMiterLimit, 100)
    assert_equal(100, @processor.graphics_state.miter_limit)
  end

  it "sets the line dash pattern" do
    call(:SetLineDashPattern, [3, 4], 5)
    assert_equal(HexaPDF::PDF::Content::LineDashPattern.new([3, 4], 5),
                 @processor.graphics_state.line_dash_pattern)
  end

  it "sets the rendering intent" do
    call(:SetRenderingIntent, HexaPDF::PDF::Content::RenderingIntent::SATURATION)
    assert_equal(HexaPDF::PDF::Content::RenderingIntent::SATURATION,
                 @processor.graphics_state.rendering_intent)
  end

  describe "SetGraphicsStateParameters" do
    it "applies parameters from an ExtGState dictionary" do
      @processor.resources[:ExtGState] = {Name: {LW: 10, CA: 0.5}}
      call(:SetGraphicsStateParameters, :Name)
      assert_equal(10, @processor.graphics_state.line_width)
      assert_equal(0.5, @processor.graphics_state.stroking_alpha)
    end

    it "fails if the resources dictionary doesn't have an ExtGState entry" do
      assert_raises(HexaPDF::Error) { call(:SetGraphicsStateParameters, :Name) }
    end

    it "fails if the ExtGState resources doesn't have the specified dictionary" do
      @processor.resources[:ExtGState] = {}
      assert_raises(HexaPDF::Error) { call(:SetGraphicsStateParameters, :Name) }
    end
  end

  it "sets the stroking color space" do
    call(:SetStrokingColorSpace, :DeviceRGB)
    assert_equal(@processor.color_space(:DeviceRGB), @processor.graphics_state.stroking_color_space)
  end

  it "sets the non stroking color space" do
    call(:SetNonStrokingColorSpace, :DeviceRGB)
    assert_equal(@processor.color_space(:DeviceRGB),
                 @processor.graphics_state.non_stroking_color_space)
  end

  it "sets the stroking color" do
    call(:SetStrokingColor, 128)
    assert_equal(@processor.color_space(:DeviceGray).color(128),
                 @processor.graphics_state.stroking_color)
  end

  it "sets the non stroking color" do
    call(:SetNonStrokingColor, 128)
    assert_equal(@processor.color_space(:DeviceGray).color(128),
                 @processor.graphics_state.non_stroking_color)
  end

  it "sets the DeviceGray stroking color" do
    call(:SetDeviceGrayStrokingColor, 128)
    assert_equal(@processor.color_space(:DeviceGray).color(128),
                 @processor.graphics_state.stroking_color)
  end

  it "sets the DeviceGray non stroking color" do
    call(:SetDeviceGrayNonStrokingColor, 128)
    assert_equal(@processor.color_space(:DeviceGray).color(128),
                 @processor.graphics_state.non_stroking_color)
  end

  it "sets the DeviceRGB stroking color" do
    call(:SetDeviceRGBStrokingColor, 128, 0, 128)
    assert_equal(@processor.color_space(:DeviceRGB).color(128, 0, 128),
                 @processor.graphics_state.stroking_color)
  end

  it "sets the DeviceRGB non stroking color" do
    call(:SetDeviceRGBNonStrokingColor, 128, 0, 128)
    assert_equal(@processor.color_space(:DeviceRGB).color(128, 0, 128),
                 @processor.graphics_state.non_stroking_color)
  end

  it "sets the DeviceCMYK stroking color" do
    call(:SetDeviceCMYKStrokingColor, 128, 0, 128, 128)
    assert_equal(@processor.color_space(:DeviceCMYK).color(128, 0, 128, 128),
                 @processor.graphics_state.stroking_color)
  end

  it "sets the DeviceCMYK non stroking color" do
    call(:SetDeviceCMYKNonStrokingColor, 128, 0, 128, 128)
    assert_equal(@processor.color_space(:DeviceCMYK).color(128, 0, 128, 128),
                 @processor.graphics_state.non_stroking_color)
  end

  it "changes the graphics object to path for begin path operations" do
    call(:BeginPath, 128, 0)
    assert(@processor.in_path?)
  end

  it "changes the graphics object to none for end path operations" do
    @processor.graphics_object = :path
    call(:EndPath)
    refute(@processor.in_path?)
  end

  it "changes the graphics object to clipping_path for clip path operations" do
    call(:ClipPath)
    assert_equal(:clipping_path, @processor.graphics_object)
  end
end
