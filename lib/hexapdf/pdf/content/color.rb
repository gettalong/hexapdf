# -*- encoding: utf-8 -*-

require 'hexapdf/error'

module HexaPDF
  module PDF
    module Content

      # This module includes utility functions that are useful for all color classes.
      #
      # See: PDF1.7 s8.6
      module ColorUtils

        # Normalizes the given color value so that it is in the range from 0.0 to 1.0.
        #
        # The conversion is done in the following way:
        #
        # * If the color value is an Integer, it is converted to a float and divided by +upper+.
        # * If the color value is greater than 1.0, it is set to 1.0.
        # * If the color value is less than 0.0, it is set to 0.0.
        def normalize_value(value, upper)
          value = value.to_f / upper if value.kind_of?(Integer)
          (value < 0 ? 0.0 : (value > 1 ? 1.0 : value))
        end
        private :normalize_value

        # Compares this color to another one by converting both to their RGB representation.
        def ==(other)
          other.respond_to?(:components) && other.respond_to?(:color_space) &&
            components == other.components && color_space == other.color_space
        end

      end

      # This class represents a "universal" color space that is used for all color spaces that
      # aren't implemented yet.
      module UniversalColorSpace

        # The default universal color.
        def self.default_color
          Color.new
        end

        # Creates a new universal color object. The number of arguments isn't restricted.
        def self.color(*args)
          Color.new(*args)
        end

        # A single color in the universal color space.
        #
        # This doesn't represent a real color but is a place holder for a color in a color space
        # that isn't implemented yet.
        class Color

          include ColorUtils

          # Creates a new universal color with the given components.
          def initialize(*components)
            @components = components
          end

          # Returns the UniversalColorSpace module.
          def color_space
            UniversalColorSpace
          end

          # Returns the componets of the universal color, i.e. all arguments provided on
          # initialization.
          def components
            @components
          end

        end

      end


      # The DeviceRGB color space that manages the DeviceRGBColorSpace::Color objects.
      module DeviceRGBColorSpace

        # Returns the default color for the DeviceRGB color space.
        def self.default_color
          Color.new(0.0, 0.0, 0.0)
        end

        # Returns the color object for the given red, green and blue components.
        def self.color(r, g, b)
          Color.new(r, g, b)
        end

        # A color in the DeviceRGB color space.
        #
        # The color values are automatically normalized to the DeviceRGB color value range of 0.0 to
        # 1.0.
        #
        # See: PDF1.7 s8.6.4.3
        class Color

          include ColorUtils

          # Initializes the color with the +r+ (red), +g+ (green) and +b+ (blue) components.
          #
          # Each argument has to be either an integer between 0 and 255 or a float between 0.0 and
          # 1.0.
          def initialize(r, g, b)
            @r = normalize_value(r, 255)
            @g = normalize_value(g, 255)
            @b = normalize_value(b, 255)
          end

          # Returns the DeviceRGB color space module.
          def color_space
            DeviceRGBColorSpace
          end

          # Returns the RGB color as an array of normalized color values.
          def components
            [@r, @g, @b]
          end

        end

      end


      # The DeviceCMYK color space that manages the DeviceCYMKColorSpace::Color objects.
      module DeviceCMYKColorSpace

        # Returns the default color for the DeviceCMYK color space.
        def self.default_color
          Color.new(0.0, 0.0, 0.0, 1.0)
        end

        # Returns the color object for the given cyan, magenta, yellow and black components.
        def self.color(c, m, y, k)
          Color.new(c, m, y, k)
        end

        # A color in the DeviceCMYK color space.
        #
        # The color values are automatically normalized to the DeviceCMYK color value range of 0.0
        # to 1.0.
        #
        # See: PDF1.7 s8.6.4.4
        class Color

          include ColorUtils

          # Initializes the color with the +c+ (cyan), +m+ (magenta), +y+ (yellow) and +k+ (black)
          # components.
          #
          # Each argument has to be either an integer between 0 and 100 or a float between 0.0 and
          # 1.0.
          def initialize(c, m, y, k)
            @c = normalize_value(c, 255)
            @m = normalize_value(m, 255)
            @y = normalize_value(y, 255)
            @k = normalize_value(k, 255)
          end

          # Returns the DeviceCMYK color space module.
          def color_space
            DeviceCMYKColorSpace
          end

          # Returns the CMYK color as an array of normalized color values.
          def components
            [@c, @y, @m, @k]
          end

        end

      end


      # The DeviceGray color space that manages the DeviceGrayColorSpace::Color objects.
      module DeviceGrayColorSpace

        # Returns the default color for the DeviceGray color space.
        def self.default_color
          Color.new(0.0)
        end

        # Returns the color object for the given gray component.
        def self.color(gray)
          Color.new(gray)
        end

        # A color in the DeviceGray color space.
        #
        # The color values are automatically normalized to the DeviceGray color value range of 0.0 to
        # 1.0.
        #
        # See: PDF1.7 s8.6.4.2
        class Color

          include ColorUtils

          # Initializes the color with the +gray+ component.
          #
          # The argument +gray+ has to be either an integer between 0 and 255 or a float between 0.0
          # and 1.0.
          def initialize(gray)
            @gray = normalize_value(gray, 255)
          end

          # Returns the DeviceGray color space module.
          def color_space
            DeviceGrayColorSpace
          end

          # Returns the normalized gray value as an array.
          def components
            [@gray]
          end

        end

      end

    end
  end
end
