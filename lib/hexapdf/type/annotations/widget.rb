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

require 'hexapdf/type/annotation'

module HexaPDF
  module Type
    module Annotations

      # Widget annotations are used by interactive forms to represent the appearance of fields and
      # to manage user interactions.
      #
      # See: PDF1.7 s12.5.6.19, HexaPDF::Type::Annotation
      class Widget < Annotation

        # The dictionary used by the /MK key of the widget annotation.
        class AppearanceCharacteristics < Dictionary

          define_type :XXAppearanceCharacteristics

          define_field :R,  type: Integer, default: 0
          define_field :BC, type: PDFArray
          define_field :BG, type: PDFArray
          define_field :CA, type: String
          define_field :RC, type: String
          define_field :AC, type: String
          define_field :I,  type: Stream
          define_field :RI, type: Stream
          define_field :IX, type: Stream
          define_field :IF, type: :XXIconFit
          define_field :TP, type: Integer, default: 0, allowed_values: [0, 1, 2, 3, 4, 5, 6]

          private

          def perform_validation #:nodoc:
            super

            if key?(:R) && self[:R] % 90 != 0
              yield("Value of field R needs to be a multiple of 90")
            end
          end

        end

        define_field :Subtype, type: Symbol, required: true, default: :Widget
        define_field :H,       type: Symbol, allowed_values: [:N, :I, :O, :P, :T]
        define_field :MK,      type: :XXAppearanceCharacteristics
        define_field :A,       type: Dictionary, version: '1.1'
        define_field :AA,      type: Dictionary, version: '1.2'
        define_field :BS,      type: :Border, version: '1.2'
        define_field :Parent,  type: Dictionary

      end

    end
  end
end
