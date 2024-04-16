# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/type/acro_form/java_script_actions'

describe HexaPDF::Type::AcroForm::JavaScriptActions do
  describe "formatting" do
    before do
      @action = {S: :JavaScript}
      @klass = HexaPDF::Type::AcroForm::JavaScriptActions
    end

    it "returns the original value if the formatting action can't be processed" do
      @action[:JS] = 'Unknown();'
      @klass.apply_formatting("10", @action)
    end

    describe "AFNumber_Format" do
      before do
        @value = '1234567.898765'
        @action[:JS] = ''
      end

      def assert_format(arg_string, result_value, result_color)
        @action[:JS] = "AFNumber_Format(#{arg_string});"
        value, text_color = @klass.apply_formatting(@value, @action)
        assert_equal(result_value, value)
        result_color ? assert_equal(result_color, text_color) : assert_nil(text_color)
      end

      it "respects the set number of decimals" do
        assert_format('0, 2, 0, 0, "E", false', "1.234.568E", "black")
        assert_format('2, 2, 0, 0, "E", false', "1.234.567,90E", "black")
      end

      it "respects the digit separator style" do
        ["1,234,567.90", "1234567.90", "1.234.567,90", "1234567,90"].each_with_index do |result, style|
          assert_format("2, #{style}, 0, 0, \"\", false", result, "black")
        end
      end

      it "respects the negative value styling" do
        @value = '-1234567.898'
        [["-E1234567,90", "black"], ["E1234567,90", "red"], ["(E1234567,90)", "black"],
         ["(E1234567,90)", "red"]].each_with_index do |result, style|
          assert_format("2, 3, #{style}, 0, \"E\", true", result[0], result[1])
        end
      end

      it "respects the specified currency string and position" do
        assert_format('2, 3, 0, 0, " E", false', "1234567,90 E", "black")
        assert_format('2, 3, 0, 0, "E ", true', "E 1234567,90", "black")
      end

      it "does nothing to the value if the JavasSript method could not be determined " do
        assert_format('2, 3, 0, 0, " E", false, a', "1234567.898765", nil)
      end
    end
  end
end
