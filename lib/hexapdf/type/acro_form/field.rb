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
require 'hexapdf/utils/bit_field'

module HexaPDF
  module Type
    module AcroForm

      # AcroForm field dictionaries are used to define the properties of form fields of AcroForm
      # objects.
      #
      # Fields can be organized in a hierarchy using the /Kids and /Parent keys, for namespacing
      # purposes and to set default values. Those fields that have other fields as children are
      # called non-terminal fields, otherwise they are called terminal fields.
      #
      # == Specific Field Type Implementations
      #
      # Subclasses are used to implement specific AcroForm field types.
      #
      # If a AcroForm field type adds additional inheritable dictionary fields, it has to set the
      # constant +INHERITABLE_FIELDS+ to all inheritable dictionary fields, including those from the
      # superclass.
      #
      # See: PDF1.7 s12.7.3.1
      class Field < Dictionary

        extend Utils::BitField

        define_type :XXAcroFormField

        define_field :FT,     type: Symbol, allowed_values: [:Btn, :Tx, :Ch, :Sig]
        define_field :Parent, type: :XXAcroFormField
        define_field :Kids,   type: PDFArray
        define_field :T,      type: String
        define_field :TU,     type: String, version: '1.3'
        define_field :TM,     type: String, version: '1.3'
        define_field :Ff,     type: Integer, default: 0
        define_field :V,      type: [Symbol, String, Stream, PDFArray, Dictionary]
        define_field :DV,     type: [Symbol, String, Stream, PDFArray, Dictionary]
        define_field :AA,     type: Dictionary, version: '1.2'

        # The inheritable dictionary fields common to all AcroForm field types.
        INHERITABLE_FIELDS = [:FT, :Ff, :V, :DV].freeze

        ##
        # :method: flags
        #
        # Returns an array of flag names representing the set bit flags.
        #

        ##
        # :method: flagged?
        # :call-seq:
        #   flagged?(flag)
        #
        # Returns +true+ if the given flag is set. The argument can either be the flag name or the
        # bit index.
        #

        ##
        # :method: flag
        # :call-seq:
        #   flag(*flags, clear_existing: false)
        #
        # Sets the given flags, given as flag names or bit indices. If +clear_existing+ is +true+,
        # all prior flags will be cleared.
        #
        bit_field(:flags, {ReadOnly: 0, Required: 1, NoExport: 2},
                  lister: "flags", getter: "flagged?", setter: "flag",
                  value_getter: "self[:Ff]", value_setter: "self[:Ff]")

        # Form fields must always be indirect objects.
        def must_be_indirect?
          true
        end

        # Returns the value for the entry +name+.
        #
        # If +name+ is an inheritable value and the value has not been set on this field object, its
        # value is retrieved from the parent fields.
        #
        # See: Dictionary#[]
        def [](name)
          if value[name].nil? && self.class::INHERITABLE_FIELDS.include?(name)
            field = self
            while field.value[name].nil? && (parent = field[:Parent])
              field = parent
            end
            field == self || field.value[name].nil? ? super : field[name]
          else
            super
          end
        end

        # Returns the type of the field, either :Btn (pushbuttons, check boxes, radio buttons), :Tx
        # (text fields), :Ch (scrollable list boxes, combo boxes) or :Sig (signature fields).
        def field_type
          self[:FT]
        end

        # Returns the full name of the field or +nil+ if no name is set.
        #
        # The full name of a field is constructed using the full name of the parent field, a period
        # and the partial name of the field.
        def full_name
          if key?(:Parent)
            [self[:Parent].full_name, self[:T]].compact.join('.')
          else
            self[:T]
          end
        end

        # Returns +true+ if this is a terminal field.
        def terminal_field?
          kids = self[:Kids]
          kids.nil? || kids.empty? || kids.any? {|kid| kid[:Subtype] == :Widget }
        end

        private

        def perform_validation #:nodoc:
          super
          if terminal_field? && field_type.nil?
            yield("/FT is required for terminal fields")
          end
          if key?(:T) && self[:T].include?('.')
            yield("/T shall not contain a period")
          end
        end

      end

    end
  end
end
