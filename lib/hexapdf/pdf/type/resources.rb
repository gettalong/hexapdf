# -*- encoding: utf-8 -*-

require 'hexapdf/error'
require 'hexapdf/pdf/configuration'
require 'hexapdf/pdf/dictionary'
require 'hexapdf/pdf/content/color_space'

module HexaPDF
  module PDF
    module Type

      # Represents the resources needed by a content stream.
      #
      # See: PDF1.7 s7.8.3
      class Resources < Dictionary

        define_field :ExtGState, type: Dictionary
        define_field :ColorSpace, type: Dictionary
        define_field :Pattern, type: Dictionary
        define_field :Shading, type: Dictionary, version: '1.3'
        define_field :XObject, type: Dictionary
        define_field :Font, type: Dictionary
        define_field :ProcSet, type: Array
        define_field :Properties, type: Dictionary, version: '1.2'

        define_validator(:validate_resources)

        # Returns the color space stored under the given name.
        #
        # Note: The color spaces :DeviceGray, :DeviceRGB and :DeviceCMYK are returned without a
        # lookup since they are fixed.
        def color_space(name)
          case name
          when :DeviceRGB, :DeviceGray, :DeviceCMYK
            GlobalConfiguration.constantize('color_space.map'.freeze, name).new
          else
            space_definition = self[:ColorSpace] && self[:ColorSpace][name]
            if space_definition.nil?
              raise HexaPDF::Error, "Color space '#{name}' not found in the resources"
            end
            space_name = (space_definition.kind_of?(Array) ? space_definition[0] : space_definition)

            GlobalConfiguration.constantize('color_space.map'.freeze, space_name) do
              Content::ColorSpace::Universal
            end.new(space_definition)
          end
        end

        private

        # Ensures that a valid procedure set is available.
        def validate_resources
          val = self[:ProcSet]
          if !val
            self[:ProcSet] = [:PDF, :Text, :ImageB, :ImageC, :ImageI]
          else
            val.reject! do |name|
              case name
              when :PDF, :Text, :ImageB, :ImageC, :ImageI
                false
              else
                yield("Invalid page procedure set name /#{name}", true)
                true
              end
            end
          end
        end

      end

    end
  end
end
