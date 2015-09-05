# -*- encoding: utf-8 -*-

require 'hexapdf/font/afm/character_metrics'

module HexaPDF
  module Font
    module AFM

      # Represents the information stored in an AFM font metrics file that is needed for working
      # with that font in context of the PDF format.
      #
      # FontMetrics objects are designed to be value objects. So after building a FontMetrics object
      # it should be frozen so that no modifications can be done.
      class FontMetrics

        # PostScript name of the font.
        attr_accessor :font_name

        # Full text name of the font.
        attr_accessor :full_name

        # Name of the typeface family to which the font belongs.
        attr_accessor :family_name

        # A string describing the character set of the font.
        attr_accessor :character_set

        # Weight of the font.
        attr_accessor :weight

        # The font bounding box as array of four numbers, specifying the x- and y-coordinates of the
        # lower-left corner and the x- and y-coordinates of the upper-right corner.
        attr_accessor :font_bbox

        # The y-value of the top of the capital H (or 0 or nil if the font doesn't contain a capital
        # H).
        attr_accessor :cap_height

        # The y-value of the top of the lowercase x (or 0 or nil if the font doesnt' contain a
        # lowercase x)
        attr_accessor :x_height

        # Ascender of the font.
        attr_accessor :ascender

        # Descender of the font.
        attr_accessor :descender

        # Dominant width of horizontal stems.
        attr_accessor :std_hw

        # Dominant width of vertical stems.
        attr_accessor :std_vw


        # Distance from the baseline for centering underlining strokes.
        attr_accessor :underline_position

        # Stroke width for underlining.
        attr_accessor :underline_thickness

        # Angle (in degrees counter-clockwise from the vertical) of the dominant vertical strokes of
        # the font.
        attr_accessor :italic_angle

        # Boolean specifying if the font is a fixed pitch (monospaced) font.
        attr_accessor :is_fixed_pitch


        # Mapping of character codes and names to CharacterMetrics objects.
        attr_accessor :character_metrics

        # Nested mapping of kerning pairs, ie. each key is a character name and each value is a
        # mapping from the second character name to the kerning amount.
        attr_accessor :kerning_pairs

        def initialize #:nodoc:
          @character_metrics = {}
          @kerning_pairs = Hash.new {|h, k| h[k] = {}}
        end

        def freeze #:nodoc:
          super
          @character_metrics.each_value(&:freeze)
          @character_metrics.freeze
          @kerning_pairs.each_value do |hash|
            hash.each_value(&:freeze)
            hash.freeze
          end
          @kerning_pairs.default_proc = nil
          @kerning_pairs.freeze
          self
        end

      end

    end
  end
end
