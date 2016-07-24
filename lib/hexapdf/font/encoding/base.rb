# -*- encoding: utf-8 -*-

require 'hexapdf/font/encoding/glyph_list'

module HexaPDF
  module Font
    module Encoding

      # Base for encoding classes that are used for mapping codes in the range of 0 to 255 to glyph
      # names.
      class Base

        # The name of the encoding or +nil+ if the encoding has not been assigned a name.
        attr_reader :encoding_name

        # The hash mapping codes to names.
        attr_reader :code_to_name

        # Creates a new encoding object containing no default mappings.
        def initialize
          @code_to_name = {}
          @unicode_cache = {}
          @encoding_name = nil
        end

        # Returns the name for the given code, or .notdef if no glyph for the code is defined.
        #
        # The returned value is always a Symbol object!
        def name(code)
          @code_to_name.fetch(code, :'.notdef')
        end

        # Returns the Unicode value in UTF-8 for the given code, or an empty string if the code
        # cannot be mapped.
        #
        # Note that this method caches the result of the Unicode mapping and therefore should only
        # be called after all codes have been defined.
        def unicode(code)
          @unicode_cache[code] ||= GlyphList.name_to_unicode(name(code))
        end

      end

    end
  end
end
