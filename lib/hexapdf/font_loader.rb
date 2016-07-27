# -*- encoding: utf-8 -*-

module HexaPDF

  # == Overview
  #
  # A *font loader* is a callable object that loads a font based on the given name and options. If
  # the font loader doesn't have the requested font, it has to return +nil+.
  #
  # The returned object has to be a PDF font wrapper and not the generic font object because it
  # needs to be usable by the PDF canvas.
  #
  #
  # == Implementation of a Font Loader
  #
  # Each font loader is a (stateless) object (normally a module) that has to be callable, i.e. it
  # has to provide the following method:
  #
  # call(document, name, **options)::
  #     Should return the font wrapper customized for the given document if the font is known or
  #     else +nil+.
  #
  # The +options+ argument is font loader dependent. However, all font loaders should handle the
  # following common options:
  #
  # variant:: The font variant that should be used (e.g. :none, :bold, :italic, :bold_italic).
  module FontLoader

    autoload(:Standard14, 'hexapdf/font_loader/standard14')

  end

end
