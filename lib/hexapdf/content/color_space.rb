# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2019 Thomas Leitner
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

require 'hexapdf/error'

module HexaPDF
  module Content

    # This module contains the color space implementations.
    #
    # == General Information
    #
    # The PDF specification defines several color spaces. Probably the most used ones are the
    # device color spaces DeviceRGB, DeviceCMYK and DeviceGray. However, there are several others.
    # For example, patterns are also implemented via color spaces.
    #
    # HexaPDF provides implementations for the most common color spaces. Additional ones can
    # easily be added. After implementing one it just has to be registered on the global
    # configuration object under the 'color_space.map' key.
    #
    # Color space implementations are currently used so that different colors can be
    # distinguished and to provide better error handling.
    #
    #
    # == Color Space Implementations
    #
    # A color space implementation consists of two classes: one for the color space and one for
    # its colors.
    #
    # The class for the color space needs to respond to the following methods:
    #
    # #initialize(definition)::
    #   Creates the color space using the given array with the color space definition. The first
    #   item in the array is always the color space family, the other items are color space
    #   specific.
    #
    # #family::
    #   Returns the PDF name of the color space family this color space belongs to.
    #
    # #definition::
    #   Returns the color space definition as array.
    #
    # #default_color::
    #   Returns the default color for this color space.
    #
    # #color(*args)::
    #   Returns the color corresponding to the given arguments. The number and types of the
    #   arguments differ from one color space to another.
    #
    # The class representing a color in the color space needs to respond to the following methods:
    #
    # #color_space::
    #   Returns the associated color space object.
    #
    # #components::
    #   Returns an array of components that uniquely identifies this color within the color space.
    #
    # See: PDF1.7 s8.6
    module ColorSpace

      # This module includes utility functions that are useful for all color classes.
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
          value.clamp(0, 1)
        end
        private :normalize_value
        module_function :normalize_value

        # Compares this color to another one by looking at their associated color spaces and their
        # components.
        def ==(other)
          other.respond_to?(:components) && other.respond_to?(:color_space) &&
            components == other.components && color_space == other.color_space
        end

      end

      # This class represents a "universal" color space that is used for all color spaces that
      # aren't implemented yet.
      class Universal

        # The color space definition used for creating this universal color space.
        attr_reader :definition

        # Creates the universal color space for the given color space definition.
        def initialize(definition)
          @definition = definition
        end

        # The default universal color.
        def default_color
          Color.new(self)
        end

        # Creates a new universal color object. The number of arguments isn't restricted.
        def color(*args)
          Color.new(self, *args)
        end

        # Returns the PDF color space family this color space belongs to.
        def family
          @definition[0]
        end

        # Compares this universal color space to another one by looking at their definitions.
        def ==(other)
          other.kind_of?(self.class) && definition == other.definition
        end

        # A single color in the universal color space.
        #
        # This doesn't represent a real color but is a place holder for a color in a color space
        # that isn't implemented yet.
        class Color

          include ColorUtils

          # Returns the specific Universal color space used for this color.
          attr_reader :color_space

          # Returns the componets of the universal color, i.e. all arguments provided on
          # initialization.
          attr_reader :components

          # Creates a new universal color with the given components.
          def initialize(color_space, *components)
            @color_space = color_space
            @components = components
          end

        end

      end

      # The DeviceRGB color space.
      class DeviceRGB

        # The one (and only) DeviceRGB color space.
        DEFAULT = new

        # Returns the DeviceRGB color space object.
        def self.new(_definition = nil)
          DEFAULT
        end

        # Returns the default color for the DeviceRGB color space.
        def default_color
          Color.new(0.0, 0.0, 0.0)
        end

        # Returns the color object for the red, green and blue components.
        #
        # Color values can either be integers in the range from 0 to 255 or floating point numbers
        # between 0.0 and 1.0. The integer color values are automatically normalized to the
        # DeviceRGB color value range of 0.0 to 1.0.
        def color(r, g, b)
          Color.new(ColorUtils.normalize_value(r, 255),
                    ColorUtils.normalize_value(g, 255),
                    ColorUtils.normalize_value(b, 255))
        end

        # Returns +:DeviceRGB+.
        def family
          :DeviceRGB
        end

        # A color in the DeviceRGB color space.
        #
        # See: PDF1.7 s8.6.4.3
        class Color

          include ColorUtils

          # Initializes the color with the +r+ (red), +g+ (green) and +b+ (blue) components.
          #
          # Each argument has to be a float between 0.0 and 1.0.
          def initialize(r, g, b)
            @r = r
            @g = g
            @b = b
          end

          # Returns the DeviceRGB color space module.
          def color_space
            DeviceRGB::DEFAULT
          end

          # Returns the RGB color as an array of normalized color values.
          def components
            [@r, @g, @b]
          end

        end

      end

      # The DeviceCMYK color space.
      class DeviceCMYK

        # The one (and only) DeviceCMYK color space.
        DEFAULT = new

        # Returns the DeviceCMYK color space object.
        def self.new(_definition = nil)
          DEFAULT
        end

        # Returns the default color for the DeviceCMYK color space.
        def default_color
          Color.new(0.0, 0.0, 0.0, 1.0)
        end

        # Returns the color object for the given cyan, magenta, yellow and black components.
        #
        # Color values can either be integers in the range from 0 to 100 or floating point numbers
        # between 0.0 and 1.0. The integer color values are automatically normalized to the
        # DeviceCMYK color value range of 0.0 to 1.0.
        def color(c, m, y, k)
          Color.new(ColorUtils.normalize_value(c, 100), ColorUtils.normalize_value(m, 100),
                    ColorUtils.normalize_value(y, 100), ColorUtils.normalize_value(k, 100))
        end

        # Returns +:DeviceCMYK+.
        def family
          :DeviceCMYK
        end

        # A color in the DeviceCMYK color space.
        #
        # See: PDF1.7 s8.6.4.4
        class Color

          include ColorUtils

          # Initializes the color with the +c+ (cyan), +m+ (magenta), +y+ (yellow) and +k+ (black)
          # components.
          #
          # Each argument has to be a float between 0.0 and 1.0.
          def initialize(c, m, y, k)
            @c = c
            @m = m
            @y = y
            @k = k
          end

          # Returns the DeviceCMYK color space module.
          def color_space
            DeviceCMYK::DEFAULT
          end

          # Returns the CMYK color as an array of normalized color values.
          def components
            [@c, @m, @y, @k]
          end

        end

      end

      # The DeviceGray color space.
      class DeviceGray

        # The one (and only) DeviceGray color space.
        DEFAULT = new

        # Returns the DeviceGray color space object.
        def self.new(_definition = nil)
          DEFAULT
        end

        # Returns the default color for the DeviceGray color space.
        def default_color
          Color.new(0.0)
        end

        # Returns the color object for the given gray component.
        #
        # Color values can either be integers in the range from 0 to 255 or floating point numbers
        # between 0.0 and 1.0. The integer color values are automatically normalized to the
        # DeviceGray color value range of 0.0 to 1.0.
        def color(gray)
          Color.new(ColorUtils.normalize_value(gray, 255))
        end

        # Returns +:DeviceGray+.
        def family
          :DeviceGray
        end

        # A color in the DeviceGray color space.
        #
        # See: PDF1.7 s8.6.4.2
        class Color

          include ColorUtils

          # Initializes the color with the +gray+ component.
          #
          # The argument +gray+ has to be a float between 0.0 and 1.0.
          def initialize(gray)
            @gray = gray
          end

          # Returns the DeviceGray color space module.
          def color_space
            DeviceGray::DEFAULT
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
