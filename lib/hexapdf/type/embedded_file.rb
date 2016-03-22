# -*- encoding: utf-8 -*-

require 'hexapdf/stream'

module HexaPDF
  module Type

    # Represents an embedded file stream.
    #
    # An embedded file stream contains the data of, and optionally some meta data about, a file
    # that is embedded into the PDF file. Each embedded file is either associated with a certain
    # FileSpecification dictionary or with the document as a whole through the /EmbeddedFiles
    # entry in the document catalog's /Names dictionary.
    #
    # See: PDF1.7 s7.11.4, FileSpecification
    class EmbeddedFile < Stream

      # The type used for the /Mac field of a Parameters dictionary.
      class MacInfo < Dictionary

        define_field :Subtype, type: Integer
        define_field :Creator, type: Integer
        define_field :ResFork, type: Stream

        # Returns :XXEmbeddedFileParametersMacInfo
        def type
          :XXEmbeddedFileParametersMacInfo
        end

      end

      # The type used for the /Params field of an EmbeddedFileStream.
      class Parameters < Dictionary

        define_field :Size,         type: Integer
        define_field :CreationDate, type: PDFDate
        define_field :ModDate,      type: PDFDate
        define_field :Mac,          type: :XXEmbeddedFileParametersMacInfo
        define_field :CheckSum,     type: PDFByteString

        # Returns :XXEmbeddedFileParameters
        def type
          :XXEmbeddedFileParameters
        end

      end


      define_field :Type,    type: Symbol, default: :EmbeddedFile, version: '1.3'
      define_field :Subtype, type: Symbol
      define_field :Params,  type: :XXEmbeddedFileParameters

    end

  end
end
