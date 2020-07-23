# -*- encoding: utf-8 -*-

require 'test_helper'
require_relative '../../content/common'
require 'hexapdf/document'
require 'hexapdf/type/acro_form/button_field'

describe HexaPDF::Type::AcroForm::ButtonField do
  before do
    @doc = HexaPDF::Document.new
    @field = @doc.add({FT: :Btn, T: 'button'}, type: :XXAcroFormField, subtype: :Btn)
  end

  it "can be initialized as push button" do
    @field.initialize_as_push_button
    assert_nil(@field[:V])
    assert(@field.push_button?)
  end

  it "can be initialized as check box" do
    @field.initialize_as_check_box
    assert_equal(:Off, @field[:V])
    assert(@field.check_box?)
  end

  it "can be initialized as radio button" do
    @field.initialize_as_radio_button
    assert_equal(:Off, @field[:V])
    assert_equal(1 << 15, @field[:Ff])
  end

  describe "push button" do
    before do
      @field.flag(:push_button)
    end

    it "can be asked whether it is a push button field" do
      @field.flag(:push_button)
      assert(@field.push_button?)
    end

    it "always returns nil when getting the field value" do
      @field[:V] = :test
      assert_nil(@field.field_value)
    end

    it "doesn't set a field value" do
      @field.field_value = :test
      assert_nil(@field[:V])
    end

    it "applies sensible default values when creating a widget" do
      widget = @field.create_widget(@doc.pages.add)
      border_style = widget.border_style
      assert_equal([0], border_style.color.components)
      assert_equal(1, border_style.width)
      assert_equal(:beveled, border_style.style)
      assert_equal([0.5], widget.background_color.components)
    end
  end

  describe "check box" do
    before do
      @field.unflag(:push_button)
      @field.unflag(:radio)
    end

    it "can be asked whether it is a check box field" do
      assert(@field.check_box?)
    end

    it "returns a correct field value" do
      refute(@field.field_value)
      @field[:V] = :Off
      refute(@field.field_value)
      @field[:V] = :Yes
      assert(@field.field_value)
    end

    it "sets a correct field value" do
      @field.field_value = true
      assert_equal(:Yes, @field[:V])
      @field.field_value = false
      assert_equal(:Off, @field[:V])
    end

    it "can determine the name of the on state" do
      assert_equal(:Yes, @field.check_box_on_name)
      widget = @field.create_widget(@doc.pages.add)
      assert_equal(:Yes, @field.check_box_on_name)
      widget[:AP][:N].delete(:Yes)
      widget[:AP][:N][:On] = nil
      assert_equal(:On, @field.check_box_on_name)
    end

    it "applies sensible default values when creating a widget" do
      widget = @field.create_widget(@doc.pages.add)
      assert_equal({Yes: nil, Off: nil}, widget[:AP][:N].value)
      border_style = widget.border_style
      assert_equal([0], border_style.color.components)
      assert_equal(1, border_style.width)
      assert_equal(:solid, border_style.style)
      assert_equal([1], widget.background_color.components)
      assert_equal(:check, widget.marker_style.style)
    end
  end

  describe "radio button" do
    before do
      @field.unflag(:push_button)
      @field.flag(:radio)
    end

    it "can be asked whether it is a radio button field" do
      assert(@field.radio_button?)
    end

    it "returns a correct field value" do
      assert_nil(@field.field_value)
      @field[:V] = :Off
      assert_nil(@field.field_value)
      @field[:V] = :name
      assert_equal(:name, @field.field_value)
    end

    it "sets a correct field value" do
      @field.field_value = :button1
      assert_equal(:button1, @field[:V])
      @field.field_value = nil
      assert_equal(:Off, @field[:V])
    end

    it "applies sensible default values when creating a widget" do
      widget = @field.create_widget(@doc.pages.add, value: 'test')
      border_style = widget.border_style
      assert_equal([0], border_style.color.components)
      assert_equal(1, border_style.width)
      assert_equal(:solid, border_style.style)
      assert_equal([1], widget.background_color.components)
      assert_equal(:circle, widget.marker_style.style)
    end

    it "fails if the value argument is not provided for create_widget" do
      assert_raises(ArgumentError) { @field.create_widget(@doc.pages.add) }
    end
  end

  it "returns a default field value" do
    assert_method_invoked(@field, :normalized_field_value, [:DV]) do
      @field.default_field_value
    end
  end

  it "sets a default field value" do
    assert_method_invoked(@field, :normalized_field_value_set, [:DV, :value]) do
      @field.default_field_value = :value
    end
  end

  it "resolves /Opt as inheritable field" do
    @field[:Parent] = {Opt: 5}
    assert_equal(5, @field[:Opt])

    @field[:Opt] = 6
    assert_equal(6, @field[:Opt])
  end

  describe "create_appearance_streams" do
    it "works for check boxes" do
      @field.create_widget(@doc.pages.add, Rect: [0, 0, 0, 0])
      @field.create_appearance_streams
      assert(@field[:AP][:N][:Yes])
    end

    it "works for radio buttons" do
      @field.initialize_as_radio_button
      @field.create_widget(@doc.pages.add, Rect: [0, 0, 0, 0], value: :test)
      @field.create_appearance_streams
      assert(@field[:AP][:N][:test])
    end

    it "won't generate appearance streams if they already exist" do
      widget = @field.create_widget(@doc.pages.add, Rect: [0, 0, 0, 0])
      @field.create_appearance_streams
      yes = widget.appearance.normal_appearance[:Yes]
      off = widget.appearance.normal_appearance[:Off]
      widget.appearance.normal_appearance.delete(:Off)
      @field.create_appearance_streams
      assert_same(yes, widget.appearance.normal_appearance[:Yes])
      refute_same(off, widget.appearance.normal_appearance[:Off])
    end

    it "fails for unsupported button types" do
      @field.flag(:push_button)
      @field.create_widget(@doc.pages.add, Rect: [0, 0, 0, 0])
      assert_raises(HexaPDF::Error) { @field.create_appearance_streams }
    end

    it "uses the configuration option acro_form.appearance_generator" do
      @doc.config['acro_form.appearance_generator'] = 'NonExistent'
      assert_raises(Exception) { @field.create_appearance_streams }
    end
  end

  describe "validation" do
    it "checks the value of the /FT field" do
      @field.delete(:FT)
      refute(@field.validate(auto_correct: false))
      assert(@field.validate)
      assert_equal(:Btn, @field.field_type)
    end

    it "sets the field value to :Off it it is not set" do
      assert(@field.validate)
      assert_equal(:Off, @field[:V])
    end
  end
end
