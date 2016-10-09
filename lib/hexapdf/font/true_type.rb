# -*- encoding: utf-8 -*-

module HexaPDF
  module Font

    # This module provides classes for handling TrueType fonts.
    #
    # Note that currently not all parts of the file format are supported, only those needed for
    # using the fonts with PDF.
    module TrueType

      autoload(:Font, 'hexapdf/font/true_type/font')

    end

  end
end
