# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2020 Thomas Leitner
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
#
# If the GNU Affero General Public License doesn't fit your need,
# commercial licenses are available at <https://gettalong.at/hexapdf/>.
#++
require 'hexapdf/layout/box'
require 'hexapdf/layout/text_layouter'

module HexaPDF
  module Layout

    # A TextBox is used for drawing text, either inside a rectangular box or by flowing it around
    # objects of a Frame.
    #
    # This class uses TextLayouter behind the scenes to do the hard work.
    class TextBox < Box

      # Creates a new TextBox object with the given inline items (e.g. TextFragment and InlineBox
      # objects).
      def initialize(items, **kwargs)
        super(**kwargs)
        @tl = TextLayouter.new(style)
        @items = items
        @result = nil
      end

      # Fits the text box into the Frame.
      #
      # Depending on the 'position' style property, the text is either fit into the rectangular area
      # given by +available_width+ and +available_height+, or fit to the outline of the frame
      # starting from the top.
      #
      # The spacing after the last line can be controlled via the style property +last_line_gap+.
      #
      # Also see TextLayouter#style for other style properties taken into account.
      def fit(available_width, available_height, frame)
        return false if (@initial_width > 0 && @initial_width > available_width) ||
          (@initial_height > 0 && @initial_height > available_height)

        @width = @height = 0
        @result = if style.position == :flow
                    @tl.fit(@items, frame.width_specification, frame.contour_line.bbox.height)
                  else
                    @width = reserved_width
                    @height = reserved_height
                    width = (@initial_width > 0 ? @initial_width : available_width) - @width
                    height = (@initial_height > 0 ? @initial_height : available_height) - @height
                    @tl.fit(@items, width, height)
                  end
        @width += (@initial_width > 0 ? width : @result.lines.max_by(&:width)&.width || 0)
        @height += (@initial_height > 0 ? height : @result.height)
        if style.last_line_gap && @result.lines.last
          @height += style.line_spacing.gap(@result.lines.last, @result.lines.last)
        end

        @result.status == :success
      end

      # Splits the text box into two boxes if necessary and possible.
      def split(available_width, available_height, frame)
        fit(available_width, available_height, frame) unless @result
        if @width > available_width || @height > available_height
          [nil, self]
        elsif @result.remaining_items.empty?
          [self]
        elsif @result.lines.empty?
          [nil, self]
        else
          box = clone
          box.instance_variable_set(:@result, nil)
          box.instance_variable_set(:@items, @result.remaining_items)
          [self, box]
        end
      end

      # :nodoc:
      def empty?
        super && (!@result || @result.lines.empty?)
      end

      private

      # Draws the text into the box.
      def draw_content(canvas, x, y)
        return unless @result && !@result.lines.empty?
        @result.draw(canvas, x, y + content_height)
      end

    end

  end
end
