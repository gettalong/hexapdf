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
require 'hexapdf/error'
require 'hexapdf/content/parser'

module HexaPDF
  module Type
    module AcroForm

      # An AcroForm variable text field defines how text that it is not known at generation time
      # should be rendered. For example, AcroForm text fields (normally) don't have an initial
      # value; the value is entered by the user and needs to be rendered correctly by the PDF
      # reader.
      #
      # See: PDF1.7 s12.7.3.3
      class VariableTextField < Field

        define_field :DA, type: String
        define_field :Q, type: Integer, default: 0, allowed_values: [0, 1, 2]
        define_field :DS, type: String, version: '1.5'
        define_field :RV, type: [String, Stream], version: '1.5'

        # All inheritable dictionary fields for text fields.
        INHERITABLE_FIELDS = (superclass::INHERITABLE_FIELDS + [:DA, :Q]).freeze

        UNSET_ARG = ::Object.new # :nodoc:

        # :call-seq:
        #   field.text_alignment                -> alignment
        #   field.text_alignment(alignment)     -> field
        #
        # Sets or returns the text alignment that should be used when displaying text.
        #
        # With no argument, the current text alignment is returned. When a value is provided, the
        # text alignment is set accordingly.
        #
        # The alignment value is one of :left, :center or :right.
        def text_alignment(alignment = UNSET_ARG)
          if alignment == UNSET_ARG
            case self[:Q]
            when 0 then :left
            when 1 then :center
            when 2 then :right
            end
          else
            self[:Q] = case alignment
                       when :left then 0
                       when :center then 1
                       when :right then 2
                       else
                         raise ArgumentError, "Invalid variable text field alignment #{alignment}"
                       end
          end
        end

        # Sets the default appearance string using the provided values.
        #
        # The default argument values are a sane default. If +font_size+ is set to 0, the font size
        # is calculated using the height/width of the field.
        def set_default_appearance_string(font: 'Helvetica', font_size: 0)
          name = document.acro_form(create: true).default_resources.
            add_font(document.fonts.add(font).pdf_object)
          self[:DA] = "0 g /#{name} #{font_size} Tf"
        end

        # Parses the default appearance string and returns an array containing [font_name,
        # font_size].
        #
        # The default appearance string is taken from the field or, if not set, the default
        # appearance string of the form.
        def parse_default_appearance_string
          da = self[:DA] || (document.acro_form && document.acro_form[:DA])
          raise HexaPDF::Error, "No default appearance string set" unless da

          font_params = nil
          HexaPDF::Content::Parser.parse(da) do |obj, params|
            font_params = params.dup if obj == :Tf
          end
          font_params
        end

      end

    end
  end
end
