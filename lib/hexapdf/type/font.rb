# -*- encoding: utf-8 -*-

require 'hexapdf/stream'
require 'hexapdf/font/cmap'

module HexaPDF
  module Type

    # Represents a generic font object.
    #
    # This class is the base class for all font objects, be it simple fonts or composite fonts.
    class Font < Dictionary

      define_field :Type, type: Symbol, required: true, default: :Font
      define_field :BaseFont, type: Symbol, required: true
      define_field :ToUnicode, type: Stream, version: '1.2'

      # Returns the UTF-8 string for the given character code, or an empty string if no mapping was
      # found.
      def to_utf8(code)
        if to_unicode_cmap
          to_unicode_cmap.to_unicode(code)
        else
          ''.freeze
        end
      end

      private

      # Parses and caches the ToUnicode CMap.
      def to_unicode_cmap
        unless defined?(@to_unicode_cmap)
          @to_unicode_cmap = if key?(:ToUnicode)
                               HexaPDF::Font::CMap.parse(self[:ToUnicode].stream)
                             else
                               nil
                             end
        end
        @to_unicode_cmap
      end

    end

  end
end
