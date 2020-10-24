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

require 'hexapdf/utils/math_helpers'

module HexaPDF
  module Content
    module GraphicObject

      # This class describes an elliptical in center parameterization arc that is approximated using
      # Bezier curves. It can be used to draw circles, circular arcs, ellipses and elliptical arcs,
      # all either in clockwise or counterclockwise direction and optionally inclined in respect to
      # the x-axis.
      #
      # See: ELL - https://spaceroots.org/documents/ellipse/elliptical-arc.pdf
      class Arc

        include HexaPDF::Utils::MathHelpers

        # Creates and configures a new elliptical arc object.
        #
        # See #configure for the allowed keyword arguments.
        def self.configure(**kwargs)
          new.configure(**kwargs)
        end

        # The maximal number of curves used for approximating a complete ellipse.
        #
        # The higher the value the better the approximation will be but it will also take longer
        # to compute. The value should not be lower than 4. Default value is 6 which already
        # provides a good approximation.
        attr_accessor :max_curves

        # x-coordinate of center point
        attr_reader :cx

        # y-coordinate of center point
        attr_reader :cy

        # Length of semi-major axis
        attr_reader :a

        # Length of semi-minor axis
        attr_reader :b

        # Start angle in degrees
        attr_reader :start_angle

        # End angle in degrees
        attr_reader :end_angle

        # Inclination in degrees of semi-major axis in respect to x-axis
        attr_reader :inclination

        # Direction of arc - if +true+ in clockwise direction, else in counterclockwise direction
        attr_reader :clockwise

        # Creates an elliptical arc with default values (a counterclockwise unit circle at the
        # origin).
        def initialize
          @max_curves = 6
          @cx = @cy = 0
          @a = @b = 1
          @start_angle = 0
          @end_angle = 360
          @inclination = 0
          @clockwise = false
          calculate_cached_values
        end

        # Configures the arc with
        #
        # * center point (+cx+, +cy+),
        # * semi-major axis +a+,
        # * semi-minor axis +b+,
        # * start angle of +start_angle+ degrees,
        # * end angle of +end_angle+ degrees and
        # * an inclination in respect to the x-axis of +inclination+ degrees.
        #
        # The +clockwise+ argument determines if the arc is drawn in the counterclockwise direction
        # (+false+) or in the clockwise direction (+true+).
        #
        # Any arguments not specified are not modified and retain their old value, see #initialize
        # for the inital values.
        #
        # Returns self.
        def configure(cx: nil, cy: nil, a: nil, b: nil, start_angle: nil, end_angle: nil,
                      inclination: nil, clockwise: nil)
          @cx = cx if cx
          @cy = cy if cy
          @a = a.abs if a
          @b = b.abs if b
          if @a == 0 || @b == 0
            raise HexaPDF::Error, "Semi-major and semi-minor axes must be greater than zero"
          end
          @start_angle = start_angle if start_angle
          @end_angle = end_angle if end_angle
          @inclination = inclination if inclination
          @clockwise = clockwise unless clockwise.nil?
          calculate_cached_values
          self
        end

        # Returns the start point of the elliptical arc.
        def start_point
          evaluate(@start_eta)
        end

        # Returns the end point of the elliptical arc.
        def end_point
          evaluate(@end_eta)
        end

        # Returns the point at +angle+ degrees on the ellipse.
        #
        # Note that the point may not lie on the arc itself!
        def point_at(angle)
          evaluate(angle_to_param(angle))
        end

        # Draws the arc on the given Canvas.
        #
        # If the argument +move_to_start+ is +true+, a Canvas#move_to operation is executed to
        # move the current point to the start point of the arc. Otherwise it is assumed that the
        # current point already coincides with the start point
        #
        # The #max_curves value is set to the value of the configuration option
        # 'graphic_object.arc.max_curves' before drawing.
        def draw(canvas, move_to_start: true)
          @max_curves = canvas.context.document.config['graphic_object.arc.max_curves']
          canvas.move_to(*start_point) if move_to_start
          curves.each {|x, y, hash| canvas.curve_to(x, y, **hash) }
        end

        # Returns an array of arrays that contain the points for the Bezier curves which are used
        # for approximating the elliptical arc between #start_point and #end_point.
        #
        # One subarray consists of
        #
        #   [end_point_x, end_point_y, p1: control_point_1, p2: control_point_2]
        #
        # The first start point is the one returned by #start_point, the other start points are
        # the end points of the curve before.
        #
        # The format of the subarray is chosen so that it can be fed to the Canvas#curve_to
        # method by using array splatting.
        #
        # See: ELL s3.4.1 (especially the last box on page 18)
        def curves
          result = []

          # Number of curves to use, maximal segment angle is 2*PI/max_curves
          n = [@max_curves, ((@end_eta - @start_eta).abs / (2 * Math::PI / @max_curves)).ceil].min
          d_eta = (@end_eta - @start_eta) / n

          alpha = Math.sin(d_eta) * (Math.sqrt(4 + 3 * Math.tan(d_eta / 2)**2) - 1) / 3

          eta2 = @start_eta
          p2x, p2y = evaluate(eta2)
          p2x_prime, p2y_prime = derivative_evaluate(eta2)
          1.upto(n) do
            p1x = p2x
            p1y = p2y
            p1x_prime = p2x_prime
            p1y_prime = p2y_prime

            eta2 += d_eta
            p2x, p2y = evaluate(eta2)
            p2x_prime, p2y_prime = derivative_evaluate(eta2)

            result << [p2x, p2y,
                       {p1: [p1x + alpha * p1x_prime, p1y + alpha * p1y_prime],
                        p2: [p2x - alpha * p2x_prime, p2y - alpha * p2y_prime]}]
          end

          result
        end

        private

        # Calculates the values that are derived from the input values and needed for the
        # calculations
        def calculate_cached_values
          theta = deg_to_rad(@inclination)
          @cos_theta = Math.cos(theta)
          @sin_theta = Math.sin(theta)

          # (see ELL s2.2.1) Calculating start_eta and end_eta so that
          #   start_eta < end_eta   <= start_eta + 2*PI if counterclockwise
          #   end_eta   < start_eta <= end_eta + 2*PI   if clockwise
          @start_eta = angle_to_param(@start_angle)
          @end_eta = angle_to_param(@end_angle)
          if !@clockwise && @end_eta <= @start_eta
            @end_eta += 2 * Math::PI
          elsif @clockwise && @end_eta >= @start_eta
            @start_eta += 2 * Math::PI
          end
        end

        # Converts the +angle+ in degrees to the parameter used for the parametric function
        # defining the ellipse.
        #
        # The return value is between 0 and 2*PI.
        def angle_to_param(angle)
          angle = deg_to_rad(angle % 360)
          eta = Math.atan2(Math.sin(angle) / @b, Math.cos(angle) / @a)
          eta += 2 * Math::PI if eta < 0
          eta
        end

        # Returns an array containing the x and y coordinates of the point on the elliptical arc
        # specified by the parameter +eta+.
        #
        # See: ELL s2.2.1 (3)
        def evaluate(eta)
          a_cos_eta = @a * Math.cos(eta)
          b_sin_eta = @b * Math.sin(eta)
          [@cx + a_cos_eta * @cos_theta - b_sin_eta * @sin_theta,
           @cy + a_cos_eta * @sin_theta + b_sin_eta * @cos_theta]
        end

        # Returns an array containing the derivative of the parametric function defining the
        # ellipse evaluated at +eta+.
        #
        # See: ELL s2.2.1 (4)
        def derivative_evaluate(eta)
          a_sin_eta = @a * Math.sin(eta)
          b_cos_eta = @b * Math.cos(eta)
          [- a_sin_eta * @cos_theta - b_cos_eta * @sin_theta,
           - a_sin_eta * @sin_theta + b_cos_eta * @cos_theta]
        end

      end

    end
  end
end
