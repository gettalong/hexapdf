# -*- encoding: utf-8 -*-

require 'hexapdf/data_dir'

module HexaPDF
  module Font

    # Contains implementations of the encodings used for fonts.
    module Encoding

      autoload(:Base, 'hexapdf/font/encoding/base')
      autoload(:StandardEncoding, 'hexapdf/font/encoding/standard_encoding')
      autoload(:MacRomanEncoding, 'hexapdf/font/encoding/mac_roman_encoding')
      autoload(:WinAnsiEncoding, 'hexapdf/font/encoding/win_ansi_encoding')
      autoload(:GlyphList, 'hexapdf/font/encoding/glyph_list')

      # Returns the encoding object for the given name, or +nil+ if no such encoding is available.
      def self.for_name(name)
        case name
        when :WinAnsiEncoding then @win_ansi ||= WinAnsiEncoding.new
        when :MacRomanEncoding then @mac_roman ||= MacRomanEncoding.new
        when :StandardEncoding then @standard ||= StandardEncoding.new
        else nil
        end
      end

    end

  end
end
