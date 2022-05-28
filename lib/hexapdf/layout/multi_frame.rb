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

module HexaPDF
  module Layout

    # A MultiFrame contains an array of Frame objects and allows placing boxes one after the other
    # in them. Such functionality is useful for boxes that provide multiple frames for content.
    #
    # == Usage
    #
    # * First one needs to add the frame objects via #<< or provide them on initialization.
    #
    # * Then use the #fit method to fit boxes one after the other.
    #
    # * Once all boxes have been fitted inside the MultiFrame, the #fit_results, #remaining_boxes
    #   and #fit_successful? methods can be used to get the result:
    #
    #   - If there are no remaining boxes, all boxes were successfully fitted.
    #   - If there are remaining boxes but no fit results, the first box could not be fitted.
    #   - If there are remaining boxes and fit results, some boxes were able to fit.
    class MultiFrame

      # The array of frames inside of which the boxes should be laid out.
      attr_reader :frames

      # The Frame::FitResult objects for the successfully fitted objects in the order the boxes were
      # fitted.
      attr_reader :fit_results

      # The boxes that could not be fitted into the frames.
      attr_reader :remaining_boxes

      # Creates a new MultiFrame object for the given +frames+.
      def initialize(frames = [])
        @frames = []
        @min_frame_content_y = []
        @frame_index = 0
        @fit_results = []
        @remaining_boxes = []

        frames.each {|frame| self << frame }
      end

      # Add the given frame to the list of frames.
      def <<(frame)
        @frames << frame
        @min_frame_content_y << frame.y
      end

      # Fits the given box into the current location.
      def fit(box)
        unless @remaining_boxes.empty?
          @remaining_boxes << box
          return
        end

        while (current_frame = @frames[@frame_index])
          result = current_frame.fit(box)
          if result.success?
            current_frame.remove_area(result.mask)
            @min_frame_content_y[@frame_index] = [@min_frame_content_y[@frame_index], result.mask[0].y].min
            @fit_results << result
            box = nil
            break
          elsif current_frame.full?
            @frame_index += 1
          else
            draw_box, box = current_frame.split(result)
            if draw_box
              current_frame.remove_area(result.mask)
              @min_frame_content_y[@frame_index] = [@min_frame_content_y[@frame_index], result.mask[0].y].min
              @fit_results << result
            elsif !current_frame.find_next_region
              @frame_index += 1
            end
          end
        end

        @remaining_boxes << box if box
      end

      # Returns an array with the heights of the content of each frame.
      def content_heights
        @min_frame_content_y.map.with_index do |y, index|
          @frames[index].bottom + @frames[index].height - y
        end
      end

      # Returns +true+ if all boxes were successfully fitted.
      def fit_successful?
        @remaining_boxes.empty?
      end

    end

  end
end
