# -*- encoding: utf-8 -*-

require 'hexapdf/type/font_simple'

module HexaPDF
  module Type

    # Represents a TrueType font.
    class FontTrueType < FontSimple

      define_field :Subtype, type: Symbol, required: true, default: :TrueType

    end

  end
end
