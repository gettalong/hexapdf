# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/content/canvas'
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
      assert(arc.sweep)
    end
  end


  describe "configure" do
    it "changes the values" do
      arc = HexaPDF::Content::GraphicObject::EndpointArc.new
      arc.configure(x: 1, y: 2, a: 3, b: 4, inclination: 5, large_arc: false, sweep: false)
      assert_equal(1, arc.x)
      assert_equal(2, arc.y)
      assert_equal(3, arc.a)
      assert_equal(4, arc.b)
      assert_equal(5, arc.inclination)
      refute(arc.large_arc)
      refute(arc.sweep)
    end
  end

  describe "draw" do
    it "draws the arc onto the canvas" do
      doc = HexaPDF::Document.new
      page = doc.pages.add_page
      {
        [false, false] => {cx: 50, cy: 25, start_angle: 90, end_angle: 0, sweep: false},
        [false, true] => {cx: 100, cy: 50, start_angle: 180, end_angle: 270, sweep: true},
        [true, false] => {cx: 100, cy: 50, start_angle: 180, end_angle: -90, sweep: false},
        [true, true] => {cx: 50, cy: 25, start_angle: 90, end_angle: 360, sweep: true}
      }.each do |(large_arc, sweep), data|
        canvas = HexaPDF::Content::Canvas.new(page, content: :replace)
        canvas.draw(:arc, a: 50, b: 25, inclination: 0, **data)
        arc_data = page.contents

        canvas = HexaPDF::Content::Canvas.new(page, content: :replace)
        assert(page.contents.empty?)
        canvas.move_to(50.0, 50.0)
        canvas.draw(:endpoint_arc, x: 100, y: 25, a: 50, b: 25, inclination: 0,
                    large_arc: large_arc, sweep: sweep)
        assert_equal(arc_data, page.contents)
      end
    end
  end
end
