# -*- encoding: utf-8 -*-

module HexaPDF
  module Content
    module GraphicObject

      # This graphic object represents a solid elliptical arc, i.e. an arc that has an inner and
      # an outer set of a/b values.
      #
      # Thus it can be used to create
      #
      # * an (elliptical) disk (when the inner a/b are zero and the difference between start and
      #   end angles is greater than or equal to 360),
      #
      # * an (elliptical) sector (when the inner a/b are zero and the difference between start
      #   and end angles is less than 360),
      #
      # * an (elliptical) annulus (when the inner a/b are nonzero and the difference between
      #   start and end angles is greater than or equal to 360), and
      #
      # * an (elliptical) annular sector (when the inner a/b are nonzero and the difference
      #   between start and end angles is less than 360)
      #
      # See: Arc
      class SolidArc

        # Creates and configures a new solid arc object.
        #
        # See #configure for the allowed keyword arguments.
        def self.configure(**kwargs)
          new.configure(kwargs)
        end

        # x-coordinate of center point
        attr_reader :cx

        # y-coordinate of center point
        attr_reader :cy

        # Length of inner semi-major axis
        attr_reader :inner_a

        # Length of inner semi-minor axis
        attr_reader :inner_b

        # Length of outer semi-major axis
        attr_reader :outer_a

        # Length of outer semi-minor axis
        attr_reader :outer_b

        # Start angle in degrees
        attr_reader :start_angle

        # End angle in degrees
        attr_reader :end_angle

        # Inclination in degrees of semi-major axis in respect to x-axis
        attr_reader :theta

        # Creates a solid arc with default values (a unit disk at the origin).
        def initialize
          @cx = @cy = 0
          @inner_a = @inner_b = 0
          @outer_a = @outer_b = 1
          @start_angle = 0
          @end_angle = 0
          @theta = 0
        end

        # Configures the solid arc with
        #
        # * center point (+cx+, +cy+),
        # * inner semi-major axis +inner_a+,
        # * inner semi-minor axis +inner_b+,
        # * outer semi-major axis +outer_a+,
        # * outer semi-minor axis +outer_b+,
        # * start angle of +start_angle+ degrees,
        # * end angle of +end_angle+ degrees and
        # * an inclination in respect to the x-axis of +theta+ degrees.
        #
        # Any arguments not specified are not modified and retain their old value, see #initialize
        # for the inital values.
        #
        # Returns self.
        def configure(cx: nil, cy: nil, inner_a: nil, inner_b: nil, outer_a: nil, outer_b: nil,
          start_angle: nil, end_angle: nil, theta: nil)
          @cx = cx if cx
          @cy = cy if cy
          @inner_a = inner_a if inner_a
          @inner_b = inner_b if inner_b
          @outer_a = outer_a if outer_a
          @outer_b = outer_b if outer_b
          @start_angle = start_angle % 360 if start_angle
          @end_angle = end_angle % 360 if end_angle
          @theta = theta if theta

          self
        end

        # Draws the solid arc on the given Canvas.
        def draw(canvas)
          angle_difference = (@end_angle - @start_angle).abs
          if @inner_a == 0 && @inner_b == 0
            arc = canvas.graphic_object(:arc, cx: @cx, cy: @cy, a: @outer_a, b: @outer_b,
              start_angle: @start_angle, end_angle: @end_angle,
              theta: @theta, sweep: true)
            if angle_difference == 0
              arc.draw(canvas)
              canvas.close_subpath
            else
              canvas.move_to(@cx, @cy)
              canvas.line_to(arc.start_point)
              arc.draw(canvas, move_to_start: false)
              canvas.close_subpath
            end
          else
            inner = canvas.graphic_object(:arc, cx: @cx, cy: @cy, a: @inner_a, b: @inner_b,
              start_angle: @end_angle, end_angle: @start_angle,
              theta: @theta, sweep: false)
            outer = canvas.graphic_object(:arc, cx: @cx, cy: @cy, a: @outer_a, b: @outer_b,
              start_angle: @start_angle, end_angle: @end_angle,
              theta: @theta, sweep: true)
            if angle_difference == 0
              outer.draw(canvas)
              canvas.close_subpath
              inner.draw(canvas)
              canvas.close_subpath
            else
              outer.draw(canvas)
              canvas.line_to(inner.start_point)
              inner.draw(canvas, move_to_start: false)
              canvas.close_subpath
            end
          end
        end

      end

    end
  end
end
