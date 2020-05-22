# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/type/acro_form/form'

describe HexaPDF::Type::AcroForm::Form do
  before do
    @doc = HexaPDF::Document.new
    @acro_form = @doc.add({}, type: :XXAcroForm)
  end

  describe "signature flags" do
    before do
      @acro_form[:SigFlags] = 3
    end

    it "returns all signature flags" do
      assert_equal([:signatures_exist, :append_only], @acro_form.signature_flags)
    end

    it "returns true if the given flag is set" do
      assert(@acro_form.signature_flag?(:signatures_exist))
    end

    it "raises an error if an unknown flag name is provided" do
      assert_raises(ArgumentError) { @acro_form.signature_flag?(:non_exist) }
    end

    it "sets the given flag bits" do
      @acro_form[:SigFlags] = 0
      @acro_form.signature_flag(:append_only)
      assert_equal([:append_only], @acro_form.signature_flags)
      @acro_form.signature_flag(:signatures_exist, clear_existing: true)
      assert_equal([:signatures_exist], @acro_form.signature_flags)
    end
  end

  it "returns the root fields" do
    assert_equal([], @acro_form.root_fields.value)
  end

  it "finds the root fields" do
    @doc.pages.add[:Annots] = [{FT: :Tx1}, {FT: :Tx2, Parent: {FT: :Tx3}}]
    @doc.pages.add[:Annots] = [{Subtype: :Widget}]
    @doc.pages.add

    result = [{FT: :Tx1}, {FT: :Tx3}]
    assert_equal(result, @acro_form.find_root_fields.map(&:value))
    refute(@acro_form.key?(:Fields))

    @acro_form.find_root_fields!
    assert_equal(result, @acro_form[:Fields].value.map(&:value))
  end

  describe "each_field" do
    before do
      @acro_form[:Fields] = [
        {T: :Tx1},
        {T: :Tx2, Kids: [{Subtype: :Widget}]},
        {T: :Tx3, Kids: [{T: :Tx4}, {T: :Tx5, Kids: [{T: :Tx6}]}]},
      ]
    end

    it "iterates over all terminal fields" do
      assert_equal([:Tx1, :Tx2, :Tx4, :Tx6], @acro_form.each_field.map {|h| h[:T] })
    end

    it "iterates over all fields" do
      assert_equal([:Tx1, :Tx2, :Tx3, :Tx4, :Tx5, :Tx6],
                   @acro_form.each_field(terminal_only: false).map {|h| h[:T] })
    end
  end

  describe "field_by_name" do
    before do
      @acro_form[:Fields] = [
        {T: "root only", Kids: [{Subtype: :Widget, T: "no"}]},
        {T: "children", Kids: [{T: "child"}, {T: "sub", Kids: [{T: "child"}]}]},
      ]
    end

    it "works for root fields" do
      assert(@acro_form.field_by_name("root only"))
    end

    it "works for 1st level children" do
      assert(@acro_form.field_by_name("children.child"))
    end

    it "works for children on any level" do
      assert(@acro_form.field_by_name("children.sub.child"))
    end

    it "returns nil for unknown fields" do
      assert_nil(@acro_form.field_by_name("non root field"))
      assert_nil(@acro_form.field_by_name("root only.no child"))
      assert_nil(@acro_form.field_by_name("root only.no"))
      assert_nil(@acro_form.field_by_name("children.no child"))
      assert_nil(@acro_form.field_by_name("children.sub.no child"))
    end
  end

  it "returns the default resources" do
    assert_kind_of(HexaPDF::Type::Resources, @acro_form.default_resources)
  end

  it "allows setting a default 'default appearance string' if none is set" do
    @acro_form[:DA] = 'test'
    @acro_form.set_default_appearance_string
    assert_equal('test', @acro_form[:DA])

    @acro_form.delete(:DA)
    @acro_form.set_default_appearance_string
    assert_equal("0 g /F1 0 Tf", @acro_form[:DA])
    assert(@acro_form.default_resources.font(:F1))
  end

  describe "perform_validation" do
    it "checks whether the /DR field is available when /DA is set" do
      @acro_form[:DA] = 'test'
      refute(@acro_form.validate)
    end

    it "checks whether the font used in /DA is available in /DR" do
      @acro_form[:DA] = '/F2 0 Tf /F1 0 Tf'
      refute(@acro_form.validate {|msg, c| assert_match(/DR must also be present/, msg) })
      @acro_form.default_resources[:Font] = {}
      refute(@acro_form.validate {|msg, c| assert_match(/font.*is not.*resource/, msg) })
      @acro_form.default_resources[:Font][:F1] = :yes
      assert(@acro_form.validate)
    end

    it "set the default appearance string, though optional, to a valid value to avoid problems" do
      assert(@acro_form.validate)
      assert_equal("0 g /F1 0 Tf", @acro_form[:DA])
    end
  end
end
