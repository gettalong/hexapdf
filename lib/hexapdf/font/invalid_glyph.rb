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

module HexaPDF
  module Font

    # Represents an invalid glyph, i.e. a Unicode character that has no representation in the used
    # font.
    class InvalidGlyph

      # The string that could not be represented as a glyph.
      attr_reader :str

      # Creates a new Glyph object.
      def initialize(font, str)
        @font = font
        @str = str
      end

      # Returns the appropriate missing glyph id based on the used font.
      def id
        @font.missing_glyph_id
      end
      alias name id

      # Returns 0.
      def x_min
        0
      end
      alias x_max x_min
      alias y_min x_min
      alias y_max x_min
      alias width x_min

      # Word spacing is never applied for the invalid glyph, so +false+ is returned.
      def apply_word_spacing?
        false
      end

      #:nodoc:
      def inspect
        "#<#{self.class.name} font=#{@font.full_name.inspect} id=#{id} #{@str.inspect}>"
      end

    end

  end
end
