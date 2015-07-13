# -*- encoding: utf-8 -*-

module HexaPDF
  module PDF
    module Content

      # A TransformationMatrix is a matrix used in PDF graphics operations to specify the
      # relationship between different coordinate systems.
      #
      # All matrix operations modify the matrix in place. So if the original matrix should be
      # preserved, duplicate it before the operation.
      #
      # It is important to note that the matrix transforms from the new coordinate system to the
      # untransformed coordinate system. This means that after the transformation all coordinates
      # are specified in the new, transformed coordinate system and to get the untransformed
      # coordinates the matrix needs to be applied.
      #
      # Although all operations are done in 2D space the transformation matrix is a 3x3 matrix
      # because homogeneous coordinates are used. This, however, also means that only six entries
      # are actually used that are named like in the following graphic:
      #
      #   a b 0
      #   c d 0
      #   e f 1
      #
      # Here is a simple transformation matrix to translate all coordinates by 5 units horizontally
      # and 10 units vertically:
      #
      #   1  0 0
      #   0  1 0
      #   5 10 1
      #
      # Details and some examples can be found in the PDF reference.
      #
      # See: PDF1.7 s8.3
      class TransformationMatrix

        # Convert degrees to radians.
        def self.rad(degrees)
          degrees * Math::PI / 180
        end


        # The value at the position (1,1) in the matrix.
        attr_reader :a

        # The value at the position (1,2) in the matrix.
        attr_reader :b

        # The value at the position (2,1) in the matrix.
        attr_reader :c

        # The value at the position (2,2) in the matrix.
        attr_reader :d

        # The value at the position (3,1) in the matrix.
        attr_reader :e

        # The value at the position (3,2) in the matrix.
        attr_reader :f

        # Initializes the transformation matrix to the indenty matrix.
        def initialize
          @a = 1
          @b = 0
          @c = 0
          @d = 1
          @e = 0
          @f = 0
        end

        # Returns the untransformed coordinates of the given point.
        def evaluate(x, y)
          [@a * x + @c * y + @e, @b * x + @d * y + @f]
        end

        # Translates this matrix by +x+ units horizontally and +y+ units vertically and returns it.
        #
        # This is equal to premultiply(1, 0, 0, 1, x, y).
        def translate(x, y)
          @e = x * @a + y * @c + @e
          @f = x * @b + y * @d + @f
          self
        end

        # Scales this matrix by +sx+ units horizontally and +y+ units vertically and returns it.
        #
        # This is equal to premultiply(sx, 0, 0, sy, 0, 0).
        def scale(sx, sy)
          @a = sx * @a
          @b = sx * @b
          @c = sy * @c
          @d = sy * @d
          self
        end

        # Rotates this matrix by an angle of +q+ degrees and returns it.
        #
        # This equal to premultiply(cos(rad(q)), sin(rad(q)), -sin(rad(q)), cos(rad(q)), x, y).
        def rotate(q)
          cq = Math.cos(self.class.rad(q))
          sq = Math.sin(self.class.rad(q))
          premultiply(cq, sq, -sq, cq, 0, 0)
        end

        # Skews this matrix by an angle of +a+ degrees for the x axis and by an angle of +b+ degrees
        # for the y axis and returns it.
        #
        # This is equal to premultiply(1, tan(rad(a)), tan(rad(b)), 1, x, y).
        def skew(a, b)
          premultiply(1, Math.tan(self.class.rad(a)), Math.tan(self.class.rad(b)), 1, 0, 0)
        end

        # Transforms this matrix by premultiplying it with the given one (ie. given*this) and
        # returns it.
        def premultiply(a, b, c, d, e, f)
          a1 = a * @a + b * @c
          b1 = a * @b + b * @d
          c1 = c * @a + d * @c
          d1 = c * @b + d * @d
          @e = e * @a + f * @c + @e
          @f = e * @b + f * @d + @f
          @a = a1
          @b = b1
          @c = c1
          @d = d1
          self
        end

      end

    end
  end
end
