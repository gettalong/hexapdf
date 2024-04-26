# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2024 Thomas Leitner
#
# HexaPDF is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License version 3 as
# published by the Free Software Foundation with the addition of the
# following permission added to Section 15 as permitted in Section 7(a):
# FOR ANY PART OF THE COVERED WORK IN WHICH THE COPYRIGHT IS OWNED BY
# THOMAS LEITNER, THOMAS LEITNER DISCLAIMS THE WARRANTY OF NON
# INFRINGEMENT OF THIRD PARTY RIGHTS.
#
# HexaPDF is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public
# License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with HexaPDF. If not, see <http://www.gnu.org/licenses/>.
#
# The interactive user interfaces in modified source and object code
# versions of HexaPDF must display Appropriate Legal Notices, as required
# under Section 5 of the GNU Affero General Public License version 3.
#
# In accordance with Section 7(b) of the GNU Affero General Public
# License, a covered work must retain the producer line in every PDF that
# is created or manipulated using HexaPDF.
#
# If the GNU Affero General Public License doesn't fit your need,
# commercial licenses are available at <https://gettalong.at/hexapdf/>.
#++

require 'json'
require 'hexapdf/error'
require 'hexapdf/layout/style'
require 'hexapdf/layout/text_fragment'
require 'hexapdf/layout/text_layouter'

