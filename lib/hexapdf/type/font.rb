# -*- encoding: utf-8 -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2017 Thomas Leitner
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
#++

require 'hexapdf/stream'
require 'hexapdf/font/cmap'

module HexaPDF
  module Type

    # Represents a generic font object.
    #
    # This class is the base class for all font objects, be it simple fonts or composite fonts.
    class Font < Dictionary

      define_field :Type, type: Symbol, required: true, default: :Font
      define_field :BaseFont, type: Symbol, required: true
      define_field :ToUnicode, type: Stream, version: '1.2'

      # Font objects must always be indirect.
      def must_be_indirect?
        true
      end

      # Returns the UTF-8 string for the given character code, or calls the configuration option
      # 'font.on_missing_unicode_mapping' if no mapping was found.
      def to_utf8(code)
        to_unicode_cmap && to_unicode_cmap.to_unicode(code) || missing_unicode_mapping(code)
      end

      # Returns the bounding box of the font or +nil+ if it is not found.
      def bounding_box
        if key?(:FontDescriptor) && self[:FontDescriptor].key?(:FontBBox)
          self[:FontDescriptor][:FontBBox].value
        else
          nil
        end
      end

      # Returns +true+ if the font is embedded.
      def embedded?
        dict = self[:FontDescriptor]
        dict && (dict[:FontFile] || dict[:FontFile2] || dict[:FontFile3])
      end

      private

      # Parses and caches the ToUnicode CMap.
      def to_unicode_cmap
        unless defined?(@to_unicode_cmap)
          @to_unicode_cmap = if key?(:ToUnicode)
                               HexaPDF::Font::CMap.parse(self[:ToUnicode].stream)
                             else
                               nil
                             end
        end
        @to_unicode_cmap
      end

      # Calls the configured proc for handling missing unicode mappings.
      def missing_unicode_mapping(code)
        @document.config['font.on_missing_unicode_mapping'].call(code, self)
      end

    end

  end
end
