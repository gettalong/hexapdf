# -*- encoding: utf-8 -*-

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
  #   [llx, lly, urx, ury]
  #
  # where +llx+ is the lower-left x-coordinate, +lly+ is the lower-left y-coordinate, +urx+ is the
  # upper-right x-coordinate and +ury+ is the upper-right y-coordinate.
  #
  # See: PDF1.7 s7.9.5
  class Rectangle < HexaPDF::Object

    # Returns the x-coordinate of the lower-left corner.
    def left
      value[0]
    end

    # Returns the x-coordinate of the upper-right corner.
    def right
      value[2]
    end

    # Returns the y-coordinate of the lower-left corner.
    def bottom
      value[1]
    end

    # Returns the y-coordinate of the upper-right corner.
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

    private

    # Ensures that the value is an array containing four numbers that specify the lower-left and
    # upper-right corner.
    def after_data_change
      super
      unless value.kind_of?(Array) && value.size == 4
        raise ArgumentError, "A PDF rectangle structure must contain an array of four numbers"
      end
      value[0], value[2] = value[2], value[0] if value[0] > value[2]
      value[1], value[3] = value[3], value[1] if value[1] > value[3]
    end

  end

end
