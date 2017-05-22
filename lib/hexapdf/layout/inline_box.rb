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

module HexaPDF
  module Layout

    # An InlineBox can be used as an item for a LineFragment so that inline graphics are possible.
    # The box *must* have a fixed size!
    class InlineBox

      # The width of the box.
      attr_reader :width

      # The height of the box.
      attr_reader :height

      # The vertical alignment of the box.
      #
      # Can be any supported value except :text - see LineFragment for all possible values.
      attr_reader :valign

      # :call-seq:
      #    InlineBox.new(width, height, valign: :baseline) {|box, canvas| block}      -> inline_box
      #
      # Creates a new InlineBox object that uses the provided block when it is asked to draw itself
      # on a canvas (see #draw).
      #
      # Since the final location of the box is not known beforehand, the drawing operations inside
      # the block should draw inside the rectangle (0, 0, width, height).
      #
      # The +valign+ argument can be used to specify the vertical alignment of the box relative to
      # other items in the LineFragment - see #valign and LineFragment.
      def initialize(width, height, valign: :baseline, &block)
        @width = width
        @height = height
        @valign = valign
        @draw_block = block
      end

      # :call-seq:
      #   box.draw(canvas, x, y)    -> block_result
      #
      # Draws the contents of the box onto the canvas at the position (x, y), and returns the result
      # of the drawing block (see #initialize).
      #
      # The coordinate system is translated so that the origin is at (x, y) during the drawing
      # operations.
      def draw(canvas, x, y)
        canvas.translate(x, y) { @draw_block.call(self, canvas) }
      end

      # The minimum x-coordinate which is always 0.
      def x_min
        0
      end

      # The maximum x-coordinate which is equivalent to the width of the box.
      def x_max
        width
      end

    end

  end
end
