# -*- encoding: utf-8 -*-

require 'test_helper'
require_relative '../content/common'
require 'hexapdf/document'
require 'hexapdf/layout/text_fragment'

# Numeric values were manually calculated using the information from the AFM file.
describe HexaPDF::Layout::TextFragment do
  before do
    @doc = HexaPDF::Document.new
    @font = @doc.fonts.load("Times", custom_encoding: true)
  end

  def setup_fragment(items, text_rise = 0)
    style = HexaPDF::Layout::Style.new(font: @font, font_size: 20,
                                       horizontal_scaling: 200, character_spacing: 1,
                                       word_spacing: 2, text_rise: text_rise)
    @fragment = HexaPDF::Layout::TextFragment.new(items: items, style: style)
  end

  it "creates a TextFragment from text and options" do
    frag = HexaPDF::Layout::TextFragment.create("Tom", font: @font, font_size: 20,
                                                font_features: {kern: true})
    assert_equal(4, frag.items.length)
    assert_equal(36.18, frag.width)
    assert_equal(13.66 + 4.34, frag.height)
  end

  it "returns :text for valign" do
    assert_equal(:text, setup_fragment([]).valign)
  end

  describe "draw" do
    def setup_with_style(**styles)
      setup_fragment(@font.decode_utf8('H'), 2)
      styles.each {|name, value| @fragment.style.send(name, value)}
      @canvas = @doc.pages.add.canvas
      @fragment.draw(@canvas, 10, 15)
    end

    def assert_draw_operators(*args, front: [], middle: args, back: [])
      ops = [
        *front,
        [:begin_text],
        [:set_text_matrix, [1, 0, 0, 1, 10, 15]],
        [:set_font_and_size, [:F1, 20]],
        [:set_leading, [24.0]],
        [:set_horizontal_scaling, [200]],
        [:set_character_spacing, [1]],
        [:set_word_spacing, [2]],
        [:set_text_rise, [2]],
        *middle,
        [:show_text_with_positioning, [['!']]],
        *back,
      ].compact
      assert_operators(@canvas.contents, ops)
    end

    it "draws text onto the canvas" do
      setup_with_style
      assert_draw_operators
    end

    it "draws styled filled text" do
      setup_with_style(fill_color: 0.5, fill_alpha: 0.5)
      assert_draw_operators([:set_graphics_state_parameters, [:GS1]],
                            [:set_device_gray_non_stroking_color, [0.5]])
      assert_equal({Type: :ExtGState, CA: 1, ca: 0.5}, @canvas.resources[:ExtGState][:GS1])
    end

    it "draws style stroked text" do
      setup_with_style(text_rendering_mode: :stroke,
                       stroke_color: [1.0, 0, 0], stroke_alpha: 0.5, stroke_width: 2,
                       stroke_cap_style: :round, stroke_join_style: :round, stroke_miter_limit: 5,
                       stroke_dash_pattern: [1, 2, 3])
      assert_draw_operators([:set_text_rendering_mode, [1]],
                            [:set_graphics_state_parameters, [:GS1]],
                            [:set_device_rgb_stroking_color, [1, 0, 0]],
                            [:set_line_width, [2]],
                            [:set_line_cap_style, [1]],
                            [:set_line_join_style, [1]],
                            [:set_miter_limit, [5]],
                            [:set_line_dash_pattern, [[1, 2, 3], 0]])
      assert_equal({Type: :ExtGState, CA: 0.5, ca: 1}, @canvas.resources[:ExtGState][:GS1])
    end

    it "invokes the underlay callback" do
      setup_with_style(underlay_callback: proc { @canvas.stroke_color(0.5) })
      assert_draw_operators(front: [[:save_graphics_state],
                                    [:concatenate_matrix, [1, 0, 0, 1, 10, 15 + @fragment.y_min]],
                                    [:set_device_gray_stroking_color, [0.5]],
                                    [:restore_graphics_state]])
    end

    it "invokes the overlay callback" do
      setup_with_style(overlay_callback: proc { @canvas.stroke_color(0.5) })
      assert_draw_operators(back: [[:end_text],
                                   [:save_graphics_state],
                                   [:concatenate_matrix, [1, 0, 0, 1, 10, 15 + @fragment.y_min]],
                                   [:set_device_gray_stroking_color, [0.5]],
                                   [:restore_graphics_state]])
    end
  end

  describe "empty fragment" do
    before do
      setup_fragment([])
    end

    it "calculates the x_min" do
      assert_equal(0, @fragment.x_min)
    end

    it "calculates the x_max" do
      assert_equal(0, @fragment.x_max)
    end

    it "calculates the y_min" do
      assert_equal(-4.34, @fragment.y_min)
    end

    it "calculates the y_max" do
      assert_equal(13.66, @fragment.y_max)
    end

    it "calculates the width" do
      assert_equal(0, @fragment.width)
    end

    it "calculates the height" do
      assert_equal(13.66 + 4.34, @fragment.height)
    end

    it "draws nothing" do
      canvas = @doc.pages.add.canvas
      @fragment.draw(canvas, 10, 15)
      assert_operators(canvas.contents, [])
    end
  end

  describe "normal text" do
    before do
      setup_fragment(@font.decode_utf8("Hal lo").insert(2, -35).insert(1, -10))
    end

    it "calculates the x_min" do
      assert_in_delta(0.76, @fragment.x_min)
    end

    it "calculates the x_max" do
      assert_in_delta(116.68 - 1.2 - 2, @fragment.x_max)
    end

    it "calculates the exact y_min" do
      assert_in_delta(-0.2, @fragment.exact_y_min)
    end

    it "calculates the exact y_max" do
      assert_in_delta(13.66, @fragment.exact_y_max)
    end

    it "calculates the y_min" do
      assert_in_delta(-4.34, @fragment.y_min)
    end

    it "calculates the y_max" do
      assert_in_delta(13.66, @fragment.y_max)
    end

    it "calculates the width" do
      assert_in_delta(116.68, @fragment.width)
    end

    it "calculates the height" do
      assert_in_delta(13.66 + 4.34, @fragment.height)
    end
  end

  describe "with a positive text rise" do
    before do
      setup_fragment(@font.decode_utf8("l,"), 4)
    end

    it "calculates the y_min" do
      assert_in_delta(-4.34 + 4, @fragment.y_min)
    end

    it "calculates the y_max" do
      assert_in_delta(13.66 + 4, @fragment.y_max)
    end

    it "calculates the height" do
      assert_in_delta(13.66 + 4 + 0.34, @fragment.height)
    end
  end

  describe "with a negative text rise" do
    before do
      setup_fragment(@font.decode_utf8("l,"), -15)
    end

    it "calculates the y_min" do
      assert_in_delta(-4.34 - 15, @fragment.y_min)
    end

    it "calculates the y_max" do
      assert_in_delta(13.66 - 15, @fragment.y_max)
    end

    it "calculates the height" do
      assert_in_delta(4.34 + 15, @fragment.height)
    end
  end

  describe "with a glyph without outline as last item" do
    before do
      setup_fragment(@font.decode_utf8("H "))
    end

    it "calculates the x_max" do
      assert_in_delta(46.88 - 2 - 4, @fragment.x_max)
    end

    it "calculates the width" do
      assert_in_delta(46.88, @fragment.width)
    end
  end

  describe "with a glyph with x_min < 0 and x_max > width as first and last item" do
    before do
      setup_fragment(@font.decode_utf8("\u{2044}o\u{2044}".unicode_normalize(:nfd)))
    end

    it "calculates the x_min" do
      assert_in_delta(-6.72, @fragment.x_min)
    end

    it "calculates the x_max" do
      assert_in_delta(39.36 + 6.56 - 2, @fragment.x_max)
    end

    it "calculates the width" do
      assert_in_delta(39.36, @fragment.width)
    end
  end

  describe "with positive kerning values as first and last items" do
    before do
      setup_fragment([100, 100] + @font.decode_utf8("Hallo") + [100, 100])
    end

    it "calculates the x_min" do
      assert_in_delta(-7.24, @fragment.x_min)
    end

    it "calculates the x_max" do
      assert_in_delta(82.88 - 1.2 - 2 - -4 - -4, @fragment.x_max)
    end

    it "calculates the width" do
      assert_in_delta(82.88, @fragment.width)
    end
  end

  it "can be inspected" do
    frag = setup_fragment(@font.decode_utf8("H"))
    assert_match(/:H/, frag.inspect)
  end
end
