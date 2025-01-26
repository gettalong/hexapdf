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

require 'hexapdf/error'

module HexaPDF
  module Type
    module Annotations

      # The AppearanceGenerator class provides methods for generating the appearance streams of
      # annotations except those for widgets (see HexaPDF::Type::AcroForm::AppearanceGenerator for
      # those).
      #
      # There is one private create_TYPE_appearance method for each annotation type. This allows
      # subclassing the appearance generator and adjusting the appearances to one's needs.
      #
      # By default, an existing appearance is overwritten and the +:print+ flag is set as well as
      # the +:hidden+ flag unset on the annotation so that the appearance will appear on print-outs.
      #
      # Also note that the annotation's /Rect entry is modified so that it contains the whole
      # generated appearance.
      #
      # The visual appearances are chosen to be similar to those used by Adobe Acrobat and others.
      # By subclassing and overriding the necessary methods it is possible to define custom
      # appearances.
      #
      # The default annotation appearance generator for a document can be changed using the
      # 'annotation.appearance_generator' configuration option.
      #
      # See: PDF2.0 s12.5
      class AppearanceGenerator

        # Creates a new instance for the given +annotation+.
        def initialize(annotation)
          @annot = annotation
          @document = annotation.document
        end

        # Creates the appropriate appearance for the annotation provided on initialization.
        def create_appearance
          case @annot[:Subtype]
          when :Line then create_line_appearance
          else
            raise HexaPDF::Error, "Appearance regeneration for #{@annot[:Subtype]} not yet supported"
          end
        end

        private

        # Creates the appropriate appearance for a line annotation.
        #
        # See: HexaPDF::Type::Annotations::Line
        def create_line_appearance
          form = (@annot[:AP] ||= {})[:N] ||=
            @document.add({Type: :XObject, Subtype: :Form, BBox: [0, 0, 0, 0]})
          @annot.flag(:print)
          @annot.unflag(:hidden)

          x0, y0, x1, y1 = @annot.line
          style = @annot.border_style
          opacity = @annot.opacity
          ll = @annot.leader_line_length
          lle = @annot.leader_line_extension_length
          llo = @annot.leader_line_offset

          angle = Math.atan2(y1 - y0, x1 - x0)
          cos_angle = Math.cos(angle)
          sin_angle = Math.sin(angle)
          line_length = Math.sqrt((y1 - y0) ** 2 + (x1 - x0) ** 2)
          ll_sign = (ll > 0 ? 1 : -1)
          ll_y = ll_sign * (ll.abs + lle + llo)

          # Calculate annotation rectangle and form bounding box This considers the line end points
          # as well as the end points of the leader lines when calculating the bounding box.
          min_x, max_x = [x0, x0 - sin_angle * ll_y, x1, x1 - sin_angle * ll_y].minmax
          min_y, max_y = [y0, y0 + cos_angle * ll_y, y1, y1 + cos_angle * ll_y].minmax

          padding = 4 * style.width
          rect = [min_x - padding, min_y - padding, max_x + padding, max_y + padding]
          @annot[:Rect] = rect
          form[:BBox] = rect.dup

          #TODO: handle line endings
          #TODO: handle captions

          return unless style.color

          # Set the appropriate graphics state and transform the canvas so that the line is
          # unrotated and its start point at the origin.
          canvas = form.canvas(translate: false)
          canvas.opacity(**opacity.to_h)
          canvas.stroke_color(style.color)
          canvas.fill_color(@annot.interior_color) if @annot.interior_color
          canvas.line_width(style.width)
          canvas.transform(cos_angle, sin_angle, -sin_angle, cos_angle, x0, y0)

          # Draw leader lines and line
          line_y = 0
          if ll != 0
            canvas.line(0, ll_sign * llo, 0, ll_y)
            canvas.line(line_length, ll_sign * llo, line_length, ll_y)
            line_y = ll_sign * (llo + ll.abs)
          end
          canvas.line(0, line_y, line_length, line_y)
          canvas.stroke
        end

      end

    end
  end
end
