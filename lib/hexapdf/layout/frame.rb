# -*- encoding: utf-8; frozen_string_literal: true -*-
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

require 'hexapdf/layout/style'
require 'hexapdf/layout/width_from_polygon'
require 'geom2d/polygon'

module HexaPDF
  module Layout

    # A Frame describes the available space for placing boxes and provides additional methods for
    # calculating the needed information for the actual placement.
    #
    # In addition to the frame's box which is always rectangular a frame also has an *outline* which
    # may be an arbitrary polygon or even set of polygons. The outline is normally used when placing
    # text inside the frame.
    #
    # For example, a frame can describe the area of a page that is meant for visual content. When an
    # image is placed at the top left, the area it occupies is removed from the outline of the
    # frame. When text is added later, it could flow around that image by using the frame's outline.
    class Frame


      # The x-coordinate of the bottom-left corner.
      attr_reader :left

      # The y-coordinate of the bottom-left corner.
      attr_reader :bottom

      # The width of the frame.
      attr_reader :width

      # The height of the frame.
      attr_reader :height

      # The outline of the frame (a Geom2D::Polygon or Geom2D::PolygonSet).
      attr_reader :outline

      # Creates a new Frame object for the given rectangular area. If the outline of the frame
      # (should be a Geom2D::Polygon or Geom2D::PolygonSet) is not specified, then the rectangular
      # area is used as outline.
      def initialize(left, bottom, width, height, outline: nil)
        @left = left
        @bottom = bottom
        @width = width
        @height = height
        @outline = outline || Geom2D::Polygon([left, bottom], [left, bottom + height],
                                              [left + width, bottom + height],
                                              [left + width, bottom])
      end

      # Returns a width specification for the frame outline that can be used, for example, with
      # TextLayouter.
      #
      # Since not all text may start at the top of the frame, the offset argument can be used to
      # specify a vertical offset from the top of the frame where layouting should start.
      #
      # To be compatible with TextLayouter, the top left corner of the bounding box of the frame is
      # the origin of the coordinate system for the width specification, with positive x-values to
      # the right and positive y-values downwards.
      #
      # Depending on the complexity of the frame, the result may be any of the allowed width
      # specifications of TextLayouter#fit.
      def width_specification(offset = 0)
        WidthFromPolygon.new(@outline, offset)
      end

    end

  end
end
