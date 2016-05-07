# -*- encoding: utf-8 -*-

require 'hexapdf/font/ttf/table'

module HexaPDF
  module Font
    module TTF

      # Represents a file in the TrueType font file format.
      class File

        # The default configuration:
        #
        # font.ttf.table_mapping::
        #     The default mapping from table tag as symbol to table class name.
        #
        # font.ttf.cmap.unknown_format::
        #     Action to take when encountering unknown 'cmap' subtables. Can either be :ignore
        #     which ignores them or :raise which raises an error.
        DEFAULT_CONFIG = {
          'font.ttf.table_mapping' => {
            head: 'HexaPDF::Font::TTF::Table::Head',
            cmap: 'HexaPDF::Font::TTF::Table::Cmap',
            hhea: 'HexaPDF::Font::TTF::Table::Hhea',
            hmtx: 'HexaPDF::Font::TTF::Table::Hmtx',
            loca: 'HexaPDF::Font::TTF::Table::Loca',
          },
          'font.ttf.cmap.unknown_format' => :ignore,
        }


        # The IO stream associated with this file. If this is +nil+ then the TrueType font wasn't
        # originally read from an IO stream.
        attr_reader :io

        # The configuration for the TTF font.
        attr_reader :config

        # Creates a new TrueType font file object. If an IO object is given, the TTF font data is
        # read from it.
        #
        # The +config+ hash can contain configuration options.
        def initialize(io = nil, config = {})
          @io = io
          @config = DEFAULT_CONFIG.merge(config)
          @tables = {}
        end

        # Returns the table instance for the given tag (a symbol), or +nil+ if no such table exists.
        def [](tag)
          return @tables[tag] if @tables.key?(tag)

          klass = config['font.ttf.table_mapping'].fetch(tag, 'HexaPDF::Font::TTF::Table')
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
