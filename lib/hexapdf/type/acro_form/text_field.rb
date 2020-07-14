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

require 'hexapdf/error'
require 'hexapdf/type/acro_form/variable_text_field'
require 'hexapdf/layout'

module HexaPDF
  module Type
    module AcroForm

      # AcroForm text fields provide a box or space to fill-in data entered from keyboard. The text
      # may be restricted to a single line or can span multiple lines.
      #
      # == Type Specific Field Flags
      #
      # :multiline:: If set, the text field may contain multiple lines.
      #
      # :password:: The field is a password field. This changes the behaviour of the PDF reader
      #             application to not echo the input text and to not store it in the PDF file.
      #
      # :file_select:: The text field represents a file selection control where the input text is
      #                the path to a file.
      #
      # :do_not_spell_check:: The text should not be spell-checked.
      #
      # :do_not_scroll:: The text field should not scroll (horizontally for single-line fields and
      #                  vertically for multiline fields) to accomodate more text than fits into the
      #                  annotation rectangle. This means that no more text can be entered once the
      #                  field is full.
      #
      # :comb:: The field is divided into /MaxLen equally spaced positions (so /MaxLen needs to be
      #         set). This is useful, for example, when entering things like social security
      #         numbers which always have the same length.
      #
      # :rich_text:: The field is a rich text field.
      #
      # See: PDF1.7 s12.7.4.3
      class TextField < VariableTextField

        define_field :MaxLen, type: Integer

        # All inheritable dictionary fields for text fields.
        INHERITABLE_FIELDS = (superclass::INHERITABLE_FIELDS + [:MaxLen]).freeze

        # Updated list of field flags.
        FLAGS_BIT_MAPPING = superclass::FLAGS_BIT_MAPPING.merge(
          {
            multiline: 13,
            password: 14,
            file_select: 21,
            do_not_spell_check: 23,
            do_not_scroll: 24,
            comb: 25,
            rich_text: 26,
          }
        ).freeze

        # Returns the field value, i.e. the text contents of the field, or +nil+ if no value is set.
        #
        # Note that modifying the returned value *might not* modify the text contents in case it is
        # stored as stream! So always use #field_value= to set the field value.
        def field_value
          return unless value[:V]
          self[:V].kind_of?(String) ? self[:V] : self[:V].stream
        end

        # Sets the field value, i.e. the text contents of the field, to the given string.
        def field_value=(str)
          if flagged?(:password)
            raise HexaPDF::Error, "Storing a field value for a password field is not allowed"
          end
          self[:V] = str
        end

        # Returns the default field value.
        #
        # See: #field_value
        def default_field_value
          self[:DV].kind_of?(String) ? self[:DV] : self[:DV].stream
        end

        # Sets the default field value.
        #
        # See: #field_value=
        def default_field_value=(str)
          self[:DV] = str
        end

        # Creates appropriate appearance streams for all widgets.
        #
        # Before this method is invoked, the appearance properties like font, font size, border
        # style, ... have to be set because those are used to determine the appearance.
        #
        # Invoking this method will also adjust the following dictionary fields of the associated
        # widgets if necessary:
        #
        # /AP and /AS:: Set to the created appearance stream and :N, respectively. This means an
        #               already existing stream will be discarded.
        #
        # /Rect:: If the height is zero, it is auto-sized based on the font size. If additionally
        #         the font size is zero, a font size of +acro_form.default_font_size+ is
        #         used. If the width is zero, the +acro_form.text_field.default_width+ value is
        #         used.
        #
        # Flags:: The +:print+ flag is set so that the text will appear on print-outs.
        #
        # Note: Multiline, comb and rich text fields are currently not supported!
        def create_appearance_streams!
          font_name, font_size = parse_default_appearance_string
          default_font_size = document.config['acro_form.default_font_size']
          default_width = document.config['acro_form.text_field.default_width']
          default_resources = document.acro_form.default_resources
          font = default_resources.font(font_name).font_wrapper ||
            raise(HexaPDF::Error, "Font #{font_name} of the AcroForm's default resources not usable")
          style = HexaPDF::Layout::Style.new(font: font)

          each_widget do |widget|
            border_style = widget.border_style
            padding = [1, border_style.width].max

            widget[:AS] = :N
            widget.flag(:print)
            rect = widget[:Rect]
            rect.width = default_width if rect.width == 0
            if rect.height == 0
              style.font_size = (font_size == 0 ? default_font_size : font_size)
              rect.height = style.scaled_y_max - style.scaled_y_min + 2 * padding
            end

            form = (widget[:AP] ||= {})[:N] = document.add({Type: :XObject, Subtype: :Form})
            form[:BBox] = [0, 0, rect.width, rect.height]
            form[:Resources] = HexaPDF::Object.deep_copy(default_resources)

            canvas = form.canvas
            apply_background_and_border(widget, border_style, canvas)
            style.font_size = calculate_font_size(font, font_size, rect, border_style)

            canvas.marked_content_sequence(:Tx) do
              if (value = field_value)
                canvas.save_graphics_state do
                  canvas.rectangle(padding, padding, rect.width - 2 * padding,
                                   rect.height - 2 * padding).clip_path.end_path
                  fragment = HexaPDF::Layout::TextFragment.create(value, style)
                  # Adobe seems to be left/right-aligning based on twice the border width and
                  # vertically centering based on the cap height, if enough space is available
                  x = case text_alignment
                      when :left then 2 * padding
                      when :right then [rect.width - 2 * padding - fragment.width, 2 * padding].max
                      when :center then [(rect.width - fragment.width) / 2.0, 2 * padding].max
                      end
                  cap_height = font.wrapped_font.cap_height * font.scaling_factor / 1000.0 *
                    style.font_size
                  y = padding + (rect.height - 2 * padding - cap_height) / 2.0
                  y = padding - style.scaled_font_descender if y < 0
                  fragment.draw(canvas, x, y)
                end
              end
            end
          end
        end

        private

        def perform_validation #:nodoc:
          if field_type != :Tx
            yield("Field /FT of AcroForm text field has to be :Tx", true)
            self[:FT] = :Tx
          end

          super

          if self[:V] && !(self[:V].kind_of?(String) || self[:V].kind_of?(HexaPDF::Stream))
            yield("Text field doesn't contain text but #{self[:V].class} object")
          end
          if (max_len = self[:MaxLen]) && field_value.length > max_len
            yield("Text contents of field '#{full_field_name}' is too long")
          end
        end

        # Applies the background and border style of the widget annotation to the appearance stream.
        def apply_background_and_border(widget, border_style, canvas)
          rect = widget[:Rect]
          background_color = widget.background_color

          if (border_style.width > 0 && border_style.color) || background_color
            canvas.save_graphics_state
            if background_color
              canvas.fill_color(background_color).rectangle(0, 0, rect.width, rect.height).fill
            end
            if border_style.color
              offset = [0.5, border_style.width / 2.0].max
              width, height = rect.width - 2 * offset, rect.height - 2 * offset
              canvas.stroke_color(border_style.color).line_width(border_style.width)
              if border_style.style == :underlined # TODO: :beveleded, :inset
                canvas.line(offset, offset, offset + width, offset).stroke
              else
                canvas.line_dash_pattern(border_style.style) if border_style.style.kind_of?(Array)
                canvas.rectangle(offset, offset, width, height).stroke
              end
            end
            canvas.restore_graphics_state
          end
        end

        # Calculates the font size based on the font and font size of the default appearance string,
        # the annotation rectangle and the border style.
        def calculate_font_size(font, font_size, rect, border_style)
          if font_size == 0
            unit_font_size = (font.wrapped_font.bounding_box[3] - font.wrapped_font.bounding_box[1]) *
              font.scaling_factor / 1000.0
            # The constant factor was found empirically by checking what Adobe Reader etc. do
            (rect.height - 2 * border_style.width) / unit_font_size * 0.83
          else
            font_size
          end
        end

      end

    end
  end
end
