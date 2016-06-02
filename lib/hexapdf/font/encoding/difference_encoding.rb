# -*- encoding: utf-8 -*-

require 'hexapdf/font/encoding/base'

module HexaPDF
  module Font
    module Encoding

      # The difference encoding uses a base encoding that can be overlayed with additional mappings.
      #
      # See: PDF1.7 s9.6.6.1
      class DifferenceEncoding < Base

        # The base encoding.
        attr_reader :base_encoding

        # Initializes the Differences object with the given base encoding object.
        def initialize(base_encoding)
          super()
          @base_encoding = base_encoding
        end

        # Returns the name for the given code, either from this object, if it contains the code, or
        # from the base encoding.
        def name(code)
          code_to_name[code] || base_encoding.name(code)
        end

      end

    end
  end
end
