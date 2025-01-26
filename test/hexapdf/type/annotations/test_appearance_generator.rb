# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'

describe HexaPDF::Type::Annotations::AppearanceGenerator do
  before do
    @doc = HexaPDF::Document.new
  end

  describe "create" do
    it "fails for unsupported annotation types" do
      annot = @doc.add({Type: :Annot, Subtype: :Unknown})
      error = assert_raises(HexaPDF::Error) do
        HexaPDF::Type::Annotations::AppearanceGenerator.new(annot).create_appearance
      end
      assert_match(/Unknown.*not yet supported/, error.message)
    end
  end

  describe "line" do
    before do
      @line = @doc.add({Type: :Annot, Subtype: :Line, L: [100, 100, 200, 100], C: [0]})
      @generator = HexaPDF::Type::Annotations::AppearanceGenerator.new(@line)
    end

    it "sets the print flag and unsets the hidden flag" do
      @line.flag(:hidden)
      @generator.create_appearance
      assert(@line.flagged?(:print))
      refute(@line.flagged?(:hidden))
    end

    it "creates a simple line" do
      @generator.create_appearance
      assert_equal([96, 96, 204, 104], @line[:Rect])
      assert_equal([96, 96, 204, 104], @line.appearance[:BBox])
      assert_operators(@line.appearance.stream,
                       [[:concatenate_matrix, [1.0, 0.0, -0.0, 1.0, 100, 100]],
                        [:move_to, [0, 0]],
                        [:line_to, [100.0, 0]],
                        [:stroke_path]])
    end

    it "creates a rotated line" do
      @line.line(100, 100, 50, 150)
      @generator.create_appearance
      assert_equal([46, 96, 104, 154], @line[:Rect])
      assert_operators(@line.appearance.stream,
                       [[:concatenate_matrix, [-0.707107, 0.707107, -0.707107, -0.707107, 100, 100]],
                        [:move_to, [0, 0]],
                        [:line_to, [70.710678, 0]],
                        [:stroke_path]])
    end

    describe "stroke color" do
      it "uses the specified border color for stroking operations" do
        @line.border_style(color: "red")
        @generator.create_appearance
        assert_operators(@line.appearance.stream,
                         [:set_device_rgb_stroking_color, [1, 0, 0]], range: 0)
      end

      it "works with a transparent border" do
        @line.border_style(color: :transparent, width: 1)
        @generator.create_appearance
        assert_operators(@line.appearance.stream, [])
      end
    end

    it "uses the specified interior color for non-stroking operations" do
      @line.interior_color("red")
      @generator.create_appearance
      assert_operators(@line.appearance.stream,
                       [:set_device_rgb_non_stroking_color, [1, 0, 0]], range: 0)
    end

    it "sets the specified border line width" do
      @line.border_style(width: 2)
      @generator.create_appearance
      assert_operators(@line.appearance.stream,
                       [:set_line_width, [2]], range: 0)
    end

    describe "leader lines" do
      it "works for positive leader line length values" do
        @line.leader_line_length(10)
        @generator.create_appearance
        assert_operators(@line.appearance.stream,
                         [[:concatenate_matrix, [1.0, 0.0, -0.0, 1.0, 100, 100]],
                          [:move_to, [0, 0]],
                          [:line_to, [0, 10]],
                          [:move_to, [100, 0]],
                          [:line_to, [100, 10]],
                          [:move_to, [0, 10]],
                          [:line_to, [100.0, 10]],
                          [:stroke_path]])
      end

      it "works for negative leader line length values" do
        @line.leader_line_length(-10)
        @generator.create_appearance
        assert_operators(@line.appearance.stream,
                         [[:concatenate_matrix, [1.0, 0.0, -0.0, 1.0, 100, 100]],
                          [:move_to, [0, 0]],
                          [:line_to, [0, -10]],
                          [:move_to, [100, 0]],
                          [:line_to, [100, -10]],
                          [:move_to, [0, -10]],
                          [:line_to, [100.0, -10]],
                          [:stroke_path]])
      end

      it "works when using an offset and a positive leader line length" do
        @line.leader_line_length(10)
        @line.leader_line_offset(5)
        @generator.create_appearance
        assert_operators(@line.appearance.stream,
                         [[:concatenate_matrix, [1.0, 0.0, -0.0, 1.0, 100, 100]],
                          [:move_to, [0, 5]],
                          [:line_to, [0, 15]],
                          [:move_to, [100, 5]],
                          [:line_to, [100, 15]],
                          [:move_to, [0, 15]],
                          [:line_to, [100.0, 15]],
                          [:stroke_path]])
      end

      it "works when using an offset and a negative leader line length" do
        @line.leader_line_length(-10)
        @line.leader_line_offset(5)
        @generator.create_appearance
        assert_operators(@line.appearance.stream,
                         [[:concatenate_matrix, [1.0, 0.0, -0.0, 1.0, 100, 100]],
                          [:move_to, [0, -5]],
                          [:line_to, [0, -15]],
                          [:move_to, [100, -5]],
                          [:line_to, [100, -15]],
                          [:move_to, [0, -15]],
                          [:line_to, [100.0, -15]],
                          [:stroke_path]])
      end

      it "works when using leader line extensions" do
        @line.leader_line_length(10)
        @line.leader_line_extension_length(5)
        @generator.create_appearance
        assert_operators(@line.appearance.stream,
                         [[:concatenate_matrix, [1.0, 0.0, -0.0, 1.0, 100, 100]],
                          [:move_to, [0, 0]],
                          [:line_to, [0, 15]],
                          [:move_to, [100, 0]],
                          [:line_to, [100, 15]],
                          [:move_to, [0, 10]],
                          [:line_to, [100.0, 10]],
                          [:stroke_path]])
      end
    end
  end
end
