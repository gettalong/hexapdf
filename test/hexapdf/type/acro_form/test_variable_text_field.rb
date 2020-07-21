# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/type/acro_form/variable_text_field'

describe HexaPDF::Type::AcroForm::VariableTextField do
  before do
    @doc = HexaPDF::Document.new
    @doc.acro_form(create: true).set_default_appearance_string
    @field = @doc.add({}, type: HexaPDF::Type::AcroForm::VariableTextField)
  end

  describe "text_alignment" do
    it "returns the alignment value for displaying text" do
      assert_equal(:left, @field.text_alignment)
      @field[:Q] = 1
      assert_equal(:center, @field.text_alignment)
      @field[:Q] = 2
      assert_equal(:right, @field.text_alignment)
    end

    it "sets the alignment value for displaying text to a given value" do
      @field.text_alignment(:center)
      assert_equal(1, @field[:Q])
      @field.text_alignment(:right)
      assert_equal(2, @field[:Q])
      @field.text_alignment(:left)
      assert_equal(0, @field[:Q])
      assert_raises(ArgumentError) { @field.text_alignment(:unknown) }
    end
  end

  describe "set_default_appearance_string" do
    it "creates the AcroForm object if it doesn't exist" do
      @doc.catalog.delete(:AcroForm)
      @field.set_default_appearance_string
      assert(@doc.acro_form)
    end

    it "uses sane default values if no arguments are provided" do
      @field.set_default_appearance_string
      assert_equal("0 g /F1 0 Tf", @field[:DA])
      font = @doc.acro_form.default_resources.font(:F1)
      assert(font)
      assert_equal(:Helvetica, font[:BaseFont])
    end

    it "allows specifying the used font and font size" do
      @field.set_default_appearance_string(font: 'Times', font_size: 10)
      assert_equal("0 g /F2 10 Tf", @field[:DA])
      assert_equal(:'Times-Roman', @doc.acro_form.default_resources.font(:F2)[:BaseFont])
    end
  end

  describe "parse_default_appearance_string" do
    it "parses the default appearance string of the field" do
      @field[:DA] = "1 g /F1 20 Tf 5 w /F2 10 Tf"
      assert_equal([:F2, 10], @field.parse_default_appearance_string)
    end

    it "uses the default appearance string of a parent field" do
      parent = @doc.add({DA: "/F1 15 Tf"}, type: :XXAcroFormField)
      @field[:Parent] = parent
      assert_equal([:F1, 15], @field.parse_default_appearance_string)
    end

    it "uses the global default appearance string" do
      assert_equal([:F1, 0], @field.parse_default_appearance_string)
    end

    it "fails if no /DA value is set" do
      @doc.acro_form.delete(:DA)
      assert_raises(HexaPDF::Error) { @field.parse_default_appearance_string }
    end
  end
end
