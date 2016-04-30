# -*- encoding: utf-8 -*-

require 'hexapdf/font/ttf/table'

module HexaPDF
  module Font
    module TTF

      # Represents a file in the TrueType font file format.
      class File

        # The default mapping from table tag as symbol to table class name.
        DEFAULT_MAPPING = {
          head: 'HexaPDF::Font::TTF::Table::Head',
        }


        # The IO stream associated with this file. If this is +nil+ then the TrueType font wasn't
        # originally read from an IO stream.
        attr_reader :io

        # The mapping from table tag as symbol to table class name.
        attr_reader :table_mapping

        # Creates a new TrueType font file object. If an IO object is given, the TTF font data is
        # read from it.
        def initialize(io = nil)
          @io = io
          @table_mapping = DEFAULT_MAPPING.dup
          @tables = {}
        end

        # Returns the table instance for the given tag (a symbol), or +nil+ if no such table exists.
        def table(tag)
          return @tables[tag] if @tables.key?(tag)

          klass = table_mapping.fetch(tag, 'HexaPDF::Font::TTF::Table')
          entry = directory.entry(tag.to_s.b)
          entry ? @tables[tag] = ::Object.const_get(klass).new(self, entry) : nil
        end

        # Returns the font directory.
        def directory
          @directory ||= Table::Directory.new(self, io ? Table::Directory::SELF_ENTRY : nil)
        end

      end

    end
  end
end
