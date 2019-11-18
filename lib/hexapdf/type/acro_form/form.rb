# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2019 Thomas Leitner
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
require 'hexapdf/stream'
require 'hexapdf/utils/bit_field'

module HexaPDF
  module Type
    module AcroForm

      # Represents the PDF's interactive form dictionary. It is linked from the catalog dictionary
      # via the /AcroForm entry.
      #
      # See: PDF1.7 s12.7.2
      class Form < Dictionary

        extend Utils::BitField

        define_type :XXAcroForm

        define_field :Fields,          type: PDFArray, required: true, version: '1.2'
        define_field :NeedAppearances, type: Boolean, default: false
        define_field :SigFlags,        type: Integer, version: '1.3'
        define_field :CO,              type: PDFArray, version: '1.3'
        define_field :DR,              type: :Ressources
        define_field :DA,              type: String
        define_field :XFA,             type: [Stream, PDFArray], version: '1.5'

        bit_field(:raw_signature_flags, {signatures_exist: 0, append_only: 1},
                  lister: "signature_flags", getter: "signature_flag?", setter: "signature_flag")

        # Returns an array with all root fields that were found in the PDF document.
        def find_root_fields
          result = []
          document.pages.each do |page|
            page[:Annots].each do |annot|
              if !annot.key?(:Parent) && annot.key?(:FT)
                result << document.wrap(annot, type: :XXAcroFormField)
              elsif annot.key?(:Parent)
                field = annot[:Parent]
                field = field[:Parent] while field[:Parent]
                result << document.wrap(field, type: :XXAcroFormField)
              end
            end
          end
          result
        end

        # Finds all root fields and sets /Fields appropriately.
        #
        # See: #find_root_fields
        def find_root_fields!
          self[:Fields] = find_root_fields
        end

        # :call-seq:
        #   acroform.each_field(terminal_only: true) {|field| block}    -> acroform
        #   acroform.each_field(terminal_only: true)                    -> Enumerator
        #
        # Yields all terminal fields or all fields, depending on the +terminal_only+ argument.
        def each_field(terminal_only: true)
          return to_enum(__method__, terminal_only: terminal_only) unless block_given?

          process_field = lambda do |field|
            field = document.wrap(field, type: :XXAcroFormField)
            yield(field) if field.terminal_field? || !terminal_only
            field[:Kids].each(&process_field) unless field.terminal_field?
          end

          self[:Fields]&.each(&process_field)
          self
        end

        private

        # Helper method for bit field getter access.
        def raw_signature_flags
          self[:SigFlags]
        end

        # Helper method for bit field setter access.
        def raw_signature_flags=(value)
          self[:SigFlags] = value
        end

      end

    end
  end
end
