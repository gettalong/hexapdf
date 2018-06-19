# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2018 Thomas Leitner
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
require 'hexapdf/layout/style'

module HexaPDF
  module Layout

    # The base class for all layout boxes.
    #
    # HexaPDF uses the following box model:
    #
    # * Each box can specify a content width and content height. Padding, border and margin are
    #   *outside* of this content rectangle.
    #
    # * The #width and #height accessors can be used to get the width and height of the box
    #   including padding and the border.
    #
    class Box

      # The width of the content box, i.e. without padding or borders.
      #
      # The value 0 means that the width is dynamically determined.
      attr_reader :content_width

      # The height of the content box, i.e. without padding or borders.
      #
      # The value 0 means that the height is dynamically determined.
      attr_reader :content_height

      # The style to be applied.
      #
      # Only the following properties are used:
      #
      # * Style#background_color
      # * Style#padding
      # * Style#border
      # * Style#overlay_callback
      # * Style#underlay_callback
      attr_reader :style

      # :call-seq:
      #    Box.new(content_width: 0, content_height: 0, style: Style.new) {|canv, box| block} -> box
      #    Box.new(width: 0, height: 0, style: Style.new) {|canv, box| block} -> box
      #
      # Creates a new Box object with the given width and height for its content that uses the
      # provided block when it is asked to draw itself on a canvas (see #draw).
      #
      # Alternative to specifying the content width/height, it is also possible to specify the box
      # width/height. The content width is then immediately calculated using the border and padding
      # information from the style and stored.
      #
      # Since the final location of the box is not known beforehand, the drawing operations inside
      # the block should draw inside the rectangle (0, 0, content_width, content_height) - note that
      # the width and height of the box may not be known beforehand.
      def initialize(content_width: 0, content_height: 0, width: 0, height: 0,
                     style: Style.new, &block)
        @style = (style.kind_of?(Style) ? style : Style.new(style))
        @draw_block = block
        @content_width = content_width
        @content_width = [width - self.width, 0].max if width != 0 && @content_width == 0
        @content_height = content_height
        @content_height = [height - self.height, 0].max if height != 0 && @content_height == 0
      end

      # Returns the width of the box, including padding and border widths.
      def width
        @content_width + @style.padding.left + @style.padding.right +
          @style.border.width.left + @style.border.width.right
      end

      # Returns the height of the box, including padding and border widths.
      def height
        @content_height + @style.padding.top + @style.padding.bottom +
          @style.border.width.top + @style.border.width.bottom
      end

      # :call-seq:
      #   box.draw(canvas, x, y)
      #
      # Draws the contents of the box onto the canvas at the position (x, y).
      #
      # The coordinate system is translated so that the origin is at the lower left corner of the
      # contents box during the drawing operations.
      def draw(canvas, x, y)
        if style.background_color
          canvas.save_graphics_state do
            canvas.fill_color(style.background_color).rectangle(x, y, width, height).fill
          end
        end

        style.underlays.draw(canvas, x, y, self)

        unless style.border.none?
          style.border.draw(canvas, x, y, width, height)
        end

        if @draw_block
          canvas.translate(x + style.padding.left + style.border.width.left,
                           y + style.padding.bottom + style.border.width.bottom) do
            @draw_block.call(canvas, self)
          end
        end

        style.overlays.draw(canvas, x, y, self)
      end

      # Returns +true+ if no drawing operations are performed.
      def empty?
        !(@draw_block || style.background_color || !style.underlays.none? ||
          !style.border.none? || !style.overlays.none?)
      end

    end

  end
end
