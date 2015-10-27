# -*- encoding: utf-8 -*-

module HexaPDF
  module Font
    module Encoding

      # Base for encoding classes that are used for mapping codes in the range of 0 to 255 to glyph
      # names.
      class Base

        # The hash mapping codes to names.
        attr_reader :code_to_name

        # Creates a new encoding object containing no default mappings.
        def initialize
          @code_to_name = {}
        end

        # Returns the name for the given code, or .notdef if no glyph for the code is defined.
        #
        # The returned value is always a Symbol object!
        def name(code)
          @code_to_name.fetch(code, :'.notdef')
        end

      end

    end
  end
end
