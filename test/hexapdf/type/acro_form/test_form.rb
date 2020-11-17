# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/type/acro_form/form'

describe HexaPDF::Type::AcroForm::Form do
  before do
    @doc = HexaPDF::Document.new
    @acro_form = @doc.add({Fields: []}, type: :XXAcroForm)
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
    @doc.pages.add[:Annots] = [{FT: :Tx}, {FT: :Tx2, Parent: {FT: :Tx3}}]
    @doc.pages.add[:Annots] = [{Subtype: :Widget}]
    @doc.pages.add

    result = [{FT: :Tx}, {FT: :Tx3}]
    root_fields = @acro_form.find_root_fields
    assert_equal(result, root_fields.map(&:value))
    assert_kind_of(HexaPDF::Type::AcroForm::TextField, root_fields[0])
    assert_equal([], @acro_form[:Fields].value)

    @acro_form.find_root_fields!
    assert_equal(result, @acro_form[:Fields].value.map(&:value))
  end

  describe "each_field" do
    before do
      @acro_form[:Fields] = [
        {T: :Tx1},
        {T: :Tx2, Kids: [{Subtype: :Widget}]},
        {T: :Tx3, FT: :Tx, Kids: [{T: :Tx4}, {T: :Tx5, Kids: [{T: :Tx6}]}]},
      ]
      @acro_form[:Fields][2][:Kids][0][:Parent] = @acro_form[:Fields][2]
      @acro_form[:Fields][2][:Kids][1][:Parent] = @acro_form[:Fields][2]
      @acro_form[:Fields][2][:Kids][1][:Kids][0][:Parent] = @acro_form[:Fields][2][:Kids][1]
    end

    it "iterates over all terminal fields" do
      assert_equal([:Tx1, :Tx2, :Tx4, :Tx6], @acro_form.each_field.map {|h| h[:T] })
    end

    it "iterates over all fields" do
      assert_equal([:Tx1, :Tx2, :Tx3, :Tx4, :Tx5, :Tx6],
                   @acro_form.each_field(terminal_only: false).map {|h| h[:T] })
    end

    it "converts the fields into their proper types if possible" do
      assert_kind_of(HexaPDF::Type::AcroForm::TextField, @acro_form.each_field.to_a.last)
    end
  end

  describe "field_by_name" do
    before do
      @acro_form[:Fields] = [
        {T: "root only", Kids: [{Subtype: :Widget}]},
        {T: "children", Kids: [{T: "child", FT: :Btn}, {T: "sub", Kids: [{T: "child"}]}]},
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

    it "returns the correct field class" do
      assert_kind_of(HexaPDF::Type::AcroForm::ButtonField, @acro_form.field_by_name('children.child'))
    end
  end

  describe "create fields" do
    describe "handles the general case" do
      it "works for names with a dot" do
        @acro_form[:Fields] = [{T: "root"}]
        field = @acro_form.create_text_field("root.field")
        assert_equal('root.field', field.full_field_name)
        assert_equal([field], @acro_form[:Fields][0][:Kids])
      end

      it "works for names without a dot" do
        field = @acro_form.create_text_field("field")
        assert_equal('field', field.full_field_name)
        assert([field], @acro_form[:Fields])
      end

      it "fails if the parent field is not found" do
        assert_raises(HexaPDF::Error) { @acro_form.create_text_field("root.field") }
      end
    end

    it "creates a text field" do
      field = @acro_form.create_text_field("field")
      assert_equal(:Tx, field.field_type)
    end

    it "creates a comb text field" do
      field = @acro_form.create_comb_text_field("field", 9)
      assert_equal(:Tx, field.field_type)
      assert_equal(9, field[:MaxLen])
      assert(field.comb_text_field?)
    end

    it "creates a password field" do
      field = @acro_form.create_password_field("field")
      assert_equal(:Tx, field.field_type)
      assert(field.password_field?)
    end

    it "creates a file select field" do
      field = @acro_form.create_file_select_field("field")
      assert_equal(:Tx, field.field_type)
      assert(field.file_select_field?)
    end

    it "creates a check box" do
      field = @acro_form.create_check_box("field")
      assert(field.check_box?)
    end

    it "creates a radio button" do
      field = @acro_form.create_radio_button("field")
      assert(field.radio_button?)
    end

    it "creates a combo box" do
      field = @acro_form.create_combo_box("field")
      assert(field.combo_box?)
    end

    it "creates a list box" do
      field = @acro_form.create_list_box("field")
      assert(field.list_box?)
    end
  end

  it "returns the default resources" do
    assert_kind_of(HexaPDF::Type::Resources, @acro_form.default_resources)
  end

  describe "set_default_appearance_string" do
    it "uses sane default values if no arguments are provided" do
      @acro_form.set_default_appearance_string
      assert_equal("0 g /F1 0 Tf", @acro_form[:DA])
      font = @acro_form.default_resources.font(:F1)
      assert(font)
      assert_equal(:Helvetica, font[:BaseFont])
    end

    it "allows specifying the used font and font size" do
      @acro_form.set_default_appearance_string(font: 'Times', font_size: 10)
      assert_equal("0 g /F1 10 Tf", @acro_form[:DA])
      assert_equal(:'Times-Roman', @acro_form.default_resources.font(:F1)[:BaseFont])
    end
  end

  it "sets the /NeedAppearances key" do
    @acro_form.need_appearances!
    assert(@acro_form[:NeedAppearances])
  end

  it "creates the appearances of all field widgets if necessary" do
    tf = @acro_form.create_text_field('test')
    tf.set_default_appearance_string
    tf.create_widget(@doc.pages.add)
    cb = @acro_form.create_check_box('test2')
    cb.create_widget(@doc.pages.add)
    @acro_form.create_appearances
    assert(tf.each_widget.all? {|w| w.appearance.normal_appearance.kind_of?(HexaPDF::Stream) })
    assert(cb.each_widget.all? {|w| w.appearance.normal_appearance[:Yes].kind_of?(HexaPDF::Stream) })
  end

  describe "perform_validation" do
    it "checks whether the /DR field is available when /DA is set" do
      @acro_form[:DA] = 'test'
      refute(@acro_form.validate)
    end

    it "checks whether the font used in /DA is available in /DR" do
      @acro_form[:DA] = '/F2 0 Tf /F1 0 Tf'
      refute(@acro_form.validate {|msg| assert_match(/DR must also be present/, msg) })
      @acro_form.default_resources[:Font] = {}
      refute(@acro_form.validate {|msg| assert_match(/font.*is not.*resource/, msg) })
      @acro_form.default_resources[:Font][:F1] = :yes
      assert(@acro_form.validate)
    end

    it "set the default appearance string, though optional, to a valid value to avoid problems" do
      assert(@acro_form.validate)
      assert_equal("0 g /F1 0 Tf", @acro_form[:DA])
    end

    describe "automatically creates the terminal fields; appearances" do
      before do
        @cb = @acro_form.create_check_box('test2')
        @cb.create_widget(@doc.pages.add)
      end

      it "does this if the configuration option is true" do
        assert(@acro_form.validate)
        assert_kind_of(HexaPDF::Stream, @cb[:AP][:N][:Yes])
      end

      it "does nothing if the configuration option is false" do
        @doc.config['acro_form.create_appearances'] = false
        assert(@acro_form.validate)
        refute_kind_of(HexaPDF::Stream, @cb[:AP][:N][:Yes])
      end
    end
  end
end
