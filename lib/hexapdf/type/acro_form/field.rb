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
require 'hexapdf/error'
require 'hexapdf/utils/bit_field'
require 'hexapdf/type/annotations'

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
      # While field objects can be created manually, it is best to use the various +create_+ methods
      # of the main Form object to create them so that all necessary things are set up correctly.
      #
      # == Field Types
      #
      # Subclasses are used to implement the specific AcroForm field types:
      #
      # * ButtonField implements the button fields (pushbuttons, check boxes and radio buttons)
      # * TextField implements single or multiline text fields.
      # * ChoiceField implements scrollable list boxes or (editable) combo boxes.
      # * SignatureField implements signature fields.
      #
      # == Field Flags
      #
      # Various characteristics of a field can be changed by setting a certain flag. Some flags are
      # defined for all types of field, some are specific to a certain type.
      #
      # The following flags apply to all fields:
      #
      # :read_only:: The field is read only which means the user can't change the value or interact
      #              with associated widget annotations.
      #
      # :required:: The field is required if the form is exported by a submit-form action.
      #
      # :no_export:: The field should *not* be exported by a submit-form action.
      #
      # == Field Type Implementation Notes
      #
      # If an AcroForm field type adds additional inheritable dictionary fields, it has to set the
      # constant +INHERITABLE_FIELDS+ to all inheritable dictionary fields, including those from the
      # superclass.
      #
      # Similarily, if additional flags are provided, the constant +FLAGS_BIT_MAPPING+ has to be set
      # to combination of the superclass value of the constant and the mapping of flag names to bit
      # indices.
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
        define_field :V,      type: [Dictionary, Symbol, String, Stream, PDFArray]
        define_field :DV,     type: [Dictionary, Symbol, String, Stream, PDFArray]
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
        bit_field(:flags, {read_only: 0, required: 1, no_export: 2},
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

        # Returns the name of the field or +nil+ if no name is set.
        def field_name
          self[:T]
        end

        # Returns the full name of the field or +nil+ if no name is set.
        #
        # The full name of a field is constructed using the full name of the parent field, a period
        # and the field name of the field.
        def full_field_name
          if key?(:Parent)
            [self[:Parent].full_field_name, field_name].compact.join('.')
          else
            field_name
          end
        end

        # Returns +true+ if this is a terminal field.
        def terminal_field?
          kids = self[:Kids]
          kids.nil? || kids.empty? || kids.all? {|kid| kid[:Subtype] == :Widget }
        end

        # :call-seq:
        #   field.each_widget {|widget| block}    -> field
        #   field.each_widget                     -> Enumerator
        #
        # Yields each widget, i.e. visual representation, of this field.
        #
        # See: HexaPDF::Type::Annotations::Widget
        def each_widget # :yields: widget
          return to_enum(__method__) unless block_given?
          if self[:Subtype]
            yield(document.wrap(self))
          elsif terminal_field?
            self[:Kids].each {|kid| yield(document.wrap(kid)) }
          end
          self
        end

        # Creates a new widget annotation for this form field (must be a terminal field!) on the
        # given +page+, adding the +values+ to the created widget annotation oject.
        #
        # The +values+ argument should at least include :Rect for setting the visible area of the
        # widget.
        #
        # If the field already has an embedded widget, i.e. field and widget are the same PDF
        # object, its widget data is extracted to a new PDF object and stored in the /Kids field,
        # together with the new widget annotation. Note that this means that a possible reference to
        # the formerly embedded widget (=this field) is not valid anymore!
        #
        # See: HexaPDF::Type::Annotations::Widget
        def create_widget(page, **values)
          unless terminal_field?
            raise HexaPDF::Error, "Widgets can only be added to terminal fields"
          end

          widget_data = {Type: :Annot, Subtype: :Widget, Rect: [0, 0, 0, 0], **values}

          if key?(:Subtype) || (key?(:Kids) && !self[:Kids].empty?)
            kids = self[:Kids] ||= []
            kids << extract_widget if key?(:Subtype)
            widget = document.add(widget_data)
            widget[:Parent] = self
            self[:Kids] << widget
          else
            value.update(widget_data)
            widget = document.wrap(self)
          end

          (page[:Annots] ||= []) << widget

          widget
        end

        private

        # An array of all widget annotation field names.
        WIDGET_FIELDS = HexaPDF::Type::Annotations::Widget.each_field.map(&:first).uniq - [:Parent]

        # Returns a new dictionary object with all the widget annotation data that is stored
        # directly in the field and adjust the references accordingly. If the field doesn't have any
        # widget data, +nil+ is returned.
        def extract_widget
          return unless key?(:Subtype)
          data = WIDGET_FIELDS.each_with_object({}) do |key, hash|
            hash[key] = delete(key) if key?(key)
          end
          widget = document.add(data, type: :Annot)
          document.pages.each do |page|
            if page.key?(:Annots) && (index = page[:Annots].index {|annot| annot.data == self.data })
              page[:Annots][index] = widget
              break # Each annotation dictionary may only appear on one page, see PDF1.7 12.5.2
            end
          end
          widget
        end

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
