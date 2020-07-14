# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2020 Thomas Leitner
#
# HexaPDF is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License version 3 as
# published by the Free Software Foundation with the addition of the
# following permission added to Section 15 as permitted in Section 7(a):
# FOR ANY PART OF THE COVERED WORK IN WHICH THE COPYRIGHT IS OWNED BY
# THOMAS LEITNER, THOMAS LEITNER DISCLAIMS THE WARRANTY OF NON
# INFRINGEMENT OF THIRD PARTY RIGHTS.
#
# HexaPDF is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public
# License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with HexaPDF. If not, see <http://www.gnu.org/licenses/>.
#
# The interactive user interfaces in modified source and object code
# versions of HexaPDF must display Appropriate Legal Notices, as required
# under Section 5 of the GNU Affero General Public License version 3.
#
# In accordance with Section 7(b) of the GNU Affero General Public
# License, a covered work must retain the producer line in every PDF that
# is created or manipulated using HexaPDF.
#
# If the GNU Affero General Public License doesn't fit your need,
# commercial licenses are available at <https://gettalong.at/hexapdf/>.
#++

require 'hexapdf/font/cmap'

module HexaPDF
  module Font
    class CMap

      # Creates a CMap file.
      #
      # Currently only ToUnicode CMaps are supported.
      class Writer

        # Maximum number of entries in one section.
        MAX_ENTRIES_IN_SECTION = 100

        # Returns a ToUnicode CMap for the given input code to Unicode codepoint mapping which needs
        # to be sorted by input codes.
        #
        # Note that the returned CMap always uses a 16-bit input code space!
        def create_to_unicode_cmap(mapping)
          return to_unicode_template % '' if mapping.empty?

          chars, ranges = compute_section_entries(mapping)

          result = create_sections("bfchar", chars.size / 2) do |index|
            index *= 2
            sprintf("<%04X>", chars[index]) << "<" <<
              ((+'').force_encoding(::Encoding::UTF_16BE) << chars[index + 1]).unpack1('H*') <<
              ">\n"
          end

          result << create_sections("bfrange", ranges.size / 3) do |index|
            index *= 3
            sprintf("<%04X><%04X>", ranges[index], ranges[index + 1]) << "<" <<
              ((+'').force_encoding(::Encoding::UTF_16BE) << ranges[index + 2]).unpack1('H*') <<
              ">\n"
          end

          to_unicode_template % result.chop!
        end

        private

        # Computes the entries for the "char" and "range" sections based on the given mapping.
        #
        # Returns two arrays +char_mappings+ and +range_mappings+ where +char_mappings+ is an array
        # of the form
        #
        #   [code1, value1, code2, value2, ...]
        #
        # and +range_mappings+ an array of the form
        #
        #   [start1, end1, value1, start2, end2, value2, ...]
        def compute_section_entries(mapping)
          chars = []
          ranges = []

          last_code, last_value = *mapping[0]
          is_range = false
          mapping.slice(1..-1).each do |code, value|
            if last_code + 1 == code && last_value + 1 == value && code % 256 != 0
              ranges << last_code << nil << last_value unless is_range
              is_range = true
            elsif is_range
              ranges[-2] = last_code
              is_range = false
            else
              chars << last_code << last_value
            end
            last_code = code
            last_value = value
          end

          # Handle last remaining mapping
          if is_range
            ranges[-2] = last_code
          else
            chars << last_code << last_value
          end

          [chars, ranges]
        end

        # Creates one or more sections of a CMap file and returns the resulting string.
        #
        # +type+::
        #     The name of the section, e.g. "bfchar" or "bfrange".
        #
        # +size+::
        #     The maximum number of elements of this type. Used for determining when to start a new
        #     section.
        #
        # The method makes sure that no section has more than the maximum number of allowed entries.
        #
        # Numbers from 0 up to size - 1 are yielded, indicating the current entry that should be
        # processed and for which an appropriate section line should be returned from the block.
        def create_sections(type, size)
          return +'' if size == 0

          result = +""
          index = 0
          while size > 0
            count = [MAX_ENTRIES_IN_SECTION, size].min
            result << "#{count} begin#{type}\n"
            index.upto(index + count - 1) {|i| result << yield(i) }
            result << "end#{type}\n"
            index += count
            size -= count
          end

          result
        end

        # Returns the CMap file template for a ToUnicode CMap.
        def to_unicode_template
          <<~TEMPLATE
            /CIDInit /ProcSet findresource begin
            12 dict begin
            begincmap
            /CIDSystemInfo
            << /Registry (Adobe)
            /Ordering (UCS)
            /Supplement 0
            >> def
            /CMapName /Adobe-Identity-UCS def
            /CMapType 2 def
            1 begincodespacerange
            <0000> <FFFF>
            endcodespacerange
            %s
            endcmap
            CMapName currentdict /CMap defineresource pop
            end
            end
          TEMPLATE
        end

      end

    end
  end
end
