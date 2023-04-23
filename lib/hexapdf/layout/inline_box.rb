# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2023 Thomas Leitner
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
require 'hexapdf/layout/frame'

module HexaPDF
  module Layout

    # An InlineBox wraps a regular Box so that it can be used as an item for a Line. This enables
    # inline graphics.
    #
    # Complete box auto-sizing is not possible since the available space cannot be determined
    # beforehand! This means the box *must* have at least its width set. The height may either also
    # be set or determined during fitting.
    #
    # Fitting of the wrapped box is done immediately after creating a InlineBox instance. For this,
    # a frame is used that has the width of the wrapped box and its height, or if not set, a
    # practically infinite height. In the latter case the height *must* be set during fitting.
    class InlineBox

      # Creates an InlineBox that wraps a basic Box. All arguments (except +valign+) and the block
      # are passed to Box::create.
      #
      # See ::new for the +valign+ argument.
      def self.create(valign: :baseline, **args, &block)
        new(Box.create(**args, &block), valign: valign)
      end

      # The vertical alignment of the box.
      #
      # Can be any supported value except :text - see Line for all possible values.
      attr_reader :valign

      # The wrapped Box object.
      attr_reader :box

      # Creates a new InlineBox object wrapping +box+.
      #
      # The +valign+ argument can be used to specify the vertical alignment of the box relative to
      # other items in the Line.
      def initialize(box, valign: :baseline)
        raise HexaPDF::Error, "Width of box not set" if box.width == 0
        @box = box
        @valign = valign
        @fit_result = Frame.new(0, 0, box.width, box.height == 0 ? 100_000 : box.height).fit(box)
        if !@fit_result.success?
          raise HexaPDF::Error, "Box for inline use could not be fit"
        elsif box.height > 99_000
          raise HexaPDF::Error, "Box for inline use has no valid height set after fitting"
        end
      end

      # Returns +true+ if this inline box is just a placeholder without drawing operations.
      def empty?
        box.empty?
      end

      # Returns the width of the wrapped box plus its left and right margins.
      def width
        box.width + box.style.margin.left + box.style.margin.right
      end

      # Returns the height of the wrapped box plus its top and bottom margins.
      def height
        box.height + box.style.margin.top + box.style.margin.bottom
      end

      # Draws the wrapped box. If the box has margins specified, the x and y offsets are correctly
      # adjusted.
      def draw(canvas, x, y)
        canvas.translate(x - @fit_result.x + box.style.margin.left,
                         y - @fit_result.y + box.style.margin.bottom) { @fit_result.draw(canvas) }
      end

      # The minimum x-coordinate which is always 0.
      def x_min
        0
      end

      # The maximum x-coordinate which is equivalent to the width of the inline box.
      def x_max
        width
      end

      # The minimum y-coordinate which is always 0.
      def y_min
        0
      end

      # The maximum y-coordinate which is equivalent to the height of the inline box.
      def y_max
        height
      end

    end

  end
end
