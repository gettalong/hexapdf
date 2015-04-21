# -*- encoding: utf-8 -*-

require 'hexapdf/pdf/dictionary'

module HexaPDF
  module PDF
    module Type

      # Represents the PDF file trailer.
      #
      # The file trailer is the starting point for the PDF's object tree. It links to the Catalog
      # (the main PDF document structure) and the Info dictionary and holds the information
      # necessary for encrypting the PDF document.
      #
      # Since a PDF document can contain multiple revisions, each revision needs to have its own
      # file trailer (see Revision#trailer).
      #
      # When cross-reference streams are used the information that is normally stored in the file
      # trailer is stored directly in the cross-reference stream dictionary. However, a Revision
      # object's trailer dictionary is always of this type. Only when a cross-reference stream is
      # written is the trailer integrated into the stream's dictionary.
      #
      # See: PDF1.7 s7.5.5
      #      XRefStream
      class Trailer < Dictionary

        define_field :Size, type: Integer, indirect: false # will be auto-set when written
        define_field :Prev, type: Integer
        define_field :Root, type: Dictionary, indirect: true
        define_field :Encrypt, type: Hash   # type Hash to avoid automatic creation on access
        define_field :Info, type: 'HexaPDF::PDF::Type::Info', indirect: true
        define_field :ID, type: Array
        define_field :XRefStm, type: Integer, version: '1.5'

        define_validator(:validate_trailer)


        # Sets the /ID field to a random array of two strings.
        def set_random_id
          value[:ID] = [Digest::MD5.digest(rand.to_s), Digest::MD5.digest(rand.to_s)]
        end

        private

        # Validates the trailer.
        def validate_trailer
          if !value[:ID]
            msg = if value[:Encrypt]
                    "ID field is required when an Encrypt dictionary is present"
                  else
                    "ID field should always be set"
                  end
            yield(msg, true)
            set_random_id
          end
        end

      end

    end
  end
end
