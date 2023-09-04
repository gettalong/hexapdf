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

    # Represents an optional content configuration dictionary.
    #
    # This dictionary is used for the /D and /Configs entries in the optional content properties
    # dictionary. It configures the states of the OCGs as well as defines how those states may be
    # changed by a PDF processor.
    #
    # See: PDF2.0 s8.11.4.3
    class OptionalContentConfiguration < Dictionary

      # Represents an optional content usage application dictionary.
      #
      # This dictionary is used for the elements in the /AS array of an optional content
      # configuration dictionary. It specifies how a PDF processor should use the usage entries of
      # OCGs to automatically change their state based on external factors (like magnifacation
      # factor or language).
      #
      # See: PDF2.0 s8.11.4.4
      class UsageApplication < Dictionary
        define_type :XXOCUsageApplication
        define_field :Event, type: Symbol, required: true, allowed_values: [:View, :Print, :Export]
        define_field :OCGs, type: PDFArray, default: []
        define_field :Category, type: PDFArray, required: true
      end

      define_type :XXOCConfiguration

      define_field :Name,      type: String
      define_field :Creator,   type: String
      define_field :BaseState, type: Symbol, default: :ON, allowed_values: [:ON, :OFF, :Unchanged]
      define_field :ON,        type: PDFArray
      define_field :OFF,       type: PDFArray
      define_field :Intent,    type: [Symbol, PDFArray], default: :View
      define_field :AS,        type: PDFArray
      define_field :Order,     type: PDFArray
      define_field :ListMode,  type: Symbol, default: :AllPages,
        allowed_values: [:AllPages, :VisiblePages]
      define_field :RBGroups,  type: PDFArray
      define_field :Locked,    type: PDFArray, default: []

    end

  end
end
