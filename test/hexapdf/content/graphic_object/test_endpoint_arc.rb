# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/content/canvas'
require 'hexapdf/content/graphic_object'
require 'hexapdf/document'

describe HexaPDF::Content::GraphicObject::EndpointArc do
  describe "initialize" do
    it "creates a default arc representing a line from the current point to the origin" do
      arc = HexaPDF::Content::GraphicObject::EndpointArc.new
      assert_equal(0, arc.x)
      assert_equal(0, arc.y)
      assert_equal(0, arc.a)
      assert_equal(0, arc.b)
      assert_equal(0, arc.inclination)
      assert(arc.large_arc)
      refute(arc.clockwise)
    end
  end

  describe "configure" do
    it "changes the values" do
      arc = HexaPDF::Content::GraphicObject::EndpointArc.new
      arc.configure(x: 1, y: 2, a: 3, b: 4, inclination: 5, large_arc: false, clockwise: true)
      assert_equal(1, arc.x)
      assert_equal(2, arc.y)
      assert_equal(3, arc.a)
      assert_equal(4, arc.b)
      assert_equal(5, arc.inclination)
      refute(arc.large_arc)
      assert(arc.clockwise)
    end
  end

  describe "draw" do
    before do
      @doc = HexaPDF::Document.new
      @page = @doc.pages.add
    end

    it "draws nothing if the endpoint is the same as the current point" do
      canvas = @page.canvas
      canvas.move_to(50, 50)
      canvas.draw(:endpoint_arc, x: 50, y: 50, a: 50, b: 25)
      assert_equal("50 50 m\n", canvas.contents)
    end

    it "draws only a straight line if either one of the semi-axis is zero" do
      canvas = @page.canvas
      canvas.move_to(50, 50)
      canvas.draw(:endpoint_arc, x: 100, y: 50, a: 0, b: 25)
      assert_equal("50 50 m\n100 50 l\n", canvas.contents)
    end

    it "draws the arc onto the canvas" do
      {
        [false, false] => {cx: 100, cy: 50, start_angle: 180, end_angle: 270, clockwise: false},
        [false, true] => {cx: 50, cy: 25, start_angle: 90, end_angle: 0, clockwise: true},
        [true, false] => {cx: 50, cy: 25, start_angle: 90, end_angle: 360, clockwise: false},
        [true, true] => {cx: 100, cy: 50, start_angle: 180, end_angle: -90, clockwise: true},
      }.each do |(large_arc, clockwise), data|
        @page.delete(:Contents)
        canvas = @page.canvas
        canvas.draw(:arc, a: 50, b: 25, inclination: 0, **data)
        arc_data = @page.contents

        canvas.contents.clear
        assert(@page.contents.empty?)
        canvas.move_to(50.0, 50.0)
        canvas.draw(:endpoint_arc, x: 100, y: 25, a: 50, b: 25, inclination: 0,
                    large_arc: large_arc, clockwise: clockwise)
        assert_equal(arc_data, @page.contents)
      end
    end

    it "draws the correct arc even if it is inclined" do
      canvas = @page.canvas
      canvas.draw(:arc, cx: 25, cy: 0, a: 50, b: 25, start_angle: 90, end_angle: 270,
                  inclination: 90, clockwise: false)
      arc_data = @page.contents

      canvas.contents.clear
      canvas.move_to(0.0, 1e-15)
      canvas.draw(:endpoint_arc, x: 50, y: 0, a: 20, b: 10, inclination: 90, large_arc: false,
                  clockwise: false)
      assert_equal(arc_data, @page.contents)
    end
  end
end
