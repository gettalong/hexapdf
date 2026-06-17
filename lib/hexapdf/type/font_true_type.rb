# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2026 Thomas Leitner
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

require 'hexapdf/type/font_simple'
require 'hexapdf/font/true_type_wrapper'

module HexaPDF
  module Type

    # Represents a TrueType font.
    #
    # See: PDF2.0 s9.6.3
    class FontTrueType < FontSimple

      define_field :Subtype, type: Symbol, required: true, default: :TrueType
      define_field :BaseFont, type: Symbol, required: true

      # Overrides the default to provide a font wrapper in case none is set and a complete TrueType
      # is embedded.
      #
      # See: Font#font_wrapper
      def font_wrapper
        if (tmp = super)
          tmp
        elsif (font_file = self.font_file) && self[:BaseFont].to_s !~ /\A[A-Z]{6}\+/
          font = HexaPDF::Font::TrueType::Font.new(StringIO.new(font_file.stream))
          @font_wrapper = HexaPDF::Font::TrueTypeWrapper.new(document, font, subset: true)
        end
      end

      private

      # Returns an encoding backed by the cmap table of the embedded TrueType font.
      #
      # If the font has a Unicode cmap (platform 0 or Microsoft/BMP), a +BuiltInUnicodeEncoding+
      # that maps character codes directly to Unicode via that cmap is returned. If the font only
      # has a Mac Roman cmap (platform 1, encoding 0), +MacRomanEncoding+ is returned since Mac
      # Roman character codes map to that encoding.
      #
      # Raises HexaPDF::Error if the font is not embedded or has no usable cmap table.
      #
      # See: PDF2.0 s9.6.6.4
      def encoding_from_font
        ff = font_file
        raise HexaPDF::Error, "No encoding and TrueType font '#{self[:BaseFont]}' is not embedded" unless ff
        cmap = HexaPDF::Font::TrueType::Font.new(StringIO.new(ff.stream))[:cmap]
        raise HexaPDF::Error, "No cmap table in embedded TrueType font '#{self[:BaseFont]}'" unless cmap
        if (table = cmap.preferred_table)
          BuiltInUnicodeEncoding.new(table)
        elsif cmap.tables.any? {|t| t.platform_id == 1 && t.encoding_id == 0 }
          HexaPDF::Font::Encoding.for_name(:MacRomanEncoding)
        else
          raise HexaPDF::Error, "No usable cmap in embedded TrueType font '#{self[:BaseFont]}'"
        end
      end

      # An encoding backed directly by a Unicode cmap subtable of an embedded TrueType font.
      #
      # Used when the font dictionary has no +Encoding+ entry and the embedded font provides a
      # Unicode cmap (platform 0 or Microsoft BMP). Character codes in the content stream are
      # looked up in the cmap as Unicode code points; the resolved glyph ID is then reverse-mapped
      # back to a code point and returned as a UTF-8 character.
      class BuiltInUnicodeEncoding < HexaPDF::Font::Encoding::Base

        def initialize(cmap_table) #:nodoc:
          super()
          @cmap = cmap_table
        end

        # Returns the Unicode character for +code+, or +nil+ if no mapping exists.
        def unicode(code)
          gid = @cmap[code]
          return nil if !gid || gid.zero?
          cp = @cmap.gid_to_code(gid)
          cp ? +'' << cp : nil
        end

      end
      private_constant :BuiltInUnicodeEncoding

      def perform_validation
        std_font = FontType1::StandardFonts.standard_font?(self[:BaseFont])
        super(ignore_missing_font_fields: std_font)

        if self[:FontDescriptor].nil? && !std_font
          yield("Required field FontDescriptor is not set", false)
        end
      end

    end

  end
end
