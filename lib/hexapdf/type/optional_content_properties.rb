# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2023 Thomas Leitner
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

require 'hexapdf/dictionary'

module HexaPDF
  module Type

    # Represents an optional content properties dictionary.
    #
    # This dictionary is the value of the /OCProperties key in the document catalog and needs to
    # exist for optional content to be usable by a PDF processor.
    #
    # In HexaPDF it provides the main entry point for working with optional content.
    #
    # See: PDF2.0 s8.11.4.2
    class OptionalContentProperties < Dictionary

      define_type :XXOCProperties

      define_field :OCGs,    type: PDFArray, required: true
      define_field :D,       type: :XXOCConfiguration, required: true
      define_field :Configs, type: PDFArray

      # :call-seq:
      #   optional_content.add_ocg(name)          -> ocg
      #   optional_content.add_ocg(ocg)           -> ocg
      #
      # Adds the given optional content group to the list of known OCGs and returns it. If a string
      # is provided, an optional content group with that name is created before adding it.
      #
      # See: #ocg, OptionalContentGroup
      def add_ocg(name_or_dict)
        ocg = if name_or_dict.kind_of?(Dictionary)
                name_or_dict
              else
                document.add({Type: :OCG, Name: name_or_dict})
              end
        (self[:OCGs] ||= []) << ocg
        ocg
      end

      # :call-seq:
      #   optional_content.ocg(name, create: true)          -> ocg or +nil+
      #
      # Returns the first found optional content group with the given +name+.
      #
      # If no optional content group with the given +name+ exists but the optional argument +create+
      # is +true+, a new OCG with the given +name+ is created and returned. Otherwise +nil+ is
      # returned.
      #
      # See: #add_ocg
      def ocg(name, create: true)
        self[:OCGs].find {|ocg| ocg.name == name } || (create && add_ocg(name) || nil)
      end

      # Returns the list of known optional content group objects, with duplicates removed.
      def ocgs
        self[:OCGs].uniq.compact
      end

    end

  end
end
