# -*- encoding: utf-8 -*-

module HexaPDF
  module Font

    # Represents a CMap, a mapping from character codes to CIDs (character IDs) or to their Unicode
    # value.
    #
    # Currently, only the mapping to the Unicode values is supported.
    #
    # See: PDF1.7 s9.7.5, s9.10.3
    class CMap

      autoload(:Parser, 'hexapdf/font/cmap/parser')

      # Creates a new CMap object from the given string which needs to contain a valid CMap file.
      def self.parse(string)
        Parser.new.parse(string)
      end

      # The registry part of the CMap version.
      attr_accessor :registry

      # The ordering part of the CMap version.
      attr_accessor :ordering

      # The supplement part of the CMap version.
      attr_accessor :supplement

      # The name of the CMap.
      attr_accessor :name

      # The mapping from character codes to Unicode values.
      attr_accessor :unicode_mapping

      # Creates a new CMap object.
      def initialize
        @unicode_mapping = {}
      end

      # Returns the Unicode string in UTF-8 encoding for the given character code.
      def to_unicode(code)
        unicode_mapping[code]
      end

    end

  end
end
