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

require 'hexapdf/object'

module HexaPDF

  # Implementation of the PDF rectangle data structure.
  #
  # Rectangles are used for describing page and bounding boxes. They are represented by arrays of
  # four numbers specifying the (x,y) coordinates of *any* diagonally opposite corners.
  #
  # This class simplifies the usage of rectangles by automatically normalizing the coordinates so
  # that they are in the order:
  #
  #   [left, bottom, right, top]
  #
  # where +left+ is the bottom left x-coordinate, +bottom+ is the bottom left y-coordinate, +right+
  # is the top right x-coordinate and +top+ is the top right y-coordinate.
  #
  # See: PDF1.7 s7.9.5
  class Rectangle < HexaPDF::Object

    # Returns the x-coordinate of the bottom-left corner.
    def left
      value[0]
    end

    # Returns the x-coordinate of the top-right corner.
    def right
      value[2]
    end

    # Returns the y-coordinate of the bottom-left corner.
    def bottom
      value[1]
    end

    # Returns the y-coordinate of the top-right corner.
    def top
      value[3]
    end

    # Returns the width of the rectangle.
    def width
      value[2] - value[0]
    end

    # Returns the height of the rectangle.
    def height
      value[3] - value[1]
    end

    # Compares this rectangle to +other+ like in Object#== but also allows comparison to simple
    # arrays if the rectangle is a direct object.
    def ==(other)
      super || (other.kind_of?(Array) && !indirect? && other == data.value)
    end

    private

    # Ensures that the value is an array containing four numbers that specify the bottom left and
    # top right corner.
    def after_data_change
      super
      unless value.kind_of?(Array) && value.size == 4 && value.all? {|i| i.kind_of?(Numeric) }
        raise ArgumentError, "A PDF rectangle structure must contain an array of four numbers"
      end
      value[0], value[2] = value[2], value[0] if value[0] > value[2]
      value[1], value[3] = value[3], value[1] if value[1] > value[3]
    end

    def perform_validation #:nodoc:
      super
      unless value.kind_of?(Array) && value.size == 4 && value.all? {|i| i.kind_of?(Numeric) }
        yield("A PDF rectangle structure must contain an array of four numbers", false)
      end
    end

  end

end
