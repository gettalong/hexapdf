# -*- encoding: utf-8 -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2017 Thomas Leitner
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
#++

require 'stringio'
require 'hexapdf/tokenizer'

module HexaPDF
  module Content

    # More efficient tokenizer for content streams. This tokenizer class works directly on a
    # string and not on an IO.
    #
    # Note: Indirect object references are *not* supported by this tokenizer!
    #
    # See: PDF1.7 s7.2
    class Tokenizer < HexaPDF::Tokenizer #:nodoc:

      # Creates a new tokenizer.
      def initialize(string)
        @ss = StringScanner.new(string)
        @string = string
      end

      # See: HexaPDF::Tokenizer#pos
      def pos
        @ss.pos
      end

      # See: HexaPDF::Tokenizer#pos=
      def pos=(pos)
        @ss.pos = pos
      end

      # See: HexaPDF::Tokenizer#scan_until
      def scan_until(re)
        @ss.scan_until(re)
      end

      # See: HexaPDF::Tokenizer#next_token
      def next_token
        @ss.skip(WHITESPACE_MULTI_RE)
        byte = @string.getbyte(@ss.pos) || -1
        if (48 <= byte && byte <= 57) || byte == 45 || byte == 43 || byte == 46 # 0..9 - +  .
          parse_number
        elsif (65 <= byte && byte <= 90) || (96 <= byte && byte <= 121)
          parse_keyword
        elsif byte == 47 # /
          parse_name
        elsif byte == 40 # (
          parse_literal_string
        elsif byte == 60 # <
          if @string.getbyte(@ss.pos + 1) != 60
            parse_hex_string
          else
            @ss.pos += 2
            TOKEN_DICT_START
          end
        elsif byte == 62 # >
          unless @string.getbyte(@ss.pos + 1) == 62
            raise HexaPDF::MalformedPDFError.new("Delimiter '>' found at invalid position", pos: pos)
          end
          @ss.pos += 2
          TOKEN_DICT_END
        elsif byte == 91 # [
          @ss.pos += 1
          TOKEN_ARRAY_START
        elsif byte == 93 # ]
          @ss.pos += 1
          TOKEN_ARRAY_END
        elsif byte == 123 || byte == 125 # { }
          Token.new(@ss.get_byte)
        elsif byte == 37 # %
          return NO_MORE_TOKENS unless @ss.skip_until(/(?=[\r\n])/)
          next_token
        elsif byte == -1
          NO_MORE_TOKENS
        else
          parse_keyword
        end
      end

      private

      # See: HexaPDF::Tokenizer#parse_number
      def parse_number
        if (val = @ss.scan(/[+-]?\d++(?!\.)/))
          val.to_i
        else
          val = @ss.scan(/[+-]?(?:\d+\.\d*|\.\d+)/)
          val << '0'.freeze if val.getbyte(-1) == 46 # dot '.'
          Float(val)
        end
      end

      # Stub implementation to prevent errors for not-overridden methods.
      def prepare_string_scanner(*)
      end

    end


    # This class knows how to correctly parse a content stream.
    #
    # == Overview
    #
    # A content stream is mostly just a stream of PDF objects. However, there is one exception:
    # inline images.
    #
    # Since inline images don't follow the normal PDF object parsing rules, they need to be
    # handled specially and this is the reason for this class. Therefore only the BI operator is
    # ever called for inline images because the ID and EI operators are handled by the parser.
    #
    # To parse some contents the #parse method needs to be called with the contents to be parsed
    # and a Processor object which is used for processing the parsed operators.
    class Parser

      # Creates a new Parser object and calls #parse.
      def self.parse(contents, processor)
        new.parse(contents, processor)
      end

      # Parses the contents and calls the processor object for each parsed operator.
      def parse(contents, processor)
        tokenizer = Tokenizer.new(contents)
        params = []
        while (obj = tokenizer.next_object(allow_keyword: true)) != Tokenizer::NO_MORE_TOKENS
          if obj.kind_of?(Tokenizer::Token)
            if obj == 'BI'.freeze
              params = parse_inline_image(tokenizer)
            end
            processor.process(obj.to_sym, params)
            params.clear
          else
            params << obj
          end
        end
      end

      private

      # Parses the inline image at the current position.
      def parse_inline_image(tokenizer)
        # BI has already been read, so read the image dictionary
        dict = {}
        while (key = tokenizer.next_object(allow_keyword: true))
          if key == 'ID'.freeze
            break
          elsif key == Tokenizer::NO_MORE_TOKENS
            raise HexaPDF::Error, "EOS while trying to read dictionary key for inline image"
          elsif !key.kind_of?(Symbol)
            raise HexaPDF::Error, "Inline image dictionary keys must be PDF name objects"
          end
          value = tokenizer.next_object
          if value == Tokenizer::NO_MORE_TOKENS
            raise HexaPDF::Error, "EOS while trying to read dictionary value for inline image"
          end
          dict[key] = value
        end

        # one whitespace character after ID
        tokenizer.next_byte

        # find the EI operator
        data = tokenizer.scan_until(/(?=EI[#{Tokenizer::WHITESPACE}])/o)
        if data.nil?
          raise HexaPDF::Error, "End inline image marker EI not found"
        end
        tokenizer.pos += 3
        [dict, data]
      end

    end

  end
end
