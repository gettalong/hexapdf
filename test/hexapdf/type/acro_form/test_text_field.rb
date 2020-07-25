# -*- encoding: utf-8 -*-

require 'test_helper'
require_relative '../../content/common'
require 'hexapdf/document'
require 'hexapdf/type/acro_form/text_field'

describe HexaPDF::Type::AcroForm::TextField do
  before do
    @doc = HexaPDF::Document.new
    @field = @doc.add({FT: :Tx}, type: :XXAcroFormField, subtype: :Tx)
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

  describe "create_appearances" do
    it "creates the needed streams" do
      @doc.acro_form(create: true)
      @field.create_widget(@doc.pages.add, Rect: [0, 0, 0, 0])
      @field.set_default_appearance_string
      @field.create_appearances
      assert(@field[:AP][:N])
    end

    it "uses the configuration option acro_form.appearance_generator" do
      @doc.config['acro_form.appearance_generator'] = 'NonExistent'
      assert_raises(Exception) { @field.create_appearances }
    end
  end

  describe "validation" do
    it "checks the value of the /FT field" do
      @field.delete(:FT)
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
