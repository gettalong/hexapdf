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

require 'hexapdf/type/annotation'
require 'hexapdf/content'
require 'hexapdf/serializer'

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

        # Returs the AcroForm field object to which this widget annotation belongs.
        #
        # Since a widget and a field can share the same dictionary object, the returned object is
        # often just the widget re-wrapped in the correct field class.
        def form_field
          field = if key?(:Parent) &&
                      (tmp = document.wrap(self[:Parent], type: :XXAcroFormField)).terminal_field?
                    tmp
                  else
                    document.wrap(self, type: :XXAcroFormField)
                  end
          document.wrap(field, type: :XXAcroFormField, subtype: field[:FT])
        end

        # :call-seq:
        #   widget.background_color                => background_color or nil
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
            if components && !components.empty?
              Content::ColorSpace.prenormalized_device_color(components)
            end
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
        #           If the special value +:transparent+ is used when setting the color, a
        #           transparent is used. A transparent border will return a +nil+ value when getting
        #           the border color.
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
            color = if color == :transparent
                      []
                    else
                      Content::ColorSpace.device_color_from_specification(color || 0).components
                    end
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

        # Describes the marker style of a check box or radio button widget.
        class MarkerStyle

          # The kind of marker that is shown inside the widget. Can either be one of the symbols
          # +:check+, +:circle+, +:cross+, +:diamond+, +:square+ or +:star+, or a one character
          # string. The latter is interpreted using the ZapfDingbats font.
          attr_reader :style

          # The size of the marker in PDF points that is shown inside the widget. The special value
          # 0 means that the marker should be auto-sized based on the widget's rectangle.
          attr_reader :size

          # A device color object representing the color of the marker - see
          # HexaPDF::Content::ColorSpace.
          attr_reader :color

          # Creates a new instance with the given values.
          def initialize(style, size, color)
            @style = style
            @size = size
            @color = color
          end

        end

        # :call-seq:
        #   widget.marker_style                                     => marker_style
        #   widget.marker_style(style: nil, size: nil, color: nil)   => widget
        #
        # Returns a MarkerStyle instance representing the marker style of the widget when no
        # argument is given. Otherwise sets the button marker style of the widget and returns self.
        #
        # This method returns valid information only for check boxes and radio buttons!
        #
        # When setting a marker style, arguments that are not provided will use the default: a black
        # auto-sized checkmark (i.e. :check for for check boxes) or circle (:circle for radio
        # buttons). This also means that multiple invocations will reset *all* prior values.
        #
        # Note: The marker is called "normal caption" in the PDF 1.7 spec and the /CA entry of the
        # associated appearance characteristics dictionary. The marker size and color are set using
        # the /DA key on the widget (although /DA is not defined for widget, this is how Acrobat
        # does it).
        #
        # See: PDF1.7 s12.5.6.19 and s17.7.3.3
        def marker_style(style: nil, size: nil, color: nil)
          field = form_field
          if style || size || color
            style ||= (field.check_box? ? :check : :cicrle)
            size ||= 0
            color = Content::ColorSpace.device_color_from_specification(color || 0)

            self[:MK] ||= {}
            self[:MK][:CA] = case style
                             when :check   then '4'
                             when :circle  then 'l'
                             when :cross   then '8'
                             when :diamond then 'u'
                             when :square  then 'n'
                             when :star    then 'H'
                             when String   then style
                             else
                               raise ArgumentError, "Unknown value #{style} for argument 'style'"
                             end
            operator = case color.color_space.family
                       when :DeviceRGB then :rg
                       when :DeviceGray then :g
                       when :DeviceCMYK then :k
                       end
            serialized_color = Content::Operator::DEFAULT_OPERATORS[operator].
              serialize(HexaPDF::Serializer.new, *color.components)
            self[:DA] = "/ZaDb #{size} Tf #{serialized_color}".strip
          else
            style = case self[:MK]&.[](:CA)
                    when '4' then :check
                    when 'l' then :circle
                    when '8' then :cross
                    when 'u' then :diamond
                    when 'n' then :square
                    when 'H' then :star
                    when String then self[:MK][:CA]
                    else
                      if field.check_box?
                        :check
                      else
                        :circle
                      end
                    end
            size = 0
            color = [0]
            if (da = self[:DA] || field[:DA])
              HexaPDF::Content::Parser.parse(da) do |obj, params|
                case obj
                when :rg, :g, :k then color = params.dup
                when :Tf then size = params[1]
                end
              end
            end
            color = HexaPDF::Content::ColorSpace.prenormalized_device_color(color)

            MarkerStyle.new(style, size, color)
          end
        end

      end

    end
  end
end
