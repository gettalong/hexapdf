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
        assert_operators(@line.appearance.stream, [:end_path], range: 3)
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

    describe "line ending styles" do
      before do
        @line.border_style(width: 2)
        @line.interior_color("red")
      end

      it "works correctly for a transparent border" do
        @line.line_ending_style(start_style: :square, end_style: :square)
        @line.border_style(color: :transparent)
        @generator.create_appearance
        assert_operators(@line.appearance.stream,
                         [[:append_rectangle, [-3, -3, 6, 6]],
                          [:fill_path_non_zero],
                          [:append_rectangle, [97, -3, 6, 6]],
                          [:fill_path_non_zero]], range: 5..-1)
      end

      it "works for a square" do
        @line.line_ending_style(start_style: :square, end_style: :square)
        @generator.create_appearance
        assert_operators(@line.appearance.stream,
                         [[:append_rectangle, [-6, -6, 12, 12]],
                          [:fill_and_stroke_path_non_zero],
                          [:append_rectangle, [94, -6, 12, 12]],
                          [:fill_and_stroke_path_non_zero]], range: 6..-1)
      end

      it "works for a circle" do
        @line.line_ending_style(start_style: :circle, end_style: :circle)
        @generator.create_appearance
        assert_operators(@line.appearance.stream,
                         [[:move_to, [6.0, 0.0]],
                          [:curve_to, [6.0, 2.140933, 4.854102, 4.125686, 3.0, 5.196152]],
                          [:curve_to, [1.145898, 6.266619, -1.145898, 6.266619, -3.0, 5.196152]],
                          [:curve_to, [-4.854102, 4.125686, -6.0, 2.140933, -6.0, 0.0]],
                          [:curve_to, [-6.0, -2.140933, -4.854102, -4.125686, -3.0, -5.196152]],
                          [:curve_to, [-1.145898, -6.266619, 1.145898, -6.266619, 3.0, -5.196152]],
                          [:curve_to, [4.854102, -4.125686, 6.0, -2.140933, 6.0, -0.0]],
                          [:close_subpath],
                          [:fill_and_stroke_path_non_zero],
                          [:move_to, [106.0, 0.0]],
                          [:curve_to, [106.0, 2.140933, 104.854102, 4.125686, 103.0, 5.196152]],
                          [:curve_to, [101.145898, 6.266619, 98.854102, 6.266619, 97.0, 5.196152]],
                          [:curve_to, [95.145898, 4.125686, 94.0, 2.140933, 94.0, 0.0]],
                          [:curve_to, [94.0, -2.140933, 95.145898, -4.125686, 97.0, -5.196152]],
                          [:curve_to, [98.854102, -6.266619, 101.145898, -6.266619, 103.0, -5.196152]],
                          [:curve_to, [104.854102, -4.125686, 106.0, -2.140933, 106.0, -0.0]],
                          [:close_subpath],
                          [:fill_and_stroke_path_non_zero]], range: 6..-1)
      end

      it "works for a diamond" do
        @line.line_ending_style(start_style: :diamond, end_style: :diamond)
        @generator.create_appearance
        assert_operators(@line.appearance.stream,
                         [[:move_to, [6, 0]],
                          [:line_to, [0, 6]],
                          [:line_to, [-6, 0]],
                          [:line_to, [0, -6]],
                          [:close_subpath],
                          [:fill_and_stroke_path_non_zero],
                          [:move_to, [106.0, 0]],
                          [:line_to, [100.0, 6]],
                          [:line_to, [94.0, 0]],
                          [:line_to, [100.0, -6]],
                          [:close_subpath],
                          [:fill_and_stroke_path_non_zero]], range: 6..-1)
      end

      it "works for open and closed as well as reversed open and closed arrows" do
        dx = 15.588457
        [:open_arrow, :closed_arrow, :ropen_arrow, :rclosed_arrow].each do |style|
          @line.line_ending_style(start_style: style, end_style: style)
          @generator.create_appearance
          used_dx = (style == :ropen_arrow || style == :rclosed_arrow ? -dx : dx)
          ops = [[:move_to, [used_dx, 9.0]],
                 [:line_to, [0, 0]],
                 [:line_to, [used_dx, -9.0]],
                 [:move_to, [100 - used_dx, -9.0]],
                 [:line_to, [100.0, 0]],
                 [:line_to, [100 - used_dx, 9.0]]]
          if style == :closed_arrow || style == :rclosed_arrow
            ops.insert(3, [:close_subpath], [:fill_and_stroke_path_non_zero])
            ops.insert(-1, [:close_subpath], [:fill_and_stroke_path_non_zero])
          else
            ops.insert(3, [:stroke_path])
            ops.insert(-1, [:stroke_path])
          end
          assert_operators(@line.appearance.stream, ops, range: 6..-1)
        end
      end

      it "works for butt" do
        @line.line_ending_style(start_style: :butt, end_style: :butt)
        @generator.create_appearance
        assert_operators(@line.appearance.stream,
                         [[:move_to, [0, 6]],
                          [:line_to, [0, -6]],
                          [:stroke_path],
                          [:move_to, [100.0, 6]],
                          [:line_to, [100.0, -6]],
                          [:stroke_path]], range: 6..-1)
      end

      it "works for slash" do
        @line.line_ending_style(start_style: :slash, end_style: :slash)
        @generator.create_appearance
        assert_operators(@line.appearance.stream,
                         [[:move_to, [3, 5.196152]],
                          [:line_to, [-3, -5.196152]],
                          [:stroke_path],
                          [:move_to, [103.0, 5.196152]],
                          [:line_to, [97.0, -5.196152]],
                          [:stroke_path]], range: 6..-1)
      end
    end
  end
end
