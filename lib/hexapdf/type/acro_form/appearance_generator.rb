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

module HexaPDF
  module Type
    module AcroForm

      # The AppearanceGenerator class provides methods for generating and updating the appearance
      # streams of form fields.
      #
      # The only method needed is #create_appearance_streams since this method determines to what
      # field the widget belongs and therefore which appearance should be generated.
      #
      # The visual appearance of a field is constructed using information from the field itself as
      # well as information from the widget. See the documentation for the individual methods which
      # information is used in which way.
      #
      # By default, any existing appearance streams are overwritten and the +:print+ flag is set on
      # the widget so that the field appearance will appear on print-outs.
      #
      # The visual appearances are chosen to be similar to those used by Adobe Acrobat and others.
      # By subclassing and overriding the necessary methods it is possible to define custom
      # appearances.
      #
      # See: PDF1.7 s12.5.5, s12.7
      class AppearanceGenerator

        # Creates a new instance for the given +widget+.
        def initialize(widget)
          @widget = widget
          @field = widget.form_field
          @document = widget.document
        end

        # Creates the appropriate appearance streams for the widget.
        def create_appearance_streams
          case @field.field_type
          when :Btn
            if @field.check_box?
              create_check_box_appearance_streams
            elsif @field.radio_button?
              create_radio_button_appearance_streams
            else
              raise HexaPDF::Error, "Unsupported button field type"
            end
          else
            raise HexaPDF::Error, "Unsupported field type #{@field.field_type}"
          end
        end

        # Creates the appropriate appearance streams for check boxes.
        #
        # For unchecked boxes an empty rectangle is drawn. When checked, a symbol from the
        # ZapfDingbats font is placed inside the rectangle. How this is exactly done depends on the
        # following values:
        #
        # * The widget's rectangle /Rect must be defined. If the height and/or width of the
        #   rectangle are zero, they are based on the configuration option
        #   +acro_form.default_font_size+ and widget's border width. In such a case the rectangle is
        #   appropriately updated.
        #
        # * The line width, style and color of the rectangle are taken from the widget's border
        #   style. See HexaPDF::Type::Annotations::Widget#border_style.
        #
        # * The background color is determined by the widget's background color. See
        #   HexaPDF::Type::Annotations::Widget#background_color.
        #
        # * The symbol (marker) as well as its size and color are determined by the button marker
        #   style of the widget. See HexaPDF::Type::Annotations::Widget#button_marker_style for
        #   details.
        #
        # Examples:
        #
        #   widget.border_style(color: 0)
        #   widget.background_color(1)
        #   widget.button_marker_style(marker: :check, size: 0, color: 0)
        #   # => default appearance
        #
        #   widget.border_style(color: :transparent, width: 2)
        #   widget.background_color(0.7)
        #   widget.button_marker_style(marker: :cross)
        #   # => no visible rectangle, gray background, cross mark when checked
        def create_check_box_appearance_streams
          border_style = @widget.border_style
          border_width = border_style.width

          rect = update_widget(@field[:V], border_width)

          @widget[:AP] = {N: {}}
          off_form = @widget[:AP][:N][:Off] = @document.add({Type: :XObject, Subtype: :Form,
                                                             BBox: [0, 0, rect.width, rect.height]})
          apply_background_and_border(border_style, off_form.canvas)

          on_form = @widget[:AP][:N][:Yes] = @document.add({Type: :XObject, Subtype: :Form,
                                                            BBox: [0, 0, rect.width, rect.height]})
          canvas = on_form.canvas
          apply_background_and_border(border_style, canvas)
          canvas.save_graphics_state do
            draw_button_marker(canvas, rect, border_width, @widget.button_marker_style)
          end
        end

        # Creates the appropriate appearance streams for radio buttons.
        #
        # For unselected radio buttons an empty circle (if the button marker is :circle) or
        # rectangle is drawn inside the widget annotation's rectangle. When selected, a symbol from
        # the ZapfDingbats font is placed inside. How this is exactly done depends on the following
        # values:
        #
        # * The widget's rectangle /Rect must be defined. If the height and/or width of the
        #   rectangle are zero, they are based on the configuration option
        #   +acro_form.default_font_size+ and the widget's border width. In such a case the
        #   rectangle is appropriately updated.
        #
        # * The line width, style and color of the circle/rectangle are taken from the widget's
        #   border style. See HexaPDF::Type::Annotations::Widget#border_style.
        #
        # * The background color is determined by the widget's background color. See
        #   HexaPDF::Type::Annotations::Widget#background_color.
        #
        # * The symbol (marker) as well as its size and color are determined by the button marker
        #   style of the widget. See HexaPDF::Type::Annotations::Widget#button_marker_style for
        #   details.
        #
        # Examples:
        #
        #   widget.border_style(color: 0)
        #   widget.background_color(1)
        #   widget.button_marker_style(marker: :circle, size: 0, color: 0)
        #   # => default appearance
        def create_radio_button_appearance_streams
          unless @widget[:AP].key?(:N) && @widget[:AP][:N].value.size == 2
            raise HexaPDF::Error, "Widget of radio button doesn't define unique name for on state"
          end

          on_name = (@widget[:AP][:N].value.keys - [:Off]).first
          border_style = @widget.border_style
          button_marker_style = @widget.button_marker_style

          rect = update_widget(@field[:V] == on_name ? on_name : :Off, border_style.width)

          off_form = @widget[:AP][:N][:Off] = @document.add({Type: :XObject, Subtype: :Form,
                                                             BBox: [0, 0, rect.width, rect.height]})
          apply_background_and_border(border_style, off_form.canvas,
                                      circular: button_marker_style.marker == :circle)

          on_form = @widget[:AP][:N][on_name] = @document.add({Type: :XObject, Subtype: :Form,
                                                               BBox: [0, 0, rect.width, rect.height]})
          canvas = on_form.canvas
          apply_background_and_border(border_style, canvas,
                                      circular: button_marker_style.marker == :circle)
          canvas.save_graphics_state do
            draw_button_marker(canvas, rect, border_style.width, @widget.button_marker_style)
          end
        end

        private

        # Updates the widget and returns its (possibly modified) rectangle.
        #
        # The following changes are made:
        #
        # * Sets the appearance state to +appearance_state+.
        # * Sets the :print flag.
        # * Adjusts the rectangle based on the default font size and the given border width if its
        #   width and/or height are zero.
        def update_widget(appearance_state, border_width)
          @widget[:AS] = appearance_state
          @widget.flag(:print)

          default_font_size = @document.config['acro_form.default_font_size']
          rect = @widget[:Rect]
          rect.width = default_font_size + 2 * border_width if rect.width == 0
          rect.height = default_font_size + 2 * border_width if rect.height == 0
          rect
        end

        # Applies the background and border style of the widget annotation to the appearance stream.
        #
        # If +circular+ is +true+, then the border is drawn as inscribed circle instead of as
        # rectangle.
        def apply_background_and_border(border_style, canvas, circular: false)
          rect = @widget[:Rect]
          background_color = @widget.background_color

          if (border_style.width > 0 && border_style.color) || background_color
            canvas.save_graphics_state
            if background_color
              canvas.fill_color(background_color)
              if circular
                canvas.circle(rect.width / 2.0, rect.height / 2.0,
                              [rect.width / 2.0, rect.height / 2.0].min)
              else
                canvas.rectangle(0, 0, rect.width, rect.height)
              end
              canvas.fill
            end
            if border_style.color
              offset = [0.5, border_style.width / 2.0].max
              width, height = rect.width - 2 * offset, rect.height - 2 * offset
              canvas.stroke_color(border_style.color).line_width(border_style.width)
              if border_style.style == :underlined # TODO: :beveleded, :inset
                if circular
                  canvas.arc(rect.width / 2.0, rect.height / 2.0,
                             a: [width / 2.0, height / 2.0].min,
                             start_angle: 180, end_angle: 0)
                else
                  canvas.line(offset, offset, offset + width, offset)
                end
              else
                canvas.line_dash_pattern(border_style.style) if border_style.style.kind_of?(Array)
                if circular
                  canvas.circle(rect.width / 2.0, rect.height / 2.0, [width / 2.0, height / 2.0].min)
                else
                  canvas.rectangle(offset, offset, width, height)
                end
              end
              canvas.stroke
            end
            canvas.restore_graphics_state
          end
        end

        # Draws the marker defined by the button marker style inside the widget's rectangle.
        #
        # This method can only used for check boxes and radio buttons!
        def draw_button_marker(canvas, rect, border_width, button_marker_style)
          if @field.radio_button? && button_marker_style.marker == :circle
            # Acrobat handles this specially
            canvas.
              fill_color(button_marker_style.color).
              circle(rect.width / 2.0, rect.height / 2.0,
                     ([rect.width / 2.0, rect.height / 2.0].min - border_width) / 2).
              fill
          elsif button_marker_style.marker == :cross # Acrobat just places a cross inside
            canvas.
              stroke_color(button_marker_style.color).
              line(border_width, border_width, rect.width - border_width,
                   rect.height - border_width).
              line(border_width, rect.height - border_width, rect.width - border_width,
                   border_width).
              stroke
          else
            font = @document.fonts.add('ZapfDingbats')
            mark = font.decode_utf8(@widget[:MK]&.[](:CA) || '4').first
            square_width = [rect.width, rect.height].min - 2 * border_width
            font_size = (button_marker_style.size == 0 ? square_width : button_marker_style.size)
            mark_width = mark.width * font.scaling_factor * font_size / 1000.0
            mark_height = (mark.y_max - mark.y_min) * font.scaling_factor * font_size / 1000.0
            x_offset = (rect.width - square_width) / 2.0 + (square_width - mark_width) / 2.0
            y_offset = (rect.height - square_width) / 2.0 + (square_width - mark_height) / 2.0 -
              (mark.y_min * font.scaling_factor * font_size / 1000.0)

            canvas.font(font, size: font_size)
            canvas.fill_color(button_marker_style.color)
            canvas.move_text_cursor(offset: [x_offset, y_offset]).show_glyphs_only([mark])
          end
        end

      end

    end
  end
end
