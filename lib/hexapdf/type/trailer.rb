# -*- encoding: utf-8 -*-

require 'hexapdf/dictionary'
require 'digest/md5'

module HexaPDF
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
    # See: PDF1.7 s7.5.5, s14.4
    #      XRefStream
    class Trailer < Dictionary

      define_field :Size,    type: Integer, indirect: false # will be auto-set when written
      define_field :Prev,    type: Integer
      define_field :Root,    type: :Catalog, indirect: true
      define_field :Encrypt, type: Dictionary
      define_field :Info,    type: :Info, indirect: true
      define_field :ID,      type: Array
      define_field :XRefStm, type: Integer, version: '1.5'

      define_validator(:validate_trailer)


      # Sets the /ID field to an array of two copies of a random string and returns this array.
      #
      # See: PDF1.7 14.4
      def set_random_id
        value[:ID] = [Digest::MD5.digest(rand.to_s)] * 2
      end

      # Updates the second part of the /ID field (the first part should always be the same for a
      # PDF file, the second part should change with each write).
      def update_id
        if !value[:ID]
          set_random_id
        else
          value[:ID][1] = Digest::MD5.digest(rand.to_s)
        end
      end

      private

      # Validates the trailer.
      def validate_trailer
        unless value[:ID]
          msg = if value[:Encrypt]
                  "ID field is required when an Encrypt dictionary is present"
                else
                  "ID field should always be set"
                end
          yield(msg, true)
          set_random_id
        end

        unless value[:Root]
          yield("A PDF document must have a Catalog dictionary", true)
          value[:Root] = document.add(Type: :Catalog)
          value[:Root].validate {|message, correctable| yield(message, correctable)}
        end
      end

    end

  end
end
