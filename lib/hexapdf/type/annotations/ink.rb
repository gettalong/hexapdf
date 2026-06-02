# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2026 Thomas Leitner
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

      # An ink annotation is a markup annotation that displays a freehand "scribble" composed of one
      # or more disjoint paths.
      #
      # The convenience method #add_path can be used to add paths to the annotation.
      #
      # The style of the scribble can be customized using the convenience methods Annotation#opacity
      # and BorderStyling#border_style (note that only a simple line dash pattern is supported).
      #
      # Example:
      #
      #   #>pdf-small
      #   doc.annotations.create_scribble(doc.pages[0]).
      #     add_path(10, 10, 50, 40, 40, 80, 80, 60).
      #     add_path(5, 90, 20, 90, 15, 50, 80, 5).
      #     border_style(color: "hp-blue", width: 2, style: [3, 1]).
      #     regenerate_appearance
      #
      # See: PDF2.0 s12.5.6.13, HexaPDF::Type::MarkupAnnotation
      class Ink < MarkupAnnotation

        include BorderStyling

        define_field :Subtype, type: Symbol, required: true, default: :Ink
        define_field :InkList, type: PDFArray, required: true
        define_field :BS,      type: :Border
        define_field :Path,    type: PDFArray, version: '2.0'

        # :call-seq:
        #   annot.paths   => [[x00, y00, x01, y01, ...], [x10, y10, x11, y11, ...], ...]
        #
        # Returns an array with all the paths of this annotation.
        def paths
          self[:InkList].to_a
        end

        # :call-seq:
        #   annot.add_path            => [x0, y0, x1, y1, ...]
        #   annot.add_path(*points)   => annot
        #
        # Adds the path consisting of the given +points+ to the list of paths and returns self.
        #
        # Adding at least one path is required. Note, however, that without setting the appearance
        # style through convenience methods like #border_style nothing will be shown.
        #
        # Example:
        #
        #   #>pdf-small
        #   doc.annotations.create_scribble(doc.pages[0]).
        #     add_path(10, 10, 40, 60, 90, 90).
        #     regenerate_appearance
        def add_path(*points)
          if points.length % 2 != 0
            raise ArgumentError, "An even number of arguments must be provided"
          else
            self[:InkList] ||= []
            self[:InkList] << points
            self
          end
        end

      end

    end
  end
end
