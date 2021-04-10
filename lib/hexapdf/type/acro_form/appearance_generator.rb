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
require 'hexapdf/layout/style'
require 'hexapdf/layout/text_fragment'
require 'hexapdf/layout/text_layouter'

module HexaPDF
  module Type
    module AcroForm

      # The AppearanceGenerator class provides methods for generating and updating the appearance
      # streams of form fields.
      #
      # The only method needed is #create_appearances since this method determines to what field the
      # widget belongs and therefore which appearance should be generated.
      #
      # The visual appearance of a field is constructed using information from the field itself as
      # well as information from the widget. See the documentation for the individual methods which
      # information is used in which way.
      #
      # By default, any existing appearances are overwritten and the +:print+ flag is set on the
      # widget so that the field appearance will appear on print-outs.
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

        # Creates the appropriate appearances for the widget.
        def create_appearances
          case @field.field_type
          when :Btn
            if @field.check_box?
              create_check_box_appearances
            elsif @field.radio_button?
              create_radio_button_appearances
            else
              raise HexaPDF::Error, "Unsupported button field type"
            end
          when :Tx, :Ch
            create_text_appearances
          else
            raise HexaPDF::Error, "Unsupported field type #{@field.field_type}"
          end
        end

        # Creates the appropriate appearances for check boxes.
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
        # * The symbol (marker) as well as its size and color are determined by the marker style of
        #   the widget. See HexaPDF::Type::Annotations::Widget#marker_style for details.
        #
        # Examples:
        #
        #   widget.border_style(color: 0)
        #   widget.background_color(1)
        #   widget.marker_style(style: :check, size: 0, color: 0)
        #   # => default appearance
        #
        #   widget.border_style(color: :transparent, width: 2)
        #   widget.background_color(0.7)
        #   widget.marker_style(style: :cross)
        #   # => no visible rectangle, gray background, cross mark when checked
        def create_check_box_appearances
          unless @widget.appearance_dict&.normal_appearance&.value&.size == 2
            raise HexaPDF::Error, "Widget of check box doesn't define name for on state"
          end
          border_style = @widget.border_style
          border_width = border_style.width

          rect = update_widget(@field[:V], border_width)

          off_form = @widget.appearance_dict.normal_appearance[:Off] =
            @document.add({Type: :XObject, Subtype: :Form, BBox: [0, 0, rect.width, rect.height]})
          apply_background_and_border(border_style, off_form.canvas)

          on_form = @widget.appearance_dict.normal_appearance[@field.check_box_on_name] =
            @document.add({Type: :XObject, Subtype: :Form, BBox: [0, 0, rect.width, rect.height]})
          canvas = on_form.canvas
          apply_background_and_border(border_style, canvas)
          canvas.save_graphics_state do
            draw_marker(canvas, rect, border_width, @widget.marker_style)
          end
        end

        # Creates the appropriate appearances for radio buttons.
        #
        # For unselected radio buttons an empty circle (if the marker is :circle) or rectangle is
        # drawn inside the widget annotation's rectangle. When selected, a symbol from the
        # ZapfDingbats font is placed inside. How this is exactly done depends on the following
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
        # * The symbol (marker) as well as its size and color are determined by the marker style of
        #   the widget. See HexaPDF::Type::Annotations::Widget#marker_style for details.
        #
        # Examples:
        #
        #   widget.border_style(color: 0)
        #   widget.background_color(1)
        #   widget.marker_style(style: :circle, size: 0, color: 0)
        #   # => default appearance
        def create_radio_button_appearances
          unless @widget.appearance_dict&.normal_appearance&.value&.size == 2
            raise HexaPDF::Error, "Widget of radio button doesn't define unique name for on state"
          end

          on_name = (@widget.appearance_dict.normal_appearance.value.keys - [:Off]).first
          border_style = @widget.border_style
          marker_style = @widget.marker_style

          rect = update_widget(@field[:V] == on_name ? on_name : :Off, border_style.width)

          off_form = @widget.appearance_dict.normal_appearance[:Off] =
            @document.add({Type: :XObject, Subtype: :Form, BBox: [0, 0, rect.width, rect.height]})
          apply_background_and_border(border_style, off_form.canvas,
                                      circular: marker_style.style == :circle)

          on_form = @widget.appearance_dict.normal_appearance[on_name] =
            @document.add({Type: :XObject, Subtype: :Form, BBox: [0, 0, rect.width, rect.height]})
          canvas = on_form.canvas
          apply_background_and_border(border_style, canvas,
                                      circular: marker_style.style == :circle)
          canvas.save_graphics_state do
            draw_marker(canvas, rect, border_style.width, @widget.marker_style)
          end
        end

        # Creates the appropriate appearances for text fields.
        #
        # The following describes how the appearance is built:
        #
        # * The font, font size and font color are taken from the associated field's default
        #   appearance string. See VariableTextField.
        #
        #   If the font is not usable by HexaPDF (which may be due to a variety of reasons, e.g. no
        #   associated information in the form's default resources), the font specified by the
        #   configuration option +acro_form.fallback_font+ will be used.
        #
        # * The widget's rectangle /Rect must be defined. If the height is zero, it is auto-sized
        #   based on the font size. If additionally the font size is zero, a font size of
        #   +acro_form.default_font_size+ is used. If the width is zero, the
        #   +acro_form.text_field.default_width+ value is used. In such cases the rectangle is
        #   appropriately updated.
        #
        # * The line width, style and color of the rectangle are taken from the widget's border
        #   style. See HexaPDF::Type::Annotations::Widget#border_style.
        #
        # * The background color is determined by the widget's background color. See
        #   HexaPDF::Type::Annotations::Widget#background_color.
        #
        # Note: Multiline, comb and rich text fields are currently not supported!
        def create_text_appearances
          default_resources = @document.acro_form.default_resources
          font, font_size = retrieve_font_information(default_resources)
          style = HexaPDF::Layout::Style.new(font: font)
          border_style = @widget.border_style
          padding = [1, border_style.width].max

          @widget[:AS] = :N
          @widget.flag(:print)
          rect = @widget[:Rect]
          rect.width = @document.config['acro_form.text_field.default_width'] if rect.width == 0
          if rect.height == 0
            style.font_size = \
              (font_size == 0 ? @document.config['acro_form.default_font_size'] : font_size)
            rect.height = style.scaled_y_max - style.scaled_y_min + 2 * padding
          end

          form = (@widget[:AP] ||= {})[:N] ||= @document.add({Type: :XObject, Subtype: :Form})
          # Wrap existing object in Form class in case the PDF writer didn't include the /Subtype
          # key; we can do this since we know this has to be a Form object
          form = @document.wrap(form, type: :XObject, subtype: :Form) unless form[:Subtype] == :Form
          form.value.replace({Type: :XObject, Subtype: :Form, BBox: [0, 0, rect.width, rect.height]})
          form.contents = ''
          form[:Resources] = HexaPDF::Object.deep_copy(default_resources)

          canvas = form.canvas
          apply_background_and_border(border_style, canvas)
          style.font_size = calculate_font_size(font, font_size, rect, border_style)
          style.clear_cache

          canvas.marked_content_sequence(:Tx) do
            if @field.field_value || @field.concrete_field_type == :list_box
              canvas.save_graphics_state do
                canvas.rectangle(padding, padding, rect.width - 2 * padding,
                                 rect.height - 2 * padding).clip_path.end_path
                if @field.concrete_field_type == :multiline_text_field
                  draw_multiline_text(canvas, rect, style, padding)
                elsif @field.concrete_field_type == :list_box
                  draw_list_box(canvas, rect, style, padding)
                else
                  draw_single_line_text(canvas, rect, style, padding)
                end
              end
            end
          end
        end

        alias create_combo_box_appearances create_text_appearances
        alias create_list_box_appearances create_text_appearances

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

        # Applies the background and border style of the widget annotation to the appearances.
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
                  if @field.concrete_field_type == :comb_text_field
                    cell_width = rect.width.to_f / @field[:MaxLen]
                    1.upto(@field[:MaxLen] - 1) do |i|
                      canvas.line(i * cell_width, border_style.width,
                                  i * cell_width, border_style.width + height)
                    end
                  end
                end
              end
              canvas.stroke
            end
            canvas.restore_graphics_state
          end
        end

        # Draws the marker defined by the marker style inside the widget's rectangle.
        #
        # This method can only used for check boxes and radio buttons!
        def draw_marker(canvas, rect, border_width, marker_style)
          if @field.radio_button? && marker_style.style == :circle
            # Acrobat handles this specially
            canvas.
              fill_color(marker_style.color).
              circle(rect.width / 2.0, rect.height / 2.0,
                     ([rect.width / 2.0, rect.height / 2.0].min - border_width) / 2).
              fill
          elsif marker_style.style == :cross # Acrobat just places a cross inside
            canvas.
              stroke_color(marker_style.color).
              line(border_width, border_width, rect.width - border_width,
                   rect.height - border_width).
              line(border_width, rect.height - border_width, rect.width - border_width,
                   border_width).
              stroke
          else
            font = @document.fonts.add('ZapfDingbats')
            mark = font.decode_utf8(@widget[:MK]&.[](:CA) || '4').first
            square_width = [rect.width, rect.height].min - 2 * border_width
            font_size = (marker_style.size == 0 ? square_width : marker_style.size)
            mark_width = mark.width * font.scaling_factor * font_size / 1000.0
            mark_height = (mark.y_max - mark.y_min) * font.scaling_factor * font_size / 1000.0
            x_offset = (rect.width - square_width) / 2.0 + (square_width - mark_width) / 2.0
            y_offset = (rect.height - square_width) / 2.0 + (square_width - mark_height) / 2.0 -
              (mark.y_min * font.scaling_factor * font_size / 1000.0)

            canvas.font(font, size: font_size)
            canvas.fill_color(marker_style.color)
            canvas.move_text_cursor(offset: [x_offset, y_offset]).show_glyphs_only([mark])
          end
        end

        # Draws a single line of text inside the widget's rectangle.
        def draw_single_line_text(canvas, rect, style, padding)
          value = @field.field_value
          fragment = HexaPDF::Layout::TextFragment.create(value, style)

          if @field.concrete_field_type == :comb_text_field
            unless @field.key?(:MaxLen)
              raise HexaPDF::Error, "Missing or invalid dictionary field /MaxLen for comb text field"
            end
            new_items = []
            cell_width = rect.width.to_f / @field[:MaxLen]
            scaled_cell_width = cell_width / style.scaled_font_size.to_f
            fragment.items.each_cons(2) do |a, b|
              new_items << a << -(scaled_cell_width - a.width / 2.0 - b.width / 2.0)
            end
            new_items << fragment.items.last
            fragment.items.replace(new_items)
            fragment.clear_cache
            # Adobe always seems to add 1 to the first offset...
            x_offset = 1 + (cell_width - style.scaled_item_width(fragment.items[0])) / 2.0
            x = case @field.text_alignment
                when :left then x_offset
                when :right then x_offset + cell_width * (@field[:MaxLen] - value.length)
                when :center then x_offset + cell_width * ((@field[:MaxLen] - value.length) / 2)
                end
          else
            # Adobe seems to be left/right-aligning based on twice the border width
            x = case @field.text_alignment
                when :left then 2 * padding
                when :right then [rect.width - 2 * padding - fragment.width, 2 * padding].max
                when :center then [(rect.width - fragment.width) / 2.0, 2 * padding].max
                end
          end

          # Adobe seems to be vertically centering based on the cap height, if enough space is
          # available
          cap_height = style.font.wrapped_font.cap_height * style.font.scaling_factor / 1000.0 *
            style.font_size
          y = padding + (rect.height - 2 * padding - cap_height) / 2.0
          y = padding - style.scaled_font_descender if y < 0
          fragment.draw(canvas, x, y)
        end

        # Draws multiple lines  of text inside the widget's rectangle.
        def draw_multiline_text(canvas, rect, style, padding)
          items = [Layout::TextFragment.create(@field.field_value, style)]
          layouter = Layout::TextLayouter.new(style)
          layouter.style.align(@field.text_alignment).line_spacing(:proportional, 1.25)

          result = nil
          if style.font_size == 0 # need to auto-size text
            style.font_size = 12 # Adobe seems to use this as starting point
            style.clear_cache
            loop do
              result = layouter.fit(items, rect.width - 4 * padding, rect.height - 4 * padding)
              break if result.status == :success || style.font_size <= 4 # don't make text too small
              style.font_size -= 1
              style.clear_cache
            end
          else
            result = layouter.fit(items, rect.width - 4 * padding, 2**20)
          end

          unless result.lines.empty?
            result.draw(canvas, 2 * padding, rect.height - 2 * padding - result.lines[0].height / 2.0)
          end
        end

        # Draws the visible option items of the list box in the widget's rectangle.
        def draw_list_box(canvas, rect, style, padding)
          option_items = @field.option_items
          top_index = @field.list_box_top_index
          items = [Layout::TextFragment.create(option_items[top_index..-1].join("\n"), style)]

          indices = @field[:I] || []
          value_indices = [@field.field_value].flatten.compact.map {|val| option_items.index(val) }
          indices = value_indices if indices != value_indices

          layouter = Layout::TextLayouter.new(style)
          layouter.style.align(@field.text_alignment).line_spacing(:proportional, 1.25)
          result = layouter.fit(items, rect.width - 4 * padding, rect.height)

          unless result.lines.empty?
            top_gap = style.line_spacing.gap(result.lines[0], result.lines[0])
            line_height = style.line_spacing.baseline_distance(result.lines[0], result.lines[0])
            canvas.fill_color(153, 193, 218) # Adobe's color for selection highlighting
            indices.map! {|i| rect.height - padding - (i - top_index + 1) * line_height }.each do |y|
              next if y + line_height > rect.height || y + line_height < padding
              canvas.rectangle(padding, y, rect.width - 2 * padding, line_height)
            end
            canvas.fill if canvas.graphics_object == :path
            result.draw(canvas, 2 * padding, rect.height - padding - top_gap)
          end
        end

        # Returns the font wrapper and font size to be used for a variable text field.
        def retrieve_font_information(resources)
          font_name, font_size = @field.parse_default_appearance_string
          font_object = resources.font(font_name) rescue nil
          font = font_object&.font_wrapper
          unless font
            fallback_font = @document.config['acro_form.fallback_font']
            fallback_font_name, fallback_font_options = if fallback_font.respond_to?(:call)
                                                          fallback_font.call(@field, font_object)
                                                        else
                                                          fallback_font
                                                        end
            if fallback_font_name
              font = @document.fonts.add(fallback_font_name, **(fallback_font_options || {}))
            else
              raise(HexaPDF::Error, "Font #{font_name} of the AcroForm's default resources not usable")
            end
          end
          [font, font_size]
        end

        # Calculates the font size for text fields based on the font and font size of the default
        # appearance string, the annotation rectangle and the border style.
        def calculate_font_size(font, font_size, rect, border_style)
          if font_size == 0
            if @field.concrete_field_type == :multiline_text_field
              0 # Handled by multiline drawing code
            elsif @field.concrete_field_type == :list_box
              12 # Seems to be Adobe's default
            else
              unit_font_size = (font.wrapped_font.bounding_box[3] - font.wrapped_font.bounding_box[1]) *
                font.scaling_factor / 1000.0
              # The constant factor was found empirically by checking what Adobe Reader etc. do
              (rect.height - 2 * border_style.width) / unit_font_size * 0.83
            end
          else
            font_size
          end
        end

      end

    end
  end
end
