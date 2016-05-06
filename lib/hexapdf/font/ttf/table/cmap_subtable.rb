# -*- encoding: utf-8 -*-

require 'hexapdf/font/ttf/table'

module HexaPDF
  module Font
    module TTF
      class Table

        # Generic base class for all cmap subtables.
        #
        # cmap format 8.0 is currently not implemented because use of the format is discouraged in
        # the specification and no font with a format 8.0 cmap subtable was available for testing.
        #
        # See:
        # * Cmap
        # * https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6cmap.html
        class CmapSubtable

          # The platform identifier for Unicode.
          PLATFORM_UNICODE = 0

          # The platform identifier for Microsoft.
          PLATFORM_MICROSOFT = 3

          # The platform identifier.
          attr_accessor :platform_id

          # The platform-specific encoding identifier.
          attr_accessor :encoding_id

          # The cmap format or +nil+ if the subtable wasn't read from a file.
          attr_reader :format

          # The language code.
          attr_accessor :language

          # The complete code map.
          attr_accessor :code_map

          # Creates a new subtable.
          def initialize(platform_id, encoding_id)
            @platform_id = platform_id
            @encoding_id = encoding_id
            @supported = true
            @code_map = {}
            @format = nil
            @language = 0
          end

          # Returns +true+ if this subtable contains a unicode cmap.
          def unicode?
            (platform_id == PLATFORM_MICROSOFT && (encoding_id == 1 || encoding_id == 10)) ||
              platform_id == PLATFORM_UNICODE
          end

          # Returns the glyph index for the given character code.
          def [](code)
            @code_map[code] || 0
          end

          # :call-seq:
          #   subtable.parse!(io, offset)     => true or false
          #
          # Parses the cmap subtable from the IO at the given offset.
          #
          # If the subtable format is supported, the information is used to populate this object and
          # +true+ is returned. Otherwise nothing is done and +false+ is returned.
          def parse(io, offset)
            io.pos = offset
            @format = io.read(2).unpack('n').first
            if [8, 10, 12].include?(@format)
              io.pos += 2
              length, @language = io.read(8).unpack('N2')
            elsif [0, 2, 4, 6].include?(@format)
              length, @language = io.read(4).unpack('n2')
            end
            supported = true
            @code_map = case @format
                        when 0 then Format0.parse(io, length)
                        when 2 then Format2.parse(io, length)
                        when 4 then Format4.parse(io, length)
                        when 6 then Format6.parse(io, length)
                        when 10 then Format10.parse(io, length)
                        when 12 then Format12.parse(io, length)
                        else
                          supported = false
                          {}
                        end
            supported
          end

          def inspect #:nodoc:
            "#<#{self.class.name} (#{platform_id}, #{encoding_id}, #{language}, " \
              "#{format.inspect}) code_map=#{@code_map}>"
          end


          # Cmap format 0
          module Format0

            # :call-seq:
            #   Format0.parse(io, length)    -> code_map
            #
            # Parses the format 0 cmap subtable from the given IO at the current position and
            # returns the contained code map.
            #
            # It is assumed that the first six bytes of the subtable have already been consumed.
            def self.parse(io, length)
              raise HexaPDF::Error, "Invalid length #{length} for cmap format 0" if length != 262
              io.read(256).unpack('C*')
            end

          end


          # Cmap format 2
          module Format2

            SubHeader = Struct.new(:first_code, :entry_count, :id_delta, :first_glyph_index)

            # :call-seq:
            #   Format2.parse(io, length)    -> code_map
            #
            # Parses the format 2 cmap subtable from the given IO at the current position and
            # returns the contained code map.
            #
            # It is assumed that the first six bytes of the subtable have already been consumed.
            def self.parse(io, length)
              sub_header_keys = io.read(512).unpack('n*')
              nr_sub_headers = 0
              sub_header_keys.map! do |key|
                nr_sub_headers = key if key > nr_sub_headers
                key / 8
              end
              nr_sub_headers = 1 + nr_sub_headers / 8
              sub_headers = []
              nr_sub_headers.times do |i|
                h = SubHeader.new(*io.read(8).unpack('n2s>n'))
                # Map the currently stored id_range_offset to the corresponding glyph index by first
                # changing the offset to begin from the position of the first glyph index and then
                # halfing the value since each glyph is a UInt16.
                h.first_glyph_index = (h.first_glyph_index - 2 - 8 * (nr_sub_headers - i - 1)) / 2
                sub_headers << h
              end
              glyph_indexes = io.read(length - 6 - 512 - 8 * nr_sub_headers).unpack('n*')
              mapper(sub_header_keys, sub_headers, glyph_indexes)
            end

            def self.mapper(sub_header_keys, sub_headers, glyph_indexes) #:nodoc:
              Hash.new do |h, code|
                i = code
                i, j = i.divmod(256)
                k = sub_header_keys[i]
                if !k
                  glyph_id = 0
                elsif k > 0
                  sub_header = sub_headers[k]
                  j -= sub_header.first_code
                  if 0 <= j && j < sub_header.entry_count
                    glyph_id = glyph_indexes[sub_header.first_glyph_index + j]
                    glyph_id = (glyph_id + sub_header.id_delta) % 65536 if glyph_id != 0
                  else
                    glyph_id = 0
                  end
                else
                  glyph_id = glyph_indexes[i]
                end
                h[code] = glyph_id
              end
            end

          end


          # Cmap format 4
          module Format4

            # :call-seq:
            #   Format4.parse(io, length)    -> code_map
            #
            # Parses the format 4 cmap subtable from the given IO at the current position and
            # returns the contained code map.
            #
            # It is assumed that the first six bytes of the subtable have already been consumed.
            def self.parse(io, length)
              seg_count_x2 = io.read(8).unpack('n').first
              end_codes = io.read(seg_count_x2).unpack('n*')
              io.pos += 2
              start_codes = io.read(seg_count_x2).unpack('n*')
              id_deltas = io.read(seg_count_x2).unpack('n*')
              id_range_offsets = io.read(seg_count_x2).unpack('n*').map!.with_index do |offset, idx|
                # Change offsets to indexes, starting from the id_range_offsets array
                offset == 0 ? offset : offset / 2 + idx
              end
              glyph_indexes = io.read(length - 16 - seg_count_x2 * 4).unpack('n*')
              mapper(end_codes, start_codes, id_deltas, id_range_offsets, glyph_indexes)
            end

            def self.mapper(end_codes, start_codes, id_deltas, id_range_offsets, glyph_indexes) #:nodoc:
              Hash.new do |h, code|
                i = end_codes.bsearch_index {|c| c >= code}
                if i && start_codes[i] <= code
                  offset = id_range_offsets[i]
                  if offset != 0
                    glyph_id = glyph_indexes[offset - end_codes.length + (code - start_codes[i])]
                    glyph_id = (glyph_id + id_deltas[i]) % 65536 if glyph_id != 0
                  else
                    glyph_id = (code + id_deltas[i]) % 65536
                  end
                else
                  glyph_id = 0
                end
                h[code] = glyph_id
              end
            end

          end


          # Cmap format 6
          module Format6

            # :call-seq:
            #   Format6.parse(io, length)    -> code_map
            #
            # Parses the format 6 cmap subtable from the given IO at the current position and
            # returns the contained code map.
            #
            # It is assumed that the first six bytes of the subtable have already been consumed.
            def self.parse(io, _length)
              first_code, entry_count = io.read(4).unpack('n2')
              code_map = io.read(2 * entry_count).unpack('n*')
              if first_code != 0
                code_map = code_map.each_with_index.with_object({}) do |(g, i), hash|
                  hash[first_code + i] = g
                end
              end
              code_map
            end

          end


          # Cmap format 10
          module Format10

            # :call-seq:
            #   Format10.parse(io, length)    -> code_map
            #
            # Parses the format 10 cmap subtable from the given IO at the current position and
            # returns the contained code map.
            #
            # It is assumed that the first twelve bytes of the subtable have already been consumed.
            def self.parse(io, _length)
              first_code, entry_count = io.read(8).unpack('N2')
              code_map = io.read(2 * entry_count).unpack('n*')
              if first_code != 0
                code_map = code_map.each_with_index.with_object({}) do |(g, i), hash|
                  hash[first_code + i] = g
                end
              end
              code_map
            end

          end


          # Cmap format 12
          module Format12

            # :call-seq:
            #   Format12.parse(io, length)    -> code_map
            #
            # Parses the format 12 cmap subtable from the given IO at the current position and
            # returns the contained code map.
            #
            # It is assumed that the first twelve bytes of the subtable have already been consumed.
            def self.parse(io, _length)
              mapper(io.read(4).unpack('N').first.times.map { io.read(12).unpack('N3') })
            end

            # The parameter +groups+ is an array containing [start_code, end_code, start_glyph_id]
            # arrays.
            def self.mapper(groups) #:nodoc:
              Hash.new do |h, code|
                group = groups.bsearch {|g| g[1] >= code}
                h[code] = (group && group[0] <= code ? group[2] + (code - group[0]) : 0)
              end
            end

          end


        end

      end
    end
  end
end
