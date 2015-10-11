# -*- encoding: utf-8 -*-

module HexaPDF
  module Font

    # This module provides classes for handling Type1 fonts.
    #
    # Note that not all parts of the file format are supported, only those needed for using the
    # fonts with PDF.
    module Type1

      autoload(:AFMParser, 'hexapdf/font/type1/afm_parser')
      autoload(:FontMetrics, 'hexapdf/font/type1/font_metrics')
      autoload(:CharacterMetrics, 'hexapdf/font/type1/character_metrics')

    end

  end
end
