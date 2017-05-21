# -*- encoding: utf-8 -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2017 Thomas Leitner
#
# HexaPDF is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License version 3 as
# published by the Free Software Foundation with the addition of the
# following permission added to Section 15 as permitted in Section 7(a):
# FOR ANY PART OF THE COVERED WORK IN WHICH THE COPYRIGHT IS OWNED BY
# THOMAS LEITNER, THOMAS LEITNER DISCLAIMS THE WARRANTY OF NON
# INFRINGEMENT OF THIRD PARTY RIGHTS.
#
# HexaPDF is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public
# License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with HexaPDF. If not, see <http://www.gnu.org/licenses/>.
#
# The interactive user interfaces in modified source and object code
# versions of HexaPDF must display Appropriate Legal Notices, as required
# under Section 5 of the GNU Affero General Public License version 3.
#
# In accordance with Section 7(b) of the GNU Affero General Public
# License, a covered work must retain the producer line in every PDF that
# is created or manipulated using HexaPDF.
#++

require 'hexapdf/layout/numeric_refinements'

module HexaPDF
  module Layout

    # A TextFragment describes an optionally kerned piece of text that shares the same font, font
    # size and other properties.
    #
    # Its items are either glyph objects of the font or numeric values describing kerning
    # information. All returned measurement values are in text space units. If the items or
    # attributes are changed, the #clear_cache has to be called. Otherwise the measurements may not
    # be correct!
    #
    # The rectangle with the lower-left corner (#x_min, #y_min) and the upper right corner (#x_max,
    # #y_max) describes the minimum bounding of the whole text fragment and is usually *not* equal
    # to the box (0, 0)-(#width, #height).
    class TextFragment

      using NumericRefinements

      # The font wrapper (see Canvas#font).
      attr_reader :font

      # The font size (see Canvas#font_size).
      attr_reader :font_size

      # The character spacing (see Canvas#character spacing).
      attr_reader :character_spacing

      # The word spacing (see Canvas#word_spacing).
      attr_reader :word_spacing

      # The horizontal scaling (see Canvas#horizontal_scaling).
      attr_reader :horizontal_scaling

      # The text rise, i.e. vertical offset (see Canvas#text_rise).
      attr_reader :text_rise

      # The items (glyphs and kerning values) of the text fragment.
      attr_reader :items

      # Additional options.
      attr_reader :options

      # Creates a new TextFragment object with the given items, font wrapper object and font size.
      #
      # The +options+ hash may contain the keys :character_spacing, :word_spacing,
      # :horizontal_scaling and :text_rise for setting the so named attribute. All other options are
      # stored in #options.
      def initialize(items:, font:, font_size:, **options)
        @font = font
        @font_size = font_size
        @character_spacing = options.delete(:character_spacing) || 0
        @word_spacing = options.delete(:word_spacing) || 0
        @horizontal_scaling = options.delete(:horizontal_scaling) || 100
        @text_rise = options.delete(:text_rise) || 0

        @items = items
        @options = options
      end

      # The minimum x-coordinate of the first glyph.
      def x_min
        @x_min ||= calculate_x_min
      end

      # The maximum x-coordinate of the last glyph.
      def x_max
        @x_max ||= calculate_x_max
      end

      # The minimum y-coordinate of any item.
      def y_min
        @y_min ||= (@items.min_by(&:y_min)&.y_min || 0) * font_size / 1000.0 + text_rise
      end

      # The maximum y-coordinate of any item.
      def y_max
        @y_max ||= (@items.max_by(&:y_max)&.y_max || 0) * font_size / 1000.0 + text_rise
      end

      # The width of the text fragment.
      #
      # It is the sum of the widths of its items and is calculated by using the algorithm presented
      # in PDF1.7 s9.4.4. By using kerning values as the first and/or last items, the text contained
      # in the fragment may spill over the left and/or right boundary.
      def width
        @width ||= calculate_width
      end

      # The height of the text fragment.
      #
      # It is calculated as the difference of the maximum of the +y_max+ values and the minimum of
      # the +y_min+ values of the items. However, the text rise value is also taken into account so
      # that the baseline is always *inside* the bounds. For example, if a large negative text rise
      # value is used, the baseline will be equal to the top boundary; if a large positive value is
      # used, it will be equal to the bottom boundary.
      def height
        @height ||= [y_max, 0].max - [y_min, 0].min
      end

      # The vertical offset of the baseline.
      #
      # When the text cursor is positioned at (0, #baseline_offset), the text described by the
      # fragment is drawn completely within the bounding box (#x_min, #y_min)-(#x_max, #y_max).
      def baseline_offset
        [y_min, 0].min.abs
      end

      # Clears all cached values.
      #
      # This method needs to be called if the fragment's items or attributes are changed!
      def clear_cache
        @x_min = @x_max = @y_min = @y_max = @width = @height =
          @scaled_font_size = @scaled_character_spacing = @scaled_word_spacing =
          @scaled_horizontal_scaling = nil
      end

      private

      def calculate_x_min
        if !@items.empty? && @items[0].glyph?
          @items[0].x_min * scaled_font_size
        else
          @items.inject(0) do |sum, item|
            sum += item.x_min * scaled_font_size
            break sum if item.glyph?
            sum
          end
        end
      end

      def calculate_x_max
        if !@items.empty? && @items[-1].glyph?
          width - scaled_glyph_right_side_bearing(@items[-1])
        else
          @items.reverse_each.inject(width) do |sum, item|
            if item.glyph?
              break sum - scaled_glyph_right_side_bearing(item)
            else
              sum + item * scaled_font_size
            end
          end
        end
      end

      def scaled_glyph_right_side_bearing(glyph)
        (glyph.x_max <= 0 ? 0 : glyph.width - glyph.x_max) * scaled_font_size +
          scaled_character_spacing + (glyph.apply_word_spacing? ? scaled_word_spacing : 0)
      end

      def calculate_width
        width = 0
        @items.each do |item|
          if item.glyph?
            width += item.width * scaled_font_size + scaled_character_spacing
            width += scaled_word_spacing if item.apply_word_spacing?
          else
            width -= item * scaled_font_size
          end
        end
        width
      end

      def scaled_font_size
        @scaled_font_size ||= font_size / 1000.0 * scaled_horizontal_scaling
      end

      def scaled_character_spacing
        @scaled_character_spacing ||= character_spacing * scaled_horizontal_scaling
      end

      def scaled_word_spacing
        @scaled_word_spacing ||= word_spacing * scaled_horizontal_scaling
      end

      def scaled_horizontal_scaling
        @scaled_horizontal_scaling ||= horizontal_scaling / 100.0
      end

    end

  end
end
