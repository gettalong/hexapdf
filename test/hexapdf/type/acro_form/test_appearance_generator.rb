# -*- encoding: utf-8 -*-

require 'test_helper'
require_relative '../../content/common'
require 'hexapdf/document'
require 'hexapdf/type/acro_form/appearance_generator'

describe HexaPDF::Type::AcroForm::AppearanceGenerator do
  before do
    @doc = HexaPDF::Document.new
    @page = @doc.pages.add
    @form = @doc.acro_form(create: true)
  end

  describe "create_appearance_streams" do
    before do
      @field = @doc.add({FT: :Btn}, type: :XXAcroFormField, subtype: :Btn)
      @widget = @doc.wrap({Parent: @field, Type: :Annot, Subtype: :Widget})
      @generator = HexaPDF::Type::AcroForm::AppearanceGenerator.new(@widget)
    end

    it "fails for unsupported button fields" do
      @field.flag(:push_button)
      @generator = HexaPDF::Type::AcroForm::AppearanceGenerator.new(@widget)
      assert_raises(HexaPDF::Error) { @generator.create_appearance_streams }
    end

    it "fails for unsupported field types" do
      @field[:FT] = :Unknown
      assert_raises(HexaPDF::Error) { @generator.create_appearance_streams }
    end
  end

  describe "background color and border" do
    before do
      @field = @doc.add({FT: :Btn}, type: :XXAcroFormField, subtype: :Btn)
      @widget = @field.create_widget(@page, defaults: false, Rect: [0, 0, 10, 20])
      @xform = @doc.add({Type: :XObject, Subtype: :Form, BBox: @widget[:Rect]})
      @generator = HexaPDF::Type::AcroForm::AppearanceGenerator.new(@widget)
    end

    def execute(circular = false)
      @generator.send(:apply_background_and_border, @widget.border_style, @xform.canvas,
                      circular: circular)
    end

    it "applies no background color or border if none is set" do
      execute
      assert_operators(@xform.stream, [])
    end

    it "applies a background color if one set" do
      @widget.background_color(0.5)
      execute
      execute(true)
      assert_operators(@xform.stream,
                       [[:save_graphics_state],
                        [:set_device_gray_non_stroking_color, [0.5]],
                        [:append_rectangle, [0, 0, 10, 20]],
                        [:fill_path_non_zero], [:restore_graphics_state],

                        [:save_graphics_state],
                        [:set_device_gray_non_stroking_color, [0.5]],
                        [:move_to, [10.0, 10.0]],
                        [:curve_to, [10.0, 11.78411, 9.045085, 13.438072, 7.5, 14.330127]],
                        [:curve_to, [5.954915, 15.222182, 4.045085, 15.222182, 2.5, 14.330127]],
                        [:curve_to, [0.954915, 13.438072, 0.0, 11.78411, 0.0, 10.0]],
                        [:curve_to, [-0.0, 8.21589, 0.954915, 6.561928, 2.5, 5.669873]],
                        [:curve_to, [4.045085, 4.777818, 5.954915, 4.777818, 7.5, 5.669873]],
                        [:curve_to, [9.045085, 6.561928, 10.0, 8.21589, 10.0, 10.0]],
                        [:close_subpath], [:fill_path_non_zero], [:restore_graphics_state]])
    end

    it "sets the border color and width correctly" do
      @widget.border_style(color: 0.5, width: 4)
      execute
      execute(true)
      assert_operators(@xform.stream,
                       [[:save_graphics_state],
                        [:set_device_gray_stroking_color, [0.5]],
                        [:set_line_width, [4]],
                        [:append_rectangle, [2, 2, 6, 16]],
                        [:stroke_path], [:restore_graphics_state],

                        [:save_graphics_state],
                        [:set_device_gray_stroking_color, [0.5]],
                        [:set_line_width, [4]],
                        [:move_to, [8.0, 10.0]],
                        [:curve_to, [8.0, 11.070466, 7.427051, 12.062843, 6.5, 12.598076]],
                        [:curve_to, [5.572949, 13.133309, 4.427051, 13.133309, 3.5, 12.598076]],
                        [:curve_to, [2.572949, 12.062843, 2.0, 11.070466, 2.0, 10.0]],
                        [:curve_to, [2.0, 8.929534, 2.572949, 7.937157, 3.5, 7.401924]],
                        [:curve_to, [4.427051, 6.866691, 5.572949, 6.866691, 6.5, 7.401924]],
                        [:curve_to, [7.427051, 7.937157, 8.0, 8.929534, 8.0, 10.0]],
                        [:close_subpath], [:stroke_path], [:restore_graphics_state]])
    end

    it "handles the case of an underlined border" do
      @widget.border_style(style: :underlined, width: 2)
      execute
      execute(true)
      assert_operators(@xform.stream,
                       [[:save_graphics_state],
                        [:set_line_width, [2]],
                        [:move_to, [1, 1]], [:line_to, [9.0, 1]],
                        [:stroke_path], [:restore_graphics_state],

                        [:save_graphics_state],
                        [:set_line_width, [2]],
                        [:move_to, [1.0, 10.0]],
                        [:curve_to, [1.0, 8.572712, 1.763932, 7.249543, 3.0, 6.535898]],
                        [:curve_to, [4.236068, 5.822254, 5.763932, 5.822254, 7.0, 6.535898]],
                        [:curve_to, [8.236068, 7.249543, 9.0, 8.572712, 9.0, 10.0]],
                        [:stroke_path], [:restore_graphics_state]])
    end
  end

  describe "draw_button_marker" do
    before do
      @field = @doc.add({FT: :Btn}, type: :XXAcroFormField, subtype: :Btn)
      @widget = @field.create_widget(@page, defaults: false, Rect: [0, 0, 10, 20])
      @xform = @doc.add({Type: :XObject, Subtype: :Form, BBox: @widget[:Rect]})
      @generator = HexaPDF::Type::AcroForm::AppearanceGenerator.new(@widget)
    end

    def execute
      @generator.send(:draw_button_marker, @xform.canvas, @widget[:Rect], @widget.border_style.width,
                      @widget.button_marker_style)
    end

    it "handles the marker :cross specially" do
      @widget.button_marker_style(marker: :cross, color: 0.5)
      execute
      assert_operators(@xform.stream,
                       [[:set_device_gray_stroking_color, [0.5]],
                        [:move_to, [1, 1]], [:line_to, [9, 19]],
                        [:move_to, [1, 19]], [:line_to, [9, 1]],
                        [:stroke_path]])
    end

    describe "handles the normal markers by drawing them using the ZapfDingbats font" do
      it "works with font auto-sizing" do
        @widget.button_marker_style(marker: :check, color: 0.5, size: 0)
        execute
        assert_operators(@xform.stream,
                         [[:set_font_and_size, [:F1, 8]],
                          [:set_device_gray_non_stroking_color, [0.5]],
                          [:begin_text],
                          [:set_text_matrix, [1, 0, 0, 1, 1.616, 7.236]],
                          [:show_text, ["!"]],
                          [:end_text]])
      end

      it "works with a fixed font size" do
        @widget.button_marker_style(marker: :check, color: 0.5, size: 5)
        execute
        assert_operators(@xform.stream,
                         [[:set_font_and_size, [:F1, 5]],
                          [:set_device_gray_non_stroking_color, [0.5]],
                          [:begin_text],
                          [:set_text_matrix, [1, 0, 0, 1, 2.885, 8.2725]],
                          [:show_text, ["!"]],
                          [:end_text]])
      end
    end
  end

  describe "button fields" do
    before do
      @field = @doc.add({FT: :Btn}, type: :XXAcroFormField, subtype: :Btn)
      @widget = @field.create_widget(@page, Rect: [0, 0, 0, 0])
      @generator = HexaPDF::Type::AcroForm::AppearanceGenerator.new(@widget)
    end

    describe "check box" do
      before do
        @field.field_value = :Off
      end

      it "updates the widgets' /AS entry to point to the selected appearance stream" do
        @generator.create_appearance_streams
        assert_equal(@field[:V], @widget[:AS])
      end

      it "set the print flag on the widgets" do
        @generator.create_appearance_streams
        assert(@widget.flagged?(:print))
      end

      it "adjusts the /Rect if width is zero" do
        @generator.create_appearance_streams
        assert_equal(12, @widget[:Rect].width)
      end

      it "adjusts the /Rect if height is zero" do
        @generator.create_appearance_streams
        assert_equal(12, @widget[:Rect].height)
      end

      it "creates the needed objects for the appearance streams" do
        @generator.create_appearance_streams
        assert_equal(:XObject, @widget[:AP][:N][:Off].type)
        assert_equal(:XObject, @widget[:AP][:N][:Yes].type)
      end

      it "creates the /Off appearance stream" do
        @generator.create_appearance_streams
        assert_operators(@widget[:AP][:N][:Off].stream,
                         [[:save_graphics_state],
                          [:set_device_gray_non_stroking_color, [1.0]],
                          [:append_rectangle, [0, 0, 12, 12]],
                          [:fill_path_non_zero],
                          [:append_rectangle, [0.5, 0.5, 11, 11]],
                          [:stroke_path], [:restore_graphics_state]])
      end

      it "creates the /Yes appearance stream" do
        @generator.create_appearance_streams
        assert_operators(@widget[:AP][:N][:Yes].stream,
                         [[:save_graphics_state],
                          [:set_device_gray_non_stroking_color, [1.0]],
                          [:append_rectangle, [0, 0, 12, 12]],
                          [:fill_path_non_zero],
                          [:append_rectangle, [0.5, 0.5, 11, 11]],
                          [:stroke_path], [:restore_graphics_state],

                          [:save_graphics_state],
                          [:set_font_and_size, [:F1, 10]],
                          [:begin_text],
                          [:set_text_matrix, [1, 0, 0, 1, 1.77, 2.545]],
                          [:show_text, ["!"]],
                          [:end_text],
                          [:restore_graphics_state]])
      end
    end
  end
end
