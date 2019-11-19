# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/type/acro_form/form'

describe HexaPDF::Type::AcroForm::Form do
  before do
    @doc = HexaPDF::Document.new
    @acroform = @doc.add({}, type: :XXAcroForm)
  end

  describe "signature flags" do
    before do
      @acroform[:SigFlags] = 3
    end

    it "returns all signature flags" do
      assert_equal([:signatures_exist, :append_only], @acroform.signature_flags)
    end

    it "returns true if the given flag is set" do
      assert(@acroform.signature_flag?(:signatures_exist))
    end

    it "raises an error if an unknown flag name is provided" do
      assert_raises(ArgumentError) { @acroform.signature_flag?(:non_exist) }
    end

    it "sets the given flag bits" do
      @acroform[:SigFlags] = 0
      @acroform.signature_flag(:append_only)
      assert_equal([:append_only], @acroform.signature_flags)
      @acroform.signature_flag(:signatures_exist, clear_existing: true)
      assert_equal([:signatures_exist], @acroform.signature_flags)
    end
  end

  it "finds the root fields" do
    @doc.pages.add[:Annots] = [{FT: :Tx1}, {FT: :Tx2, Parent: {FT: :Tx3}}]
    @doc.pages.add[:Annots] = [{Subtype: :Widget}]
    @doc.pages.add

    result = [{FT: :Tx1}, {FT: :Tx3}]
    assert_equal(result, @acroform.find_root_fields.map(&:value))
    refute(@acroform.key?(:Fields))

    @acroform.find_root_fields!
    assert_equal(result, @acroform[:Fields].value.map(&:value))
  end

  describe "each_field" do
    before do
      @acroform[:Fields] = [
        {FT: :Tx1},
        {FT: :Tx2, Kids: [{Subtype: :Widget}]},
        {FT: :Tx3, Kids: [{FT: :Tx4}, {FT: :Tx5, Kids: [{FT: :Tx6}]}]},
      ]
    end

    it "iterates over all terminal fields" do
      assert_equal([:Tx1, :Tx2, :Tx4, :Tx6], @acroform.each_field.map {|h| h[:FT] })
    end

    it "iterates over all fields" do
      assert_equal([:Tx1, :Tx2, :Tx3, :Tx4, :Tx5, :Tx6],
                   @acroform.each_field(terminal_only: false).map {|h| h[:FT] })
    end
  end
end
