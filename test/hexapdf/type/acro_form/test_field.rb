# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/type/acro_form/field'

describe HexaPDF::Type::AcroForm::Field do
  before do
    @doc = HexaPDF::Document.new
    @field = @doc.add({}, type: :XXAcroFormField)
  end

  it "must always be an indirect object" do
    assert(@field.must_be_indirect?)
  end

  it "resolves inherited field values" do
    assert_nil(@field[:FT])

    @field[:Parent] = {FT: :Tx}
    assert_equal(:Tx, @field[:FT])

    @field[:FT] = :Ch
    assert_equal(:Ch, @field[:FT])
  end

  it "has convenience methods for accessing the field flags" do
    assert_equal([], @field.flags)
    refute(@field.flagged?(:required))
    @field.flag(:required, 2)
    assert(@field.flagged?(2))
    assert_equal(6, @field[:Ff])
  end

  it "returns the field type" do
    assert_nil(@field.field_type)

    @field[:FT] = :Tx
    assert_equal(:Tx, @field.field_type)
  end

  it "returns the field name" do
    assert_nil(@field.field_name)
    @field[:T] = 'test'
    assert_equal('test', @field.field_name)
  end

  it "returns the full name of the field" do
    assert_nil(@field.full_field_name)

    @field[:T] = "Test"
    assert_equal("Test", @field.full_field_name)

    @field[:Parent] = {}
    assert_equal("Test", @field.full_field_name)

    @field[:Parent] = {T: 'Parent'}
    assert_equal("Parent.Test", @field.full_field_name)
  end

  it "returns whether the field is a terminal field" do
    assert(@field.terminal_field?)

    @field[:Kids] = []
    assert(@field.terminal_field?)

    @field[:Kids] = [{Subtype: :Widget}]
    assert(@field.terminal_field?)

    @field[:Kids] = [{FT: :Tx}]
    refute(@field.terminal_field?)
  end

  describe "perform_validation" do
    before do
      @field[:FT] = :Tx
    end

    it "requires the /FT key to be present for terminal fields" do
      assert(@field.validate)

      @field.delete(:FT)
      refute(@field.validate)

      @field[:Kids] = [{}]
      assert(@field.validate)
    end

    it "doesn't allow periods in partial field names" do
      assert(@field.validate)

      @field[:T] = "Test"
      assert(@field.validate)

      @field[:T] = "Te.st"
      refute(@field.validate)
    end
  end
end
