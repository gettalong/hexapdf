# -*- encoding: utf-8 -*-

require 'test_helper'
require_relative '../../content/common'
require 'hexapdf/document'
require 'hexapdf/type/acro_form/text_field'

describe HexaPDF::Type::AcroForm::TextField do
  before do
    @doc = HexaPDF::Document.new
    @field = @doc.add({}, type: :XXAcroFormField, subtype: :Tx)
  end

  it "resolves /MaxLen as inheritable field" do
    assert_nil(@field[:MaxLen])

    @field[:Parent] = {MaxLen: 5}
    assert_equal(5, @field[:MaxLen])

    @field[:MaxLen] = 6
    assert_equal(6, @field[:MaxLen])
  end

  describe "field_value" do
    it "handles unset values" do
      assert_nil(@field.field_value)
    end

    it "handles string values" do
      @field[:V] = "str"
      assert_equal("str", @field.field_value)
    end

    it "handles stream values" do
      @field[:V] = @doc.wrap({}, stream: "str")
      assert_equal("str", @field.field_value)
    end
  end

  describe "field_value=" do
    it "sets the field to the given value" do
      @field.field_value = 'str'
      assert_equal('str', @field.field_value)
    end

    it "fails if the :password flag is set" do
      @field.flag(:password)
      assert_raises(HexaPDF::Error) { @field.field_value = 'test' }
    end
  end

  it "sets and returns the default field value" do
    @field.default_field_value = 'hallo'
    assert_equal('hallo', @field.default_field_value)
  end

  describe "create_appearance_streams!" do
    before do
      @page = @doc.pages.add
      @form = @doc.acro_form(create: true)
      @form.set_default_appearance_string
    end

    describe "single line text fields" do
      before do
        @widget = @field.create_widget(@page, Rect: [0, 0, 0, 0])
      end

      it "updates the widgets to use the :N appearance stream" do
        @field.create_appearance_streams!
        assert_equal(:N, @widget[:AS])
      end

      it "set the print flag on the widgets" do
        @field.create_appearance_streams!
        assert(@widget.flagged?(:print))
      end

      describe "it adjusts the :Rect when necessary" do
        before do
          @widget.border_style(width: 3)
        end

        it "uses a default width if the width is zero" do
          @field.create_appearance_streams!
          assert_equal(@doc.config['acro_form.text_field.default_width'], @widget[:Rect].width)
        end

        it "uses the font size of the /DA if non-zero as basis for the height if it is zero" do
          @field.set_default_appearance_string(font_size: 10)
          @field.create_appearance_streams!
          assert_equal(15.25, @widget[:Rect].height)
        end

        it "uses a default font size as basis for the height if it and the set font size are zero" do
          assert_equal(0, @field.parse_default_appearance_string[1])
          @field.create_appearance_streams!
          assert_equal(15.25, @widget[:Rect].height)
        end
      end

      it "adds an appropriate form XObject" do
        @field.create_appearance_streams!
        form = @widget[:AP][:N]
        assert_equal(:XObject, form.type)
        assert_equal(:Form, form[:Subtype])
        assert_equal([0, 0, @widget[:Rect].width, @widget[:Rect].height], form[:BBox])
        assert_equal(@doc.acro_form.default_resources[:Font][:F1], form[:Resources][:Font][:F1])
      end

      describe "background color and border" do
        it "applies no background color or border if none is set" do
          @field.create_appearance_streams!
          assert_operators(@widget[:AP][:N].stream, [], range: 0..-3)
        end

        it "applies a background color if one set" do
          @widget.background_color(0.5)
          @field.create_appearance_streams!
          assert_operators(@widget[:AP][:N].stream,
                           [[:save_graphics_state],
                            [:set_device_gray_non_stroking_color, [0.5]],
                            [:append_rectangle, [0, 0, 100, 11.25]],
                            [:fill_path_non_zero],
                            [:restore_graphics_state]],
                           range: 0..-3)
        end

        it "sets the border color and width correctly" do
          @widget.border_style(color: 0.5, width: 4)
          @field.create_appearance_streams!
          assert_operators(@widget[:AP][:N].stream,
                           [[:save_graphics_state],
                            [:set_device_gray_stroking_color, [0.5]],
                            [:set_line_width, [4]],
                            [:append_rectangle, [2, 2, 96, 13.25]],
                            [:stroke_path],
                            [:restore_graphics_state]],
                           range: 0..-3)
        end

        it "handles the case of an underlined border" do
          @widget.border_style(style: :underlined)
          @field.create_appearance_streams!
          assert_operators(@widget[:AP][:N].stream,
                           [[:save_graphics_state],
                            [:move_to, [0.5, 0.5]], [:line_to, [99.5, 0.5]],
                            [:stroke_path],
                            [:restore_graphics_state]],
                           range: 0..-3)
        end
      end

      describe "font size calculation" do
        before do
          @widget[:Rect].height = 20
          @widget[:Rect].width = 100
          @field.field_value = ''
        end

        it "uses the non-zero font size" do
          @field.set_default_appearance_string(font_size: 10)
          @field.create_appearance_streams!
          assert_operators(@widget[:AP][:N].stream,
                           [:set_font_and_size, [:F1, 10]],
                           range: 5)
        end

        it "calculates the font size based on the rectangle height and border width" do
          @field.create_appearance_streams!
          assert_operators(@widget[:AP][:N].stream,
                           [:set_font_and_size, [:F1, 12.923875]],
                           range: 5)
          @widget.border_style(width: 2, color: :transparent)
          @field.create_appearance_streams!
          assert_operators(@widget[:AP][:N].stream,
                           [:set_font_and_size, [:F1, 11.487889]],
                           range: 5)
        end
      end

      describe "quadding e.g. text alignment" do
        before do
          @field.field_value = 'Test'
          @field.set_default_appearance_string(font_size: 10)
          @widget[:Rect].height = 20
        end

        it "works for left aligned text" do
          @field.text_alignment(:left)
          @field.create_appearance_streams!
          assert_operators(@widget[:AP][:N].stream,
                           [:set_text_matrix, [1, 0, 0, 1, 2, 6.41]],
                           range: 7)
        end

        it "works for right aligned text" do
          @field.text_alignment(:right)
          @field.create_appearance_streams!
          assert_operators(@widget[:AP][:N].stream,
                           [:set_text_matrix, [1, 0, 0, 1, 78.55, 6.41]],
                           range: 7)
        end

        it "works for center aligned text" do
          @field.text_alignment(:center)
          @field.create_appearance_streams!
          assert_operators(@widget[:AP][:N].stream,
                           [:set_text_matrix, [1, 0, 0, 1, 40.275, 6.41]],
                           range: 7)
        end

        it "vertically aligns to the font descender if the text is too high" do
          @widget[:Rect].height = 5
          @field.create_appearance_streams!
          assert_operators(@widget[:AP][:N].stream,
                           [:set_text_matrix, [1, 0, 0, 1, 2, 3.07]],
                           range: 7)
        end
      end
    end

    it "fails if no usable font is available" do
      @form.delete(:DA)
      assert_raises(HexaPDF::Error) { @field.create_appearance_streams! }
    end
  end

  describe "validation" do
    it "checks the value of the /FT field" do
      refute(@field.validate(auto_correct: false))
      assert(@field.validate)
      assert_equal(:Tx, @field.field_type)
    end

    it "checks that the field value has a valid type" do
      assert(@field.validate) # no field value
      @field.field_value = :sym
      refute(@field.validate)
    end

    it "checks the field value against /MaxLen" do
      @field[:V] = 'Test'
      assert(@field.validate)
      @field[:MaxLen] = 2
      refute(@field.validate)
    end
  end
end
