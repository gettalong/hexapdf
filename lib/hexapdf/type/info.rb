# -*- encoding: utf-8 -*-

require 'hexapdf/dictionary'

module HexaPDF
  module Type

    # Represents the PDF's document information dictionary.
    #
    # The info dictionary is linked via the /Info entry from the Trailer and contains metadata for
    # the document.
    #
    # See: PDF1.7 s14.3.3, Trailer
    class Info < Dictionary

      define_field :Title,        type: String, version: '1.1'
      define_field :Author,       type: String
      define_field :Subject,      type: String, version: '1.1'
      define_field :Keywords,     type: String, version: '1.1'
      define_field :Creator,      type: String
      define_field :Producer,     type: String
      define_field :CreationDate, type: PDFDate
      define_field :ModDate,      type: PDFDate
      define_field :Trapped,      type: Symbol, version: '1.3'

      # Returns :XXInfo
      def type
        :XXInfo
      end

    end

  end
end
