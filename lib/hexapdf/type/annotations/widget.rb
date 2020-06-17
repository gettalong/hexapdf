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
require 'hexapdf/content/color_space'

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

        # :call-seq:
        #   widget.background_color                => background_color
        #   widget.background_color(*color)        => widget
        #
        # Returns the current background color as device color object, or +nil+ if no background
        # color is set, when no argument is given. Otherwise sets the background color using the
        # +color+ argument and returns self.
        #
        # See HexaPDF::Content::ColorSpace.device_color_from_specification for information on the
        # allowed arguments.
        def background_color(*color)
          if color.empty?
            components = self[:MK]&.[](:BG)
            components.nil? ? nil : Content::ColorSpace.prenormalized_device_color(components)
          else
            color = Content::ColorSpace.device_color_from_specification(color)
            (self[:MK] ||= {})[:BG] = color.components
            self
          end
        end

        # Describes the border of an annotation.
        #
        # The +color+ property is either +nil+ if the border is transparent or else a device color
        # object - see HexaPDF::Content::ColorSpace.
        #
        # The +style+ property can be one of the following:
        #
        # :solid::      Solid line.
        # :beveled::    Embossed rectangle seemingly raised above the surface of the page.
        # :inset::      Engraved rectangle receeding into the page.
        # :underlined:: Underlined, i.e. only the bottom border is draw.
        # Array:        Dash array describing how to dash the line.
        BorderStyle = Struct.new(:width, :color, :style, :horizontal_corner_radius,
                                 :vertical_corner_radius)

        # :call-seq:
        #   widget.border_style                                      => border_style
        #   widget.border_style(color: 0, width: 1, style: :solid)   => widget
        #
        # Returns a BorderStyle instance representing the border style of the widget when no
        # argument is given. Otherwise sets the border style of the widget and returns self.
        #
        # When setting a border style, arguments that are not provided will use the default: a
        # border with a solid, black, 1pt wide line. This also means that multiple invocations will
        # reset *all* prior values.
        #
        # +color+:: The color of the border. See
        #           HexaPDF::Content::ColorSpace.device_color_from_specification for information on
        #           the allowed arguments.
        #
        # +width+:: The width of the border. If set to 0, no border is shown.
        #
        # +style+:: Defines how the border is drawn. can be one of the following:
        #
        #           +:solid+::      Draws a solid border.
        #           +:beveled+::    Draws a beveled border.
        #           +:inset+::      Draws an inset border.
        #           +:underlined+:: Draws only the bottom border.
        #           Array::         An array specifying a line dash pattern (see
        #                           HexaPDF::Content::LineDashPattern)
        def border_style(color: nil, width: nil, style: nil)
          if color || width || style
            color = Content::ColorSpace.device_color_from_specification(color || 0).components
            width ||= 1
            style ||= :solid

            (self[:MK] ||= {})[:BC] = color
            bs = self[:BS] = {W: width}
            case style
            when :solid then bs[:S] = :S
            when :beveled then bs[:S] = :B
            when :inset then bs[:S] = :I
            when :underlined then bs[:S] = :U
            when Array
              bs[:S] = :D
              bs[:D] = style
            else
              raise ArgumentError, "Unknown value #{style} for style argument"
            end
            self
          else
            result = BorderStyle.new(1, nil, :solid, 0, 0)
            if (ac = self[:MK]) && (bc = ac[:BC]) && !bc.empty?
              result.color = Content::ColorSpace.prenormalized_device_color(bc.value)
            end
            return result unless result.color

            if (bs = self[:BS])
              result.width = bs[:W] if bs.key?(:W)
              result.style = case bs[:S]
                             when :S then :solid
                             when :B then :beveled
                             when :I then :inset
                             when :U then :underlined
                             when :D then bs[:D].value
                             else :solid
                             end
            elsif key?(:Border)
              border = self[:Border]
              result.horizontal_corner_radius = border[0]
              result.vertical_corner_radius = border[1]
              result.width = border[2]
              result.style = border[3] if border[3]
            end

            result
          end
        end

      end

    end
  end
end
