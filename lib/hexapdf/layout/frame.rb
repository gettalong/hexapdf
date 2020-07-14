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

require 'hexapdf/layout/width_from_polygon'
require 'geom2d/polygon'

module HexaPDF
  module Layout

    # A Frame describes the available space for placing boxes and provides additional methods for
    # calculating the needed information for the actual placement.
    #
    # == Usage
    #
    # After a Frame object is initialized, it is ready for drawing boxes on it.
    #
    # The explicit way of drawing a box follows these steps:
    #
    # * Call #fit with the box to see if the box can fit into the currently selected region of
    #   available space. If fitting is successful, the box can be drawn using #draw.
    #
    #   The method #fit is also called for absolutely positioned boxes but since these boxes are not
    #   subject to the normal constraints, the available space used is the width and height inside
    #   the frame to the right and top of the bottom-left corner of the box.
    #
    # * If the box didn't fit, call #find_next_region to determine the next region for placing the
    #   box. If a new region was found, start over with #fit. Otherwise the frame has no more space
    #   for placing boxes.
    #
    # * Alternatively to calling #find_next_region it is also possible to call #split. This method
    #   tries to split the box into two so that the first part fits into the current region. If
    #   splitting is successful, the first box can be drawn (Make sure that the second box is
    #   handled correctly). Otherwise, start over with #find_next_region.
    #
    # For applications where splitting is not necessary, an easier way is to just use #draw and
    # #find_next_region together, as #draw calls #fit if the box was not fit into the current
    # region.
    #
    # == Used Box Properties
    #
    # The style properties "position", "position_hint" and "margin" are taken into account when
    # fitting, splitting or drawing a box. Note that the margin is ignored if a box's side coincides
    # with the frame's original boundary.
    #
    # == Frame Shape and Contour Line
    #
    # A frame's shape is used to determine the available space for laying out boxes and its contour
    # line is used whenever text should be flown around objects. They are normally the same but can
    # differ if a box with an arbitrary contour line is drawn onto the frame.
    #
    # Initially, a frame has a rectangular shape. However, once boxes are added and the frame's
    # available area gets reduced, a frame may have a polygon set consisting of arbitrary
    # rectilinear polygons as shape.
    #
    # In contrast to the frame's shape its contour line may be a completely arbitrary polygon set.
    class Frame

      include Geom2D::Utils

      # Internal class for storing data of a fitted box.
      class FitData

        # The box that was fitted into the frame.
        attr_accessor :box

        # The available width for this particular box.
        attr_accessor :available_width

        # The available height for this particular box.
        attr_accessor :available_height

        # The left margin to use instead of +box.style.margin.left+.
        attr_accessor :margin_left

        # The right margin to use instead of +box.style.margin.right+.
        attr_accessor :margin_right

        # The top margin to use instead of +box.style.margin.top+.
        attr_accessor :margin_top

        # Initialize the object by calling #reset.
        def initialize
          reset
        end

        # Resets the object.
        def reset(box = nil, available_width = 0, available_height = 0)
          @box = box
          @available_width = available_width
          @available_height = available_height
          @margin_left = @margin_right = @margin_top = 0
        end

      end

      # The x-coordinate of the bottom-left corner.
      attr_reader :left

      # The y-coordinate of the bottom-left corner.
      attr_reader :bottom

      # The width of the frame.
      attr_reader :width

      # The height of the frame.
      attr_reader :height

      # The shape of the frame, a Geom2D::PolygonSet consisting of rectilinear polygons.
      attr_reader :shape

      # The x-coordinate where the next box will be placed.
      #
      # Note: Since the algorithm for drawing takes the margin of a box into account, the actual
      # x-coordinate (and y-coordinate, available width and available height) might be different.
      attr_reader :x

      # The y-coordinate where the next box will be placed.
      #
      # Also see the note in the #x documentation for further information.
      attr_reader :y

      # The available width for placing a box.
      #
      # Also see the note in the #x documentation for further information.
      attr_reader :available_width

      # The available height for placing a box.
      #
      # Also see the note in the #x documentation for further information.
      attr_reader :available_height

      # Creates a new Frame object for the given rectangular area.
      def initialize(left, bottom, width, height, contour_line: nil)
        @left = left
        @bottom = bottom
        @width = width
        @height = height
        @contour_line = contour_line
        @shape = Geom2D::PolygonSet.new(
          [create_rectangle(left, bottom, left + width, bottom + height)]
        )
        @x = left
        @y = bottom + height
        @available_width = width
        @available_height = height
        @region_selection = :max_height
        @fit_data = FitData.new
      end

      # Fits the given box into the current region of available space.
      def fit(box)
        aw = available_width
        ah = available_height
        @fit_data.reset(box, aw, ah)

        if full?
          false
        elsif box.style.position == :absolute
          x, y = box.style.position_hint
          box.fit(width - x, height - y, self)
          true
        else
          if box.style.margin?
            margin = box.style.margin
            ah -= margin.bottom unless float_equal(@y - ah, @bottom)
            ah -= @fit_data.margin_top = margin.top unless float_equal(@y, @bottom + @height)
            aw -= @fit_data.margin_right = margin.right unless float_equal(@x + aw, @left + @width)
            aw -= @fit_data.margin_left = margin.left unless float_equal(@x, @left)
            @fit_data.available_width = aw
            @fit_data.available_height = ah
          end

          box.fit(aw, ah, self)
        end
      end

      # Tries to split the (fitted) box into two parts, where the first part needs to fit into the
      # available space, and returns both parts.
      #
      # If the given box is not the last fitted box, #fit is called before splitting the box.
      #
      # See Box#split for further details.
      def split(box)
        fit(box) unless box == @fit_data.box
        boxes = box.split(@fit_data.available_width, @fit_data.available_height, self)
        @fit_data.reset unless boxes[0] == @fit_data.box
        boxes
      end

      # Draws the given (fitted) box onto the canvas at the frame's current position. Returns +true+
      # if drawing was possible, +false+ otherwise.
      #
      # If the given box is not the last fitted box, #fit is called before drawing the box.
      #
      # After a box is successfully drawn, the frame's shape and contour line are adjusted to remove
      # the occupied area.
      def draw(canvas, box)
        unless box == @fit_data.box
          fit(box) || return
        end

        width = box.width
        height = box.height
        margin = box.style.margin if box.style.margin?

        if height == 0
          @fit_data.reset
          return true
        end

        case box.style.position
        when :absolute
          x, y = box.style.position_hint
          x += left
          y += bottom
          rectangle = if box.style.margin?
                        create_rectangle(x - margin.left, y - margin.bottom,
                                         x + width + margin.right, y + height + margin.top)
                      else
                        create_rectangle(x, y, x + width, y + height)
                      end
        when :float
          x = @x + @fit_data.margin_left
          x += @fit_data.available_width - width if box.style.position_hint == :right
          y = @y - height - @fit_data.margin_top
          # We use the real margins from the box because they either have the desired effect or just
          # extend the rectangle outside the frame.
          rectangle = create_rectangle(x - (margin&.left || 0), y - (margin&.bottom || 0),
                                       x + width + (margin&.right || 0), @y)
        when :flow
          x = 0
          y = @y - height
          rectangle = create_rectangle(left, y, left + self.width, @y)
        else
          x = case box.style.position_hint
              when :right
                @x + @fit_data.margin_left + @fit_data.available_width - width
              when :center
                max_margin = [@fit_data.margin_left, @fit_data.margin_right].max
                # If we have enough space left for equal margins, we center perfectly
                if available_width - width >= 2 * max_margin
                  @x + (available_width - width) / 2.0
                else
                  @x + @fit_data.margin_left + (@fit_data.available_width - width) / 2.0
                end
              else
                @x + @fit_data.margin_left
              end
          y = @y - height - @fit_data.margin_top
          rectangle = create_rectangle(left, y - (margin&.bottom || 0), left + self.width, @y)
        end

        box.draw(canvas, x, y)
        remove_area(rectangle)
        @fit_data.reset

        true
      end

      # Finds the next region for placing boxes. Returns +false+ if no useful region was found.
      #
      # This method should be called after drawing a box using #draw was not successful. It finds a
      # different region on each invocation. So if a box doesn't fit into the first region, this
      # method should be called again to find another region and to try again.
      #
      # The first tried region starts at the top-most, left-most vertex of the polygon and uses the
      # maximum width. The next tried region uses the maximum height. If both don't work, part of
      # the frame's shape is removed to try again.
      def find_next_region
        case @region_selection
        when :max_width
          find_max_width_region
          @region_selection = :max_height
        when :max_height
          x, y, aw, ah = @x, @y, @available_width, @available_height
          find_max_height_region
          if @x == x && @y == y && @available_width == aw && @available_height == ah
            trim_shape
          else
            @region_selection = :trim_shape
          end
        else
          trim_shape
        end

        @fit_data.reset
        available_width != 0
      end

      # Removes the given *rectilinear* polygon from both the frame's shape and the frame's contour
      # line.
      def remove_area(polygon)
        @shape = Geom2D::Algorithms::PolygonOperation.run(@shape, polygon, :difference)
        if @contour_line
          @contour_line = Geom2D::Algorithms::PolygonOperation.run(@contour_line, polygon,
                                                                   :difference)
        end
        @region_selection = :max_width
        find_next_region
      end

      # Returns +true+ if the frame has no more space left.
      def full?
        available_width == 0
      end

      # The contour line of the frame, a Geom2D::PolygonSet consisting of arbitrary polygons.
      def contour_line
        @contour_line || @shape
      end

      # Returns a width specification for the frame's contour line that can be used, for example,
      # with TextLayouter.
      #
      # Since not all text may start at the top of the frame, the offset argument can be used to
      # specify a vertical offset from the top of the frame where layouting should start.
      #
      # To be compatible with TextLayouter, the top left corner of the bounding box of the frame's
      # contour line is the origin of the coordinate system for the width specification, with
      # positive x-values to the right and positive y-values downwards.
      #
      # Depending on the complexity of the frame, the result may be any of the allowed width
      # specifications of TextLayouter#fit.
      def width_specification(offset = 0)
        WidthFromPolygon.new(contour_line, offset)
      end

      private

      # Creates a Geom2D::Polygon object representing the rectangle with the bottom left corner
      # (blx, bly) and the top right corner (trx, try).
      def create_rectangle(blx, bly, trx, try)
        Geom2D::Polygon(Geom2D::Point(blx, bly), Geom2D::Point(trx, bly),
                        Geom2D::Point(trx, try), Geom2D::Point(blx, try))
      end

      # Finds the region with the maximum width.
      def find_max_width_region
        return unless (segments = find_starting_point)

        x_right = @x + @available_width

        # Available height can be determined by finding the segment with the highest y-coordinate
        # which lies (maybe only partly) between the vertical lines @x and x_right.
        segments.select! {|s| s.max.x > @x && s.min.x < x_right }
        @available_height = @y - segments.last.start_point.y
      end

      # Finds the region with the maximum height.
      def find_max_height_region
        return unless (segments = find_starting_point)

        # Find segment with maximum y-coordinate directly below (@x,@y), this determines the
        # available height
        index = segments.rindex {|s| s.min.x <= @x && @x < s.max.x }
        y1 = segments[index].start_point.y
        @available_height = @y - y1

        # Find segment with minium min.x coordinate whose y-coordinate is between y1 and @y and
        # min.x > @x, for getting the available width
        segments.select! {|s| s.min.x > @x && y1 <= s.start_point.y && s.start_point.y <= @y }
        segment = segments.min_by {|s| s.min.x }
        @available_width = segment.min.x - @x if segment
      end

      # Trims the frame's shape so that the next starting point is different.
      def trim_shape
        return unless (segments = find_starting_point)

        # Just use the second top-most segment
        # TODO: not the optimal solution!
        index = segments.rindex {|s| s.start_point.y < @y }
        y = segments[index].start_point.y
        remove_area(Geom2D::Polygon([left, y], [left + width, y],
                                    [left + width, @y], [left, @y]))
      end

      # Finds and sets the top-left point for the next region. This is always the top-most,
      # left-most vertex of the frame's shape.
      #
      # If successful, additionally sets the available width to the length of the segment containing
      # the point and returns the sorted horizontal segments except the top-most one.
      #
      # Otherwise, sets all region specific values to zero and returns +nil+.
      def find_starting_point
        segments = sorted_horizontal_segments
        if segments.empty?
          @x = @y = @available_width = @available_height = 0
          return
        end

        top_segment = segments.pop
        @x = top_segment.min.x
        @y = top_segment.start_point.y
        @available_width = top_segment.length

        segments
      end

      # Returns the horizontal segments of the frame's shape, sorted by maximum y-, then minimum
      # x-coordinate.
      def sorted_horizontal_segments
        @shape.each_segment.select(&:horizontal?).sort! do |a, b|
          if a.start_point.y == b.start_point.y
            b.start_point.x <=> a.start_point.x
          else
            a.start_point.y <=> b.start_point.y
          end
        end
      end

    end

  end
end
