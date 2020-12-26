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

  it "can be initialized as a multiline text field" do
    @field.flag(:comb)
    @field.initialize_as_multiline_text_field
    assert(@field.multiline_text_field?)
  end

  it "can be initialized as comb text field" do
    @field.flag(:multiline)
    @field.initialize_as_comb_text_field
    assert(@field.comb_text_field?)
  end

  it "can be initialized as password field" do
    @field.flag(:multiline)
    @field[:V] = 'test'
    @field.initialize_as_password_field
    assert_nil(@field[:V])
    assert(@field.password_field?)
  end

  it "can be initialized as a file select field" do
    @field.flag(:multiline)
    @field.initialize_as_file_select_field
    assert(@field.file_select_field?)
  end

  it "can check whether the field is a multiline text field" do
    refute(@field.multiline_text_field?)
    @field.flag(:multiline)
    assert(@field.multiline_text_field?)
  end

  it "can check whether the field is a comb text field" do
    refute(@field.comb_text_field?)
    @field.flag(:comb)
    assert(@field.comb_text_field?)
  end

  it "can check whether the field is a password field" do
    refute(@field.password_field?)
    @field.flag(:password)
    assert(@field.password_field?)
  end

  it "can check whether the field is a file select field" do
    refute(@field.file_select_field?)
    @field.flag(:file_select)
    assert(@field.file_select_field?)
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

    it "converts whitespace characters to simple spaces for single line text fields" do
      @field.field_value = "str\ning"
      assert_equal('str ing', @field.field_value)
    end

    it "updates the widgets to reflect the changed value" do
      widget = @field.create_widget(@doc.pages.add, Rect: [0, 0, 0, 0])
      @field.set_default_appearance_string
      @field.field_value = 'str'
      assert(widget[:AP][:N])
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

  it "returns the correct concrete field type" do
    assert_equal(:single_line_text_field, @field.concrete_field_type)
    @field.flag(:multiline, clear_existing: true)
    assert_equal(:multiline_text_field, @field.concrete_field_type)
    @field.flag(:password, clear_existing: true)
    assert_equal(:password_field, @field.concrete_field_type)
    @field.flag(:file_select, clear_existing: true)
    assert_equal(:file_select_field, @field.concrete_field_type)
    @field.flag(:comb, clear_existing: true)
    assert_equal(:comb_text_field, @field.concrete_field_type)
    @field.flag(:rich_text, clear_existing: true)
    assert_equal(:rich_text_field, @field.concrete_field_type)
  end

  describe "create_appearances" do
    before do
      @doc.acro_form(create: true)
      @field.create_widget(@doc.pages.add, Rect: [0, 0, 0, 0])
      @field.set_default_appearance_string
    end

    it "creates the needed streams" do
      @field.create_appearances
      assert(@field[:AP][:N])
    end

    it "doesn't create a new appearance stream if the field value hasn't changed, checked per widget" do
      @field.create_appearances
      stream = @field[:AP][:N].raw_stream
      @field.create_appearances
      assert_same(stream, @field[:AP][:N].raw_stream)
      @field.field_value = 'test'
      refute_same(stream, @field[:AP][:N].raw_stream)

      widget = @field.create_widget(@doc.pages.add, Rect: [0, 0, 0, 0])
      assert_nil(widget[:AP])
      @field.create_appearances
      refute_nil(widget[:AP][:N])
    end

    it "always creates a new appearance stream if force is true" do
      @field.create_appearances
      stream = @field[:AP][:N].raw_stream
      @field.create_appearances(force: true)
      refute_same(stream, @field[:AP][:N].raw_stream)
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
      @field[:V] = :sym
      refute(@field.validate)
    end

    it "checks the field value against /MaxLen" do
      @field[:V] = 'Test'
      assert(@field.validate)
      @field[:MaxLen] = 2
      refute(@field.validate)
      @field[:V] = nil
      assert(@field.validate)
    end
  end
end
