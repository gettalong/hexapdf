# -*- encoding: utf-8 -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2016 Thomas Leitner
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

module HexaPDF
  module Font

    # Represents a CMap, a mapping from character codes to CIDs (character IDs) or to their Unicode
    # value.
    #
    # Currently, only the mapping to the Unicode values is supported.
    #
    # See: PDF1.7 s9.7.5, s9.10.3; Adobe Technical Note #5411
    class CMap

      autoload(:Parser, 'hexapdf/font/cmap/parser')
      autoload(:Writer, 'hexapdf/font/cmap/writer')

      # Creates a new CMap object from the given string which needs to contain a valid CMap file.
      def self.parse(string)
        Parser.new.parse(string)
      end

      # Returns a string containing a ToUnicode CMap that represents the given code to Unicode
      # codepoint mapping.
      #
      # See: Writer#create_to_unicode_cmap
      def self.create_to_unicode_cmap(mapping)
        Writer.new.create_to_unicode_cmap(mapping)
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
        @unicode_mapping = Hash.new("".freeze)
      end

      # Returns the Unicode string in UTF-8 encoding for the given character code, or an empty
      # string if no mapping was found.
      def to_unicode(code)
        unicode_mapping[code]
      end

    end

  end
end
