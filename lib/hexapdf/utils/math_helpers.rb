# -*- encoding: utf-8 -*-

module HexaPDF
  module Utils

    # This module provides some mathematical helper functions.
    module MathHelpers

      module_function

      # Converts degrees to radians.
      def deg_to_rad(degrees)
        degrees * Math::PI / 180
      end

    end

  end
end
