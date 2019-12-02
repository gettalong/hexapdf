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

      end

    end
  end
end
