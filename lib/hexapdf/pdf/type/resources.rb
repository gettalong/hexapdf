# -*- encoding: utf-8 -*-

require 'hexapdf/pdf/dictionary'

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
