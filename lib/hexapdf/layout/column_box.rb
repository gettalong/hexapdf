# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2022 Thomas Leitner
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
require 'hexapdf/layout/multi_frame'

module HexaPDF
  module Layout

    # A ColumnBox arranges boxes in one or more columns.
    #
    # The number of columns as well as the size of the gap between the columns can be modified.
    #
    # If the column box has padding and/or borders specified, they are handled like with any other
    # box. This means they are around all columns and their contents and are not used separately for
    # each column.
    #
    # The following style properties are used (additionally to those used by the parent class):
    #
    # Style#position::
    #    If this is set to :flow, the frames created for the columns will take the shape of the
    #    frame into account. This also means that the +available_width+ and +available_height+
    #    arguments are ignored.
    class ColumnBox < Box

      # The child boxes of this ColumnBox. They need to be finalized before #fit is called.
      attr_reader :children

      # The number of columns.
      attr_reader :columns

      # The size of the gap between the columns.
      attr_reader :gap

      # Determines whether the columns should all be equally high or not.
      attr_reader :equal_height

      # Creates a new ColumnBox object.
      def initialize(children: [], columns: 2, gap: 36, equal_height: true, **kwargs)
        super(**kwargs)
        @children = children
        @columns = columns
        @gap = gap
        @equal_height = equal_height
      end

      # Fits the column box into the available space.
      #
      # If the style property 'position' is set to :flow, the columns might not be rectangles but
      # arbitrary (sets of) polygons since the +frame+s shape is taken into account.
      def fit(available_width, available_height, frame)
        initial_fit_successful = (@equal_height ? nil : false)
        tries = 0
        @width = if style.position == :flow
                   (@initial_width > 0 ? @initial_width : frame.width) - reserved_width
                 else
                   (@initial_width > 0 ? @initial_width : available_width) - reserved_width
                 end
        height = if style.position == :flow
                   (@initial_height > 0 ? @initial_height : frame.height) - reserved_height
                 else
                   (@initial_height > 0 ? @initial_height : available_height) - reserved_height
                 end

        column_width = (@width - gap * (@columns - 1)).to_f / @columns
        left = (style.position == :flow ? frame.left : frame.x) + reserved_width_left
        top = (style.position == :flow ? frame.bottom + frame.height : frame.y) - reserved_height_top
        successful_height = height
        unsuccessful_height = 0

        while true
          @multi_frame = MultiFrame.new

          @columns.times do |col_nr|
            column_left = left + (column_width + gap) * col_nr
            column_bottom = top - height
            if style.position == :flow
              rect = Geom2D::Polygon([column_left, column_bottom],
                                     [column_left + column_width, column_bottom],
                                     [column_left + column_width, column_bottom + height],
                                     [column_left, column_bottom + height])
              shape = Geom2D::Algorithms::PolygonOperation.run(frame.shape, rect, :intersection)
            end
            column_frame = Frame.new(column_left, column_bottom, column_width, height, shape: shape)
            @multi_frame << column_frame
          end

          children.each {|box| @multi_frame.fit(box) }

          fit_successful = @multi_frame.fit_successful?
          initial_fit_successful = fit_successful if initial_fit_successful.nil?

          if fit_successful
            successful_height = height if successful_height > height
          elsif unsuccessful_height < height
            unsuccessful_height = height
          end

          break if !initial_fit_successful || tries > 40 ||
            (fit_successful && successful_height - unsuccessful_height < 10)

          height = if successful_height - unsuccessful_height <= 5
                     successful_height
                   else
                     (successful_height + unsuccessful_height) / 2.0
                   end
          tries += 1
        end

        @width += reserved_width
        @height = @multi_frame.content_heights.max + reserved_height

        @multi_frame.fit_successful?
      end

      private

      # Draws the child boxes onto the canvas at position [x, y].
      def draw_content(canvas, _x, _y)
        @multi_frame.fit_results.each {|result| result.draw(canvas) }
      end

    end

  end
end
