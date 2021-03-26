# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/type/annotations/widget'

describe HexaPDF::Type::Annotations::Widget::AppearanceCharacteristics do
  before do
    @doc = HexaPDF::Document.new
    @annot = @doc.wrap({}, type: :XXAppearanceCharacteristics)
  end

  describe "validation" do
    it "needs /R to be a multiple of 90" do
      assert(@annot.validate)

      @annot[:R] = 45
      refute(@annot.validate)

      @annot[:R] = 90
      assert(@annot.validate)
    end
  end
end

describe HexaPDF::Type::Annotations::Widget do
  before do
    @doc = HexaPDF::Document.new
    @widget = @doc.wrap({Type: :Annot, Subtype: :Widget})
  end

  describe "form_field" do
    it "works for the field and widget being the same object" do
      @widget[:FT] = :Tx
      @widget[:T] = 'field'
      result = @widget.form_field
      assert_kind_of(HexaPDF::Type::AcroForm::TextField, result)
      assert_same(@widget.data, result.data)
    end

    it "works for a field with a parent field and the widget being the same object" do
      @widget[:Parent] = {FT: :Tx, T: 'parent', Kids: [@widget]}
      @widget[:T] = 'field'
      result = @widget.form_field
      assert_kind_of(HexaPDF::Type::AcroForm::TextField, result)
      assert_same(@widget.data, result.data)
    end

    it "works for the widget being in the /Kids array of the field" do
      @widget[:Parent] = {FT: :Tx, T: 'parent', Kids: [@widget]}
      result = @widget.form_field
      assert_kind_of(HexaPDF::Type::AcroForm::TextField, result)
      refute_same(@widget.data, result.data)
    end
  end

  describe "background_color" do
    it "returns the current background color" do
      assert_nil(@widget.background_color)
      @widget[:MK] = {BG: []}
      assert_nil(@widget.background_color)
      @widget[:MK] = {BG: [1]}
      assert_equal([1], @widget.background_color.components)
    end

    it "sets the color and returns self" do
      assert_same(@widget, @widget.background_color(51))
      assert_equal([0.2], @widget.background_color.components)
    end
  end

  describe "border_style" do
    before do
      @widget[:MK] = {BC: [1, 0, 1]}
      @color = HexaPDF::Content::ColorSpace.prenormalized_device_color([1, 0, 1])
    end

    describe "getter" do
      it "no /Border, /BS or /MK set" do
        @widget.delete(:MK)
        assert_equal([1, nil, :solid, 0, 0], @widget.border_style.to_a)
      end

      it "no /Border, /BS but with /MK empty" do
        @widget[:MK].delete(:BC)
        assert_equal([1, nil, :solid, 0, 0], @widget.border_style.to_a)
      end

      it "uses the color from /MK" do
        assert_equal([1, @color, :solid, 0, 0], @widget.border_style.to_a)
        @widget[:MK][:BC] = []
        assert_equal([1, nil, :solid, 0, 0], @widget.border_style.to_a)
      end

      it "uses the data from /Border" do
        @widget[:Border] = [1, 2, 3, [1, 2]]
        assert_equal([3, @color, [1, 2], 1, 2], @widget.border_style.to_a)
      end

      it "uses the data from /BS, overriding /Border values" do
        @widget[:Border] = [1, 2, 3, [1, 2]]
        @widget[:BS] = {W: 5, S: :D, D: [5, 6]}
        assert_equal([5, @color, [5, 6], 0, 0], @widget.border_style.to_a)

        [[:S, :solid], [:D, [5, 6]], [:B, :beveled], [:I, :inset],
         [:U, :underlined], [:Unknown, :solid]].each do |val, result|
          @widget[:BS] = {S: val, D: [5, 6]}
          assert_equal([1, @color, result, 0, 0], @widget.border_style.to_a)
        end
      end
    end

    describe "setter" do
      it "returns self" do
        assert_equal(@widget, @widget.border_style(width: 1))
      end

      it "sets the color" do
        @widget.border_style(color: [1.0, 51, 1.0])
        assert_equal([1, 0.2, 1], @widget[:MK][:BC].value)

        @widget.border_style(color: :transparent)
        assert_equal([], @widget[:MK][:BC].value)
      end

      it "sets the width" do
        @widget.border_style(width: 2)
        assert_equal(2, @widget[:BS][:W])
      end

      it "sets the style" do
        [[:solid, :S], [[5, 6], :D], [:beveled, :B], [:inset, :I], [:underlined, :U]].each do |val, r|
          @widget.border_style(style: val)
          assert_equal(r, @widget[:BS][:S])
          assert_equal(val, @widget[:BS][:D].value) if r == :D
        end
      end

      it "overrides all priorly set values" do
        @widget.border_style(width: 3, style: :inset, color: [1])
        @widget.border_style(width: 5)
        border_style = @widget.border_style
        assert_equal(:solid, border_style.style)
        assert_equal([0], border_style.color.components)
      end

      it "raises an error for an unknown style" do
        assert_raises(ArgumentError) { @widget.border_style(style: :unknown) }
      end
    end
  end

  describe "marker_style" do
    before do
      @chars = %w[4 l 8 u n H S]
      @values = [:check, :circle, :cross, :diamond, :square, :star, 'S']
      @widget[:Parent] = {FT: :Btn}
    end

    describe "style" do
      it "returns the style" do
        @chars.zip(@values) do |char, result|
          @widget[:MK] = {CA: char}
          assert_equal(result, @widget.marker_style.style)
        end
      end

      it "returns the correct default button style depending on the field" do
        @widget.form_field.initialize_as_check_box
        assert_equal(:check, @widget.marker_style.style)
        @widget.form_field.initialize_as_radio_button
        assert_equal(:circle, @widget.marker_style.style)
      end

      it "sets the button style" do
        @values.zip(@chars) do |argument, char|
          @widget.marker_style(style: argument)
          assert_equal(char, @widget[:MK][:CA])
        end
      end

      it "fails if an invalid argument is provided" do
        assert_raises(ArgumentError) { @widget.marker_style(style: 5) }
      end
    end

    describe "size" do
      it "returns the size" do
        @widget.form_field[:DA] = "/F 15 Tf"
        assert_equal(15, @widget.marker_style.size)
        @widget[:DA] = "/F 10 Tf"
        assert_equal(10, @widget.marker_style.size)
      end

      it "returns the default size if none is set" do
        assert_equal(0, @widget.marker_style.size)
      end

      it "sets the given size" do
        @widget.marker_style(size: 10)
        assert_equal('/ZaDb 10 Tf 0.0 g', @widget[:DA])
      end
    end

    describe "color" do
      it "returns the color" do
        @widget.form_field[:DA] = "0 1 0 rg"
        assert_equal([0, 1, 0], @widget.marker_style.color.components)
        @widget[:DA] = "0 0 1 rg"
        assert_equal([0, 0, 1], @widget.marker_style.color.components)
      end

      it "returns the default color if none is set" do
        assert_equal([0], @widget.marker_style.color.components)
      end

      it "sets the given color" do
        @widget.marker_style(color: [1.0, 51, 1.0])
        assert_equal([1, 0.2, 1], @widget.marker_style.color.components)
        @widget.marker_style(color: [1.0, 20, 1.0, 1.0])
        assert_equal([1, 0.2, 1, 1], @widget.marker_style.color.components)
      end
    end
  end
end
