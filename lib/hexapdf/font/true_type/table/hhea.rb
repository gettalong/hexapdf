# -*- encoding: utf-8 -*-

require 'hexapdf/font/true_type/table'

module HexaPDF
  module Font
    module TrueType
      class Table

        # The 'hhea' (horizontal header) table contains information for layouting fonts whose
        # characters are written horizontally.
        #
        # See: https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6hhea.html
        class Hhea < Table

          # The version of the table (a Rational).
          attr_accessor :version

          # The distance from the baseline of the highest ascender (as intended by the font
          # designer).
          attr_accessor :ascent

          # The distance from the baseline of the lowest descender (as intended by the font
          # designer).
          attr_accessor :descent

          # The typographic line gap (as intended by the font designer).
          attr_accessor :line_gap

          # The maxium advance width (computed value).
          attr_accessor :advance_width_max

          # The minimum left side bearing (computed value).
          attr_accessor :min_left_side_bearing

          # The minimum right side bearing (computed value).
          attr_accessor :min_right_side_bearing

          # The maximum horizontal glyph extent.
          attr_accessor :x_max_extent

          # Defines together with #caret_slope_run the mathematical slope of the angle for the
          # caret.
          #
          # The slope is actually the ratio caret_slope_rise/caret_slope_run
          attr_accessor :caret_slope_rise

          # See #caret_slope_rise.
          attr_accessor :caret_slope_run

          # The amount by which a slanted highlight on a glyph needs (0 for non-slanted fonts).
          attr_accessor :caret_offset

          # The number of horizontal metrics defined in the 'hmtx' table.
          attr_accessor :num_of_long_hor_metrics

          private

          def parse_table #:nodoc:
            @version = read_fixed
            @ascent, @descent, @line_gap, @advance_width_max, @min_left_side_bearing,
              @min_right_side_bearing, @x_max_extent, @caret_slope_rise, @caret_slope_run,
              @caret_offset, @num_of_long_hor_metrics = read_formatted(32, 's>3ns>6x10n')
          end

          def load_default #:nodoc:
            @version = 1.to_r
            @ascent = @descent = @line_gap = @advance_width_max = @min_left_side_bearing =
              @min_right_side_bearing = @x_max_extent = @caret_slope_rise = @caret_slope_run =
              @caret_offset = @num_of_long_hor_metrics = 0
          end

        end

      end
    end
  end
end
