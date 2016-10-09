# -*- encoding: utf-8 -*-

require 'hexapdf/font/true_type/table'

module HexaPDF
  module Font
    module TrueType
      class Table

        # The 'name' table contains the human-readable names for features, font names, style names,
        # copyright notices and so on.
        #
        # See: https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6name.html
        class Name < Table

          # Table for mapping symbolic names to name_id codes.
          NAME_MAP = {
            copyright: 0,
            font_family: 1,
            font_subfamily: 2,
            unique_subfamily: 3,
            font_name: 4,
            version: 5,
            postscript_name: 6,
            trademark: 7,
            manufacturer: 8,
            designer: 9,
            description: 10,
            vendor_url: 11,
            designer_url: 12,
            license: 13,
            license_url: 14,
            preferred_family: 16,
            preferred_subfamily: 17,
            compatible_full: 18,
            sample_text: 19,
            postscript_cid_name: 20,
            wws_family: 21,
            wws_subfamily: 22,
          }

          # Contains the information for a Name Record.
          #
          # The string value is converted to UTF-8 if possible, otherwise it stays in BINARY.
          class Record < String

            # Indicates Unicode version.
            PLATFORM_UNICODE = 0

            # QuickDraw Script Manager code for Macintosh.
            PLATFORM_MACINTOSH = 1

            # Microsoft encoding.
            PLATFORM_MICROSOFT = 3

            # The platform identifier code.
            attr_reader :platform_id

            # The platform specific encoding identified.
            attr_reader :encoding_id

            # The language identified.
            attr_reader :language_id

            # Create a new name record.
            def initialize(text, pid, eid, lid)
              @platform_id = pid
              @encoding_id = eid
              @language_id = lid

              if platform?(:unicode) ||
                  (platform?(:microsoft) && encoding_id == 1 || encoding_id == 10)
                text.encode!(::Encoding::UTF_8, ::Encoding::UTF_16BE)
              elsif platform?(:macintosh) && encoding_id == 0
                text.encode!(::Encoding::UTF_8, ::Encoding::MACROMAN)
              end

              super(text)
            end

            # Returns +true+ if this record has the given platform identifier which can either be
            # :unicode, :macintosh or :microsoft.
            def platform?(identifier)
              platform_id == case identifier
                             when :unicode then PLATFORM_UNICODE
                             when :macintosh then PLATFORM_MACINTOSH
                             when :microsoft then PLATFORM_MICROSOFT
                             else
                               raise ArgumentError, "Unknown platform identifier: #{identifier}"
                             end
            end

            # Returns +true+ if this record is a "preferred" one.
            #
            # The label "preferred" is set on a name if it represents the US English version of the
            # name in a decodable encoding:
            # * platform_id :macintosh, encoding_id 0 (Roman) and language_id 0 (English); or
            # * platform_id :microsoft, encoding_id 1 (Unicode) and language_id 1033 (US English).
            def preferred?
              (platform_id == PLATFORM_MACINTOSH && encoding_id == 0 && language_id == 0) ||
                (platform_id == PLATFORM_MICROSOFT && encoding_id == 1 && language_id == 1033)
            end

          end


          # Holds records for the same name type (e.g. :font_name, :postscript_name, ...).
          class Records < Array

            # Returns the preferred record in this collection.
            #
            # This is either the first record where Record#preferred? is true or else just the first
            # record in the collection.
            def preferred_record
              find(&:preferred?) || self[0]
            end

          end


          # The format of the table.
          attr_accessor :format

          # The name records.
          attr_accessor :records

          # The mapping of language IDs starting from 0x8000 to language tags conforming to IETF BCP
          # 47.
          attr_accessor :language_tags

          # Returns an array with all available entries for the given name identifier (either a
          # symbol or an ID).
          #
          # See: NAME_MAP
          def [](name_or_id)
            @records[name_or_id.kind_of?(Symbol) ? NAME_MAP[name_or_id] : name_or_id]
          end

          # Adds a new record for the given name identifier (either a symbol or an ID).
          #
          # The optional platform, encoding and language IDs are preset to represent the text as
          # English in Mac Roman encoding.
          def add(name_or_id, text, platform_id: 1, encoding_id: 0, language_id: 0)
            self[name_or_id] << Record.new(text, platform_id, encoding_id, language_id)
          end

          private

          def parse_table #:nodoc:
            @format, count, string_offset = read_formatted(6, 'n3')
            string_offset += directory_entry.offset

            @records = Hash.new {|h, k| h[k] = Records.new}
            @language_tags = {}

            record_rows = count.times.map { read_formatted(12, 'n6') }
            if @format == 1
              count = read_formatted(2, 'n').first
              language_rows = count.times.map { read_formatted(4, 'n2') }
            end

            record_rows.each do |pid, eid, lid, nid, length, offset|
              io.pos = string_offset + offset
              @records[nid] << Record.new(io.read(length), pid, eid, lid)
            end

            if @format == 1
              language_rows.each_with_index do |(length, offset), index|
                io.pos = string_offset + offset
                @language_tags[0x8000 + index] =
                  io.read(length).encode!(::Encoding::UTF_8, ::Encoding::UTF_16BE)
              end
            end
          end

          def load_default #:nodoc:
            @format = 0
            @records = Hash.new {|h, k| h[k] = Records.new}
            @language_tags = {}
          end

        end

      end
    end
  end
end
