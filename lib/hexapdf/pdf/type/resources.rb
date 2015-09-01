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
        # If the color space is not found, an error is raised.
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
            elsif space_definition.kind_of?(Array)
              space_definition.map! {|item| document.deref(item)}
              space_family = space_definition[0]
            else
              space_family = space_definition
              space_definition = [space_definition]
            end

            GlobalConfiguration.constantize('color_space.map'.freeze, space_family) do
              Content::ColorSpace::Universal
            end.new(space_definition)
          end
        end

        # Adds the color space to the resources and returns the name under which it is stored.
        #
        # If there already exists a color space with the same definition, it is reused. The device
        # color spaces :DeviceGray, :DeviceRGB and :DeviceCMYK are never stored, their respective
        # name is just returned.
        def add_color_space(color_space)
          family = color_space.family
          return family if family == :DeviceRGB || family == :DeviceGray || family == :DeviceCMYK

          definition = color_space.definition
          self[:ColorSpace] = {} unless key?(:ColorSpace)
          color_space_dict = self[:ColorSpace]

          name, _value = color_space_dict.value.find do |_k, v|
            v.map! {|item| document.deref(item)}
            v == definition
          end
          unless name
            name = create_resource_name(color_space_dict.value, 'CS')
            color_space_dict[name] = definition
          end
          name
        end

        # Returns the XObject stored under the given name.
        #
        # If the XObject is not found, an error is raised.
        def xobject(name)
          object_getter(:XObject, name)
        end

        # Adds the XObject to the resources and returns the name under which it is stored.
        #
        # If there already exists a name for the given XObject, it is just returned.
        def add_xobject(object)
          object_setter(:XObject, 'XO'.freeze, object)
        end

        # Returns the graphics state parameter dictionary (see GraphicsStateParameter) stored under
        # the given name.
        #
        # If the dictionary is not found, an error is raised.
        def ext_gstate(name)
          object_getter(:ExtGState, name)
        end

        # Adds the graphics state parameter dictionary to the resources and returns the name under
        # which it is stored.
        #
        # If there already exists a name for the given dictionary, it is just returned.
        def add_ext_gstate(object)
          object_setter(:ExtGState, 'GS'.freeze, object)
        end

        private

        # Helper method for returning an entry of a subdictionary.
        def object_getter(dict_name, name)
          obj = self[dict_name] && self[dict_name][name]
          if obj.nil?
            raise HexaPDF::Error, "No object called '#{name}' stored under /#{dict_name}"
          end
          obj
        end

        # Helper method for setting an entry of a subdictionary.
        def object_setter(dict_name, prefix, object)
          self[dict_name] = {} unless key?(dict_name)
          dict = self[dict_name]
          name, _value = dict.each.find {|_, dict_obj| dict_obj == object}
          unless name
            name = create_resource_name(dict.value, prefix)
            dict[name] = object
          end
          name
        end

        # Returns a unique name that can be used to store a resource in the given hash.
        def create_resource_name(hash, prefix)
          n = hash.size + 1
          while true
            name = :"#{prefix}#{n}"
            return name unless hash.key?(name)
            n += 1
          end
        end

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
