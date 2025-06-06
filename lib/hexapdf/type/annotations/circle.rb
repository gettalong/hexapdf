# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2025 Thomas Leitner
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

require 'hexapdf/type/annotations'

module HexaPDF
  module Type
    module Annotations

      # A circle annotation displays an ellipse inside the annotation rectangle (the "circle" name
      # defined by the PDF specification is a bit misleading).
      #
      # Also see SquareCircle for more information.
      #
      # Example:
      #
      #   #>pdf-small
      #   doc.annotations.create_ellipse(doc.pages[0], 50, 50, a: 30, b: 20).
      #     border_style(color: "hp-blue", width: 2, style: [3, 1]).
      #     interior_color("hp-orange").
      #     regenerate_appearance
      #
      # See: PDF2.0 s12.5.6.8, HexaPDF::Type::Annotations::SquareCircle,
      class Circle < SquareCircle

        define_field :Subtype, type: Symbol, required: true, default: :Circle

      end

    end
  end
end
