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

require 'hexapdf/dictionary'
require 'hexapdf/stream'
require 'hexapdf/type/acro_form/field'
require 'hexapdf/utils/bit_field'

module HexaPDF
  module Type
    module AcroForm

      # Represents the PDF's interactive form dictionary. It is linked from the catalog dictionary
      # via the /AcroForm entry.
      #
      # == Overview
      #
      # An interactive form consists of fields which can be structured hierarchically and shown on
      # pages by using Annotations::Widget annotations. This means one field can have zero, one or
      # more visual representations on one or more pages. The fields at the bottom of the hierarchy
      # which have no parent are called "root fields" and are stored in /Fields.
      #
      # Each field in a form has a certain type which determines how it should be displayed and what
      # a user can do with it. The most common type is "text field" which allows the user to enter
      # one or more lines of text. There are also check boxes, radio buttons, list boxes and combo
      # boxes.
      #
      # == Visual Appearance
      #
      # The visual appearance of a field is normally provided by the application creating the PDF.
      # This is done by generating the so called appearance streams for all widgets of a field.
      # However, it is also possible to instruct the PDF reader application to generate the
      # appearances on the fly using the /NeedAppearances key, see #need_appearances!.
      #
      # HexaPDF honors the /NeedAppearances key: If it is not set or set to +false+, HexaPDF will
      # generate appearance streams for all fields that don't have any.
      #
      # See: PDF1.7 s12.7.2, Field, HexaPDF::Type::Annotations::Widget
      class Form < Dictionary

        extend Utils::BitField

        define_type :XXAcroForm

        define_field :Fields,          type: PDFArray, required: true, version: '1.2'
        define_field :NeedAppearances, type: Boolean, default: false
        define_field :SigFlags,        type: Integer, version: '1.3'
        define_field :CO,              type: PDFArray, version: '1.3'
        define_field :DR,              type: :XXResources
        define_field :DA,              type: String
        define_field :XFA,             type: [Stream, PDFArray], version: '1.5'

        bit_field(:raw_signature_flags, {signatures_exist: 0, append_only: 1},
                  lister: "signature_flags", getter: "signature_flag?", setter: "signature_flag",
                  unsetter: "signature_unflag")

        # Returns the PDFArray containing the root fields.
        def root_fields
          self[:Fields] ||= document.wrap([])
        end

        # Returns an array with all root fields that were found in the PDF document.
        def find_root_fields
          result = []
          document.pages.each do |page|
            page[:Annots]&.each do |annot|
              if !annot.key?(:Parent) && annot.key?(:FT)
                result << document.wrap(annot, type: :XXAcroFormField, subtype: annot[:FT])
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
            field = document.wrap(field, type: :XXAcroFormField,
                                  subtype: Field.inherited_value(field, :FT))
            yield(field) if field.terminal_field? || !terminal_only
            field[:Kids].each(&process_field) unless field.terminal_field?
          end

          root_fields.each(&process_field)
          self
        end

        # Returns the field with the given +name+ or +nil+ if no such field exists.
        def field_by_name(name)
          fields = root_fields
          field = nil
          name.split('.').each do |part|
            field = fields&.find {|f| f[:T] == part }
            break unless field
            field = document.wrap(field, type: :XXAcroFormField,
                                  subtype: Field.inherited_value(field, :FT))
            fields = field[:Kids] unless field.terminal_field?
          end
          field
        end

        # Creates a new text field with the given name and adds it to the form.
        #
        # The +name+ may contain dots to signify a field hierarchy. If so, the referenced parent
        # fields must already exist. If it doesn't contain dots, a top-level field is created.
        def create_text_field(name)
          create_field(name, :Tx)
        end

        # Creates a new check box with the given name and adds it to the form.
        #
        # The +name+ may contain dots to signify a field hierarchy. If so, the referenced parent
        # fields must already exist. If it doesn't contain dots, a top-level field is created.
        def create_check_box(name)
          create_field(name, :Btn).tap(&:initialize_as_check_box)
        end

        # Creates a radio button with the given name and adds it to the form.
        #
        # The +name+ may contain dots to signify a field hierarchy. If so, the referenced parent
        # fields must already exist. If it doesn't contain dots, a top-level field is created.
        def create_radio_button(name)
          create_field(name, :Btn).tap(&:initialize_as_radio_button)
        end

        # Returns the dictionary containing the default resources for form field appearance streams.
        def default_resources
          self[:DR] ||= document.wrap({}, type: :XXResources)
        end

        # Sets the global default appearance string using the provided values.
        #
        # The default argument values are a sane default. If +font_size+ is set to 0, the font size
        # is calculated using the height/width of the field.
        def set_default_appearance_string(font: 'Helvetica', font_size: 0)
          name = default_resources.add_font(document.fonts.add(font).pdf_object)
          self[:DA] = "0 g /#{name} #{font_size} Tf"
        end

        # Sets the /NeedAppearances field to +true+.
        #
        # This will make PDF reader applications generate appropriate appearance streams based on
        # the information stored in the fields and associated widgets.
        def need_appearances!
          self[:NeedAppearances] = true
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

        # Creates a new field with the full name +name+ and the field type +type+.
        def create_field(name, type)
          parent_name, _, name = name.rpartition('.')
          parent_field = parent_name.empty? ? nil : field_by_name(parent_name)
          if !parent_name.empty? && !parent_field
            raise HexaPDF::Error, "Parent field '#{parent_name}' not found"
          end

          field = document.add({FT: type, T: name, Parent: parent_field},
                               type: :XXAcroFormField, subtype: type)
          if parent_field
            (parent_field[:Kids] ||= []) << field
          else
            (self[:Fields] ||= []) << field
          end
          field
        end

        def perform_validation # :nodoc:
          if (da = self[:DA])
            unless self[:DR]
              yield("When the field /DA is present, the field /DR must also be present")
            end
            font_name = nil
            HexaPDF::Content::Parser.parse(da) do |obj, params|
              font_name = params[0] if obj == :Tf
            end
            if font_name && !(self[:DR][:Font] && self[:DR][:Font][font_name])
              yield("The font specified in /DA is not in the /DR resource dictionary")
            end
          else
            set_default_appearance_string
          end
        end

      end

    end
  end
end
