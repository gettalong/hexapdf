# -*- encoding: utf-8 -*-

require 'hexapdf/utils/math_helpers'

module HexaPDF
  module Content
    module GraphicObject

      # This class describes an elliptical arc in endpoint parameterization. It allows one to
      # generate an arc from the current point to a given point, similar to Canvas#line_to.
      #
      # See: Arc, ARC - https://www.w3.org/TR/SVG/implnote.html#ArcImplementationNotes
      class EndpointArc

        include Utils::MathHelpers

        # Creates and configures a new endpoint arc object.
        #
        # See #configure for the allowed keyword arguments.
        def self.configure(**kwargs)
          new.configure(kwargs)
        end

        # x-coordinate of endpoint
        attr_reader :x

        # y-coordinate of endpoint
        attr_reader :y

        # Length of semi-major axis
        attr_reader :a

        # Length of semi-minor axis
        attr_reader :b

        # Inclination in degrees of semi-major axis in respect to x-axis
        attr_reader :inclination

        # Large arc choice - if +true+ use the large arc (i.e. the one spanning more than 180
        # degrees), else the small arc
        attr_reader :large_arc

        # Direction of arc - if +true+ in clockwise direction, else in counterclockwise direction
        attr_reader :clockwise

        # Creates an endpoint arc with default values x=0, y=0, a=0, b=0, inclination=0,
        # large_arc=true, clockwise=false (a line to the origin).
        def initialize
          @x = @y = 0
          @a = @b = 0
          @inclination = 0
          @large_arc = true
          @clockwise = false
        end

        # Configures the endpoint arc with
        #
        # * endpoint (+x+, +y+),
        # * semi-major axis +a+,
        # * semi-minor axis +b+,
        # * an inclination in respect to the x-axis of +inclination+ degrees,
        # * the given large_arc flag and
        # * the given clockwise flag.
        #
        # The +large_arc+ option determines whether the large arc, i.e. the one spanning more than
        # 180 degrees, is used (+true+) or the small arc (+false+).
        #
        # The +clockwise+ option determines if the arc is drawn in the counterclockwise direction
        # (+false+) or in the clockwise direction (+true+).
        #
        # Any arguments not specified are not modified and retain their old value, see #initialize
        # for the inital values.
        #
        # Returns self.
        def configure(x: nil, y: nil, a: nil, b: nil, inclination: nil, large_arc: nil,
                      clockwise: nil)
          @x = x if x
          @y = y if y
          @a = a.abs if a
          @b = b.abs if b
          @inclination = inclination % 360 if inclination
          @large_arc = large_arc unless large_arc.nil?
          @clockwise = clockwise unless clockwise.nil?

          self
        end

        # Draws the arc on the given Canvas.
        def draw(canvas)
          x1, y1 = *canvas.current_point

          # ARC F.6.2 - nothing to do if endpoint is equal to current point
          return if float_equal(x1, @x) && float_equal(y1, @y)

          if @a == 0 || @b == 0
            # ARC F.6.2, F.6.6 - just use a line if it is not really an arc
            canvas.line_to(@x, @y)
          else
            values = compute_arc_values(x1, y1)
            arc = canvas.graphic_object(:arc, values)
            arc.draw(canvas, move_to_start: false)
          end
        end

        private

        # Compute the center parameterization from the endpoint parameterization.
        #
        # The argument (x1, y1) is the starting point.
        #
        # See: ARC F.6.5, F.6.6
        def compute_arc_values(x1, y1)
          x2 = @x
          y2 = @y
          rx = @a
          ry = @b
          theta = deg_to_rad(@inclination)
          cos_theta = Math.cos(theta)
          sin_theta = Math.sin(theta)

          # F.6.5.1
          x1p = (x1 - x2) / 2.0 * cos_theta + (y1 - y2) / 2.0 * sin_theta
          y1p = (x1 - x2) / 2.0 * -sin_theta + (y1 - y2) / 2.0 * cos_theta

          x1ps = x1p**2
          y1ps = y1p**2
          rxs = rx**2
          rys = ry**2

          # F.6.6.2
          l = x1ps / rxs + y1ps / rys
          if l > 1
            rx *= Math.sqrt(l)
            ry *= Math.sqrt(l)
            rxs = rx**2
            rys = ry**2
          end

          # F.6.5.2
          sqrt = Math.sqrt((rxs * rys - rxs * y1ps - rys * x1ps) / (rxs * y1ps + rys * x1ps))
          sqrt *= -1 unless @large_arc == @clockwise
          cxp = sqrt * rx * y1p / ry
          cyp = - sqrt * ry * x1p / rx

          # F.6.5.3
          cx = cos_theta * cxp - sin_theta * cyp + (x1 + x2) / 2.0
          cy = sin_theta * cxp + cos_theta * cyp + (y1 + y2) / 2.0

          # F.6.5.5
          start_angle = compute_angle_to_x_axis((x1p - cxp) / rx, (y1p - cyp) / ry)

          # F.6.5.6 (modified bc we just need the end angle)
          end_angle = compute_angle_to_x_axis((-x1p - cxp) / rx, (-y1p - cyp) / ry)

          {cx: cx, cy: cy, a: rx, b: ry, start_angle: start_angle, end_angle: end_angle,
           inclination: @inclination, clockwise: @clockwise}
        end

        # Compares two float numbers if they are within a certain delta.
        def float_equal(a, b)
          (a - b).abs < 1e-8
        end

        # Computes the angle in degrees between the x-axis and the vector.
        def compute_angle_to_x_axis(vx, vy)
          (vy < 0 ? -1 : 1) * rad_to_deg(Math.acos(vx / Math.sqrt(vx**2 + vy**2)))
        end

      end

    end
  end
end