module HexaPDF
  module Type
    module AcroForm

      # The JavaScriptActions module implements JavaScript actions that can be specified for form
      # fields, such as formatting or calculating a field's value.
      #
      # These JavaScript functions are not specified in the PDF specification but can be found in
      # other reference materials (e.g. from Adobe).
      #
      # * Formatting
      #
      #   * +AFNumber_Format+: #apply_af_number_format
      #
      # * Calculating
      #
      #   * +AFSimple_Calculate+:: #run_af_simple_calculate
      #   * Simplified Field Notation expressions:: #run_simplified_field_notation
      #
      # See: PDF2.0 s12.6.4.17
      #
      # See:
      # - https://experienceleague.adobe.com/docs/experience-manager-learn/assets/FormsAPIReference.pdf
      # - https://opensource.adobe.com/dc-acrobat-sdk-docs/library/jsapiref/JS_API_AcroJS.html#printf
      module JavaScriptActions

        # Implements a parser for the simplified field notation used for calculating field values.
        #
        # This notation is used if the predefined functions are too simple but the calculation can
        # still be done by simple arithmetic.
        class SimplifiedFieldNotationParser

          # Raised if there was an error during parsing.
          class ParseError < StandardError; end

          # Creates a new instance for the given AcroForm +form+ instance and simplified field
          # notation string +sfn_string+.
          def initialize(form, sfn_string)
            @form = form
            @tokens = sfn_string.scan(/\p{Alpha}[^()*\/+-]*|[()*\/+-]/)
          end

          # Parses the string holding the simplified field notation and returns the calculation
          # result, or +nil+ if there was any problem.
          def parse
            result = expression
            @tokens.empty? ? result : nil
          rescue ParseError
            nil
          end

          private

          # Implementation of the four basis operations.
          OPERATIONS = {
            '+' => lambda {|l, r| l + r },
            '-' => lambda {|l, r| l - r },
            '*' => lambda {|l, r| l * r },
            '/' => lambda {|l, r| l / r },
          }

          # Parses the expression at the current position.
          #
          # expression = term [('+'|'-') term]*
          def expression
            result = term
            while @tokens.first == '+' || @tokens.first == '-'
              result = OPERATIONS[@tokens.shift].call(result, term)
            end
            result
          end

          # Parses the term at the current position.
          #
          # term = factor [('*'|'/') factor]*
          def term
            result = factor
            while @tokens.first == '*' || @tokens.first == '/'
              result = OPERATIONS[@tokens.shift].call(result, factor)
            end
            result
          end

          # Parses the factor at the current position.
          #
          # factor = '(' expr ')' | field_name
          def factor
            token = @tokens.shift
            if token == '('
              value = expression
              raise ParseError, "Unmatched parentheses" unless @tokens.shift == ')'
              value
            elsif (field = @form.field_by_name(token.strip.gsub('\\', ''))) && field.terminal_field?
              field.field_value.to_f
            else
              raise ParseError, "Invalid token encountered: #{token}"
            end
          end

        end

        module_function

        # Handles JavaScript formatting actions for single-line text fields.
        #
        # The argument +value+ is the value that should be formatted and +format_action+ is the PDF
        # formatting action object that should be applied. The latter may be +nil+ if no associated
        # formatted action is available.
        #
        # Returns [value, nil_or_text_color] where value is the new, potentially changed field value
        # and the second argument is either +nil+ (no change in color) or the color that should be
        # used for the text value.
        def apply_formatting(value, format_action)
          return [value, nil] unless (action_string = action_string(format_action))
          if action_string.start_with?('AFNumber_Format(')
            apply_af_number_format(value, action_string)
          else
            [value, nil]
          end
        end

        # Regular expression for matching the AFNumber_Format method.
        #
        # See: #apply_af_number_format
        AF_NUMBER_FORMAT_RE = /
          \AAFNumber_Format\(
            \s*(?<ndec>\d+)\s*,
            \s*(?<sep_style>[0-3])\s*,
            \s*(?<neg_style>[0-3])\s*,
            \s*0\s*,
            \s*(?<currency_string>".*?")\s*,
            \s*(?<prepend>false|true)\s*
          \);\z
        /x

        # Implements the JavaScript AFNumber_Format function and returns the formatted field value.
        #
        # The argument +value+ has to be the field's value (a String) and +action_string+ has to be
        # the JavaScript action string.
        #
        # The AFNumber_Format function assumes that the text field's value contains a number (as a
        # string) and formats it according to the instructions.
        #
        # It has the form <tt>AFNumber_Format(no_of_decimals, separator_style, negative_style,
        # currency_style, currency_string, prepend_currency)</tt> where the arguments have the
        # following meaning:
        #
        # +no_of_decimals+::
        #   The number of decimal places after the decimal point, e.g. for 3 it would result in
        #   123.456.
        #
        # +separator_style+::
        #   Defines which decimal separator and whether a thousands separator should be used.
        #
        #   Possible values are:
        #
        #   +0+:: Comma for thousands separator, point for decimal separator: 12,345.67
        #   +1+:: No thousands separator, point for decimal separator: 12345.67
        #   +2+:: Point for thousands separator, comma for decimal separator: 12.345,67
        #   +3+:: No thousands separator, comma for decimal separator: 12345,67
        #
        # +negative_style+::
        #   Defines how negative numbers should be formatted.
        #
        #   Possible values are:
        #
        #   +0+:: With minus and in color black: -12,345.67
        #   +1+:: Just in color red: 12,345.67
        #   +2+:: With parentheses and in color black: (12,345.67)
        #   +3+:: With parentheses and in color red: (12,345.67)
        #
        # +currency_style+::
        #   This argument is not used, should be 0.
        #
        # +currency_string+::
        #   A string with the currency symbol, e.g. € or $.
        #
        # +prepend_currency+::
        #   A boolean defining whether the currency string should be prepended (+true+) or appended
        #   (+false+).
        def apply_af_number_format(value, action_string)
          return [value, nil] unless (match = AF_NUMBER_FORMAT_RE.match(action_string))
          value = value.to_f
          format = "%.#{match[:ndec]}f"
          text_color = 'black'

          currency_string = JSON.parse(match[:currency_string])
          format = (match[:prepend] == 'true' ? currency_string + format : format + currency_string)

          if value < 0
            value = value.abs
            case match[:neg_style]
            when '0' # MinusBlack
              format = "-#{format}"
            when '1' # Red
              text_color = 'red'
            when '2' # ParensBlack
              format = "(#{format})"
            when '3' # ParensRed
              format = "(#{format})"
              text_color = 'red'
            end
          end

          result = sprintf(format, value)

          before_decimal_point, after_decimal_point = result.split('.')
          if match[:sep_style] == '0' || match[:sep_style] == '2'
            separator = (match[:sep_style] == '0' ? ',' : '.')
            before_decimal_point.gsub!(/\B(?=(\d\d\d)+(?:[^\d]|\z))/, separator)
          end
          result = if after_decimal_point
                     decimal_point = (match[:sep_style] =~ /[01]/ ? '.' : ',')
                     "#{before_decimal_point}#{decimal_point}#{after_decimal_point}"
                   else
                     before_decimal_point
                   end

          [result, text_color]
        end

        # Handles JavaScript calculation actions for single-line text fields.
        #
        # The argument +form+ is the main Form instance of the document (needed for accessing the
        # fields for the calculation) and +calculation_action+ is the PDF calculation action object
        # that should be applied.
        #
        # Returns the calculated value as string if the calculation was succcessful or +nil+
        # otherwise.
        #
        # A calculation may not be successful if
        #
        # * HexaPDF doesn't support the specific calculation action (e.g. because it contains
        #   general JavaScript instructions), or if
        # * there was an error during the calculation (e.g. because a field could not be resolved).
        def calculate(form, calculation_action)
          return nil unless (action_string = action_string(calculation_action))
          result = if action_string.start_with?('AFSimple_Calculate(')
                     run_af_simple_calculate(form, action_string)
                   elsif action_string.match?(/\/\*\*\s*BVCALC/)
                     run_simplified_field_notation(form, action_string)
                   else
                     nil
                   end
          result && (result == result.truncate ? result.to_i.to_s : result.to_s)
        end

        # Regular expression for matching the AFSimple_Calculate function.
        #
        # See: #run_af_simple_calculate
        AF_SIMPLE_CALCULATE_RE = /
          \AAFSimple_Calculate\(
            \s*"(?<function>AVG|SUM|PRD|MIN|MAX)"\s*,
            \s*(?<fields>.*)\s*
          \);\z
        /x

        # Mapping of AFSimple_Calculate function names to implementations.
        #
        # See: #run_af_simple_calculate
        AF_SIMPLE_CALCULATE = {
          'AVG' => lambda {|values| values.sum / values.length },
          'SUM' => lambda {|values| values.sum },
          'PRD' => lambda {|values| values.inject {|product, val| product * val } },
          'MIN' => lambda {|values| values.min },
          'MAX' => lambda {|values| values.max },
        }

        # Implements the JavaScript AFSimple_Calculate function and returns the calculated value.
        #
        # The argument +form+ has to be the document's main AcroForm object and +action_string+ has
        # to be the JavaScript action string.
        #
        # The AFSimple_Calculate function applies one of several predefined functions to the values
        # of the given fields. The values of those fields need to be strings representing numbers.
        #
        # It has the form <tt>AFSimple_Calculate(function, fields))</tt> where the arguments have
        # the following meaning:
        #
        # +function+::
        #   The name of the calculation function that should be applied to the values.
        #
        #   Possible values are:
        #
        #   +SUM+:: Calculate the sum of the given field values.
        #   +AVG+:: Calculate the average of the given field values.
        #   +PRD+:: Calculate the product of the given field values.
        #   +MIN+:: Calculate the minimum of the given field values.
        #   +MAX+:: Calculate the maximum of the given field values.
        #
        # +fields+::
        #   An array of AcroForm field names the values of which should be used.
        def run_af_simple_calculate(form, action_string)
          return nil unless (match = AF_SIMPLE_CALCULATE_RE.match(action_string))
          function = match[:function]
          values = match[:fields].scan(/".*?"/).map do |name|
            return nil unless (field = form.field_by_name(name[1..-2]))
            field.field_value.to_f
          end
          AF_SIMPLE_CALCULATE.fetch(function)&.call(values)
        end

        # Implements parsing of the simplified field notation (SFN).
        #
        # The argument +form+ has to be the document's main AcroForm object and +action_string+ has
        # to be the JavaScript action string.
        #
        # This notation is more powerful than AFSimple_Calculate as it allows arbitrary expressions
        # consisting of additions, substractions, multiplications and divisions, possibly grouped
        # using parentheses, and field names (which stand in for their value).
        #
        # Note: The implementation has been created by looking at sample documents using SFN. As
        # such this may not work for all documents that use SFN.
        def run_simplified_field_notation(form, action_string)
          return nil unless (match = /BVCALC(.*?)EVCALC/m.match(action_string))
          SimplifiedFieldNotationParser.new(form, match[1]).parse
        end

        # Returns the JavaScript action string for the given action.
        def action_string(action)
          return nil unless action && action[:S] == :JavaScript
          result = action[:JS]
          result.kind_of?(HexaPDF::Stream) ? result.stream : result
        end
        private :action_string

      end

    end
  end
end
