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

require 'hexapdf/error'
require 'hexapdf/layout/text_fragment'

module HexaPDF
  module Layout

    # A LineFragment describes a line of text and can contain TextFragment objects or InlineBox
    # objects.
    #
    # The items of a line fragment are aligned along the x-axis which coincides with the text
    # baseline. The vertical alignment is determined by the value of the #valign method:
    #
    # :text_top::
    #     Align the top of the box with the top of the text of the LineFragment.
    #
    # :text_bottom::
    #     Align the bottom of the box with the bottom of the text of the LineFragment.
    #
    # :baseline::
    #     Align the bottom of the box with the baseline of the LineFragment.
    #
    # :top::
    #     Align the top of the box with the top of the LineFragment.
    #
    # :bottom::
    #     Align the bottom of the box with the bottom of the LineFragment.
    #
    # :text::
    #     This is a special alignment value for text fragment objects. The text fragment is aligned
    #     on the baseline and its minimum and maximum y-coordinates are used when calculating the
    #     line's #text_y_min and #text_y_max.
    #
    #     This value may be used by other objects if they should be handled similar to text
    #     fragments, e.g. graphical representation of characters (think: emoji fonts).
    #
    # == Item Requirements
    #
    # Each item of a line fragment has to respond to the following methods:
    #
    # #x_min:: The minimum x-coordinate of the item.
    # #x_max:: The maximum x-coordinate of the item.
    # #width:: The width of the item.
    # #valign:: The vertical alignment of the item (see above).
    # #draw(canvas, x, y):: Should draw the item onto the canvas at the position (x, y).
    #
    # If an item has a vertical alignment of :text, it additionally has to respond to the following
    # methods:
    #
    # #y_min:: The minimum y-coordinate of the item.
    # #y_max:: The maximum y-coordinate of the item.
    #
    # Otherwise (i.e. a vertical alignment different from :text), the following method must be
    # implemented:
    #
    # #height:: The height of the item.
    class LineFragment

      # The items: TextFragment and InlineBox objects
      attr_accessor :items

      # Additional options.
      attr_reader :options

      # Creates a new LineFragment object with the given items.
      #
      # The +options+ hash may contain any key suitable for the caller.
      def initialize(items: [], **options)
        @items = items
        @options = options
      end

      # Adds the given item at the end of the item list.
      #
      # Note: The cache is not cleared!
      def add(item)
        @items << item
        self
      end
      alias :<< :add

      # :call-seq:
      #   line_fragment.each {|item, x, y| block }
      #
      # Yields each item together with its horizontal and vertical offset.
      def each
        x = 0
        @items.each do |item|
          y = case item.valign
              when :text, :baseline then 0
              when :top then y_max - item.height
              when :text_top then text_y_max - item.height
              when :text_bottom then text_y_min
              when :bottom then y_min
              else
                raise HexaPDF::Error, "Unknown inline box alignment #{item.valign}"
              end
          yield(item, x, y)
          x += item.width
        end
      end

      # The minimum x-coordinate of the whole line.
      def x_min
        @items[0].x_min
      end

      # The maximum x-coordinate of the whole line.
      def x_max
        @x_max ||= width + (items[-1].x_max - items[-1].width)
      end

      # The minimum y-coordinate of any item of the line.
      def y_min
        @y_min ||= calculate_y_dimensions[0]
      end

      # The minimum y-coordinate of any TextFragment item of the line.
      def text_y_min
        @text_y_min ||= calculate_y_dimensions[2]
      end

      # The maximum y-coordinate of any item of the line.
      def y_max
        @y_max ||= calculate_y_dimensions[1]
      end

      # The maximum y-coordinate of any TextFragment item of the line.
      def text_y_max
        @text_y_max ||= calculate_y_dimensions[3]
      end

      # The width of the line fragment.
      def width
        @width ||= @items.sum(&:width)
      end

      # The height of the line fragment.
      def height
        y_max - y_min
      end

      # The vertical offset of the baseline.
      #
      # This can be used to position consecutive text fragments correctly.
      def baseline_offset
        [y_min, 0].min.abs
      end

      # Clears all cached values.
      #
      # This method needs to be called if the fragment's items are changed!
      def clear_cache
        @x_max = @y_min = @y_max = @text_y_min = @text_y_max = @width = nil
      end

      private

      # :call-seq:
      #    line_fragment.calculate_y_dimensions     -> [y_min, y_max, text_y_min, text_y_max]
      #
      # Calculates all y-values and returns them as array.
      #
      # The following algorithm is used for the calculations:
      #
      # 1. Calculate #text_y_min and #text_y_max by using only the items with valign :text.
      #
      # 2. Calculate the temporary #y_min by using either the maximum height of all items with
      #    valign :text_top subtraced from #text_y_max, or #text_y_min, whichever is smaller.
      #
      #    For the temporary #y_max, use either the maximum height of all items with valign equal to
      #    :text_bottom added to #text_y_min, or the maximum height of all items with valign
      #    :baseline, or #text_y_max, whichever is larger.
      #
      # 3. Calculate the final #y_min by using either the maximum height of all items with valign
      #    :top subtracted from the temporary #y_min, or the temporary #y_min, whichever is smaller.
      #
      #    Calculate the final #y_max by using either the maximum height of all items with valign
      #    :bottom added to #y_min, or the temporary #y_max, whichever is larger.
      #
      # In certain cases there is no unique solution to the values of #y_min and #y_max, for
      # example, it depends on the order of the calculations in part 3.
      def calculate_y_dimensions
        @text_y_min = 0
        @text_y_max = 0
        max_top_height = 0
        max_text_top_height = 0
        max_bottom_height = 0
        max_text_bottom_height = 0
        max_base_height = 0

        @items.each do |item|
          case item.valign
          when :text
            @text_y_min = item.y_min if item.y_min < @text_y_min
            @text_y_max = item.y_max if item.y_max > @text_y_max
          when :baseline
            max_base_height = item.height if max_base_height < item.height
          when :top
            max_top_height = item.height if max_top_height < item.height
          when :text_top
            max_text_top_height = item.height if max_text_top_height < item.height
          when :bottom
            max_bottom_height = item.height if max_bottom_height < item.height
          when :text_bottom
            max_text_bottom_height = item.height if max_text_bottom_height < item.height
          else
            raise HexaPDF::Error, "Unknown inline box alignment #{item.valign}"
          end
        end

        @y_min = [@text_y_max - max_text_top_height, @text_y_min].min
        @y_max = [@text_y_min + max_text_bottom_height, max_base_height, @text_y_max].max
        @y_min = [@y_max - max_top_height, @y_min].min
        @y_max = [@y_min + max_bottom_height, @y_max].max

        [@y_min, @y_max, @text_y_min, @text_y_max]
      end

    end

  end
end
