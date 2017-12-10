# -*- encoding: utf-8; frozen_string_literal: true -*-
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

require 'strscan'
require 'hexapdf/error'
require 'hexapdf/reference'

module HexaPDF

  # Tokenizes the content of an IO object following the PDF rules.
  #
  # See: PDF1.7 s7.2
  class Tokenizer

    # Represents a keyword in a PDF file.
    class Token < String; end

    TOKEN_DICT_START = Token.new('<<'.b) # :nodoc:
    TOKEN_DICT_END = Token.new('>>'.b) # :nodoc:
    TOKEN_ARRAY_START = Token.new('['.b) # :nodoc:
    TOKEN_ARRAY_END = Token.new(']'.b) # :nodoc:

    # This object is returned when there are no more tokens to read.
    NO_MORE_TOKENS = ::Object.new

    # Characters defined as whitespace.
    #
    # See: PDF1.7 s7.2.2
    WHITESPACE = "\0\t\n\f\r "

    # Characters defined as delimiters.
    #
    # See: PDF1.7 s7.2.2
    DELIMITER = "()<>{}/[]%"

    WHITESPACE_MULTI_RE = /[#{WHITESPACE}]+/ # :nodoc:

    WHITESPACE_OR_DELIMITER_RE = /(?=[#{Regexp.escape(WHITESPACE)}#{Regexp.escape(DELIMITER)}])/ # :nodoc:

    # The IO object from the tokens are read.
    attr_reader :io

    # Creates a new tokenizer.
    def initialize(io)
      @io = io
      @ss = StringScanner.new(''.b)
      @original_pos = -1
      self.pos = 0
    end

    # Returns the current position of the tokenizer inside in the IO object.
    #
    # Note that this position might be different from +io.pos+ since the latter could have been
    # changed somewhere else.
    def pos
      @original_pos + @ss.pos
    end

    # Sets the position at which the next token should be read.
    #
    # Note that this does **not** set +io.pos+ directly (at the moment of invocation)!
    def pos=(pos)
      if pos >= @original_pos && pos <= @original_pos + @ss.string.size
        @ss.pos = pos - @original_pos
      else
        @original_pos = pos
        @next_read_pos = pos
        @ss.string.clear
        @ss.reset
      end
    end

    # Returns a single token read from the current position and advances the scan pointer.
    #
    # Comments and a run of whitespace characters are ignored. The value +NO_MORE_TOKENS+ is
    # returned if there are no more tokens available.
    def next_token
      prepare_string_scanner(20)
      prepare_string_scanner(20) while @ss.skip(WHITESPACE_MULTI_RE)
      byte = @ss.string.getbyte(@ss.pos) || -1
      if (48 <= byte && byte <= 57) || byte == 45 || byte == 43 || byte == 46 # 0..9 - + .
        parse_number
      elsif byte == 47 # /
        parse_name
      elsif byte == 40 # (
        parse_literal_string
      elsif byte == 60 # <
        if @ss.string.getbyte(@ss.pos + 1) != 60
          parse_hex_string
        else
          @ss.pos += 2
          TOKEN_DICT_START
        end
      elsif byte == 62 # >
        unless @ss.string.getbyte(@ss.pos + 1) == 62
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
        until @ss.skip_until(/(?=[\r\n])/)
          return NO_MORE_TOKENS unless prepare_string_scanner
        end
        next_token
      elsif byte == -1 # we reached the end of the file
        NO_MORE_TOKENS
      else # everything else consisting of regular characters
        parse_keyword
      end
    end

    # Returns the next token but does not advance the scan pointer.
    def peek_token
      pos = self.pos
      tok = next_token
      self.pos = pos
      tok
    end

    # Returns the PDF object at the current position. This is different from #next_token because
    # references, arrays and dictionaries consist of multiple tokens.
    #
    # If the +allow_end_array_token+ argument is +true+, the ']' token is permitted to facilitate
    # the use of this method during array parsing.
    #
    # See: PDF1.7 s7.3
    def next_object(allow_end_array_token: false, allow_keyword: false)
      token = next_token

      if token.kind_of?(Token)
        case token
        when TOKEN_DICT_START
          token = parse_dictionary
        when TOKEN_ARRAY_START
          token = parse_array
        when TOKEN_ARRAY_END
          unless allow_end_array_token
            raise HexaPDF::MalformedPDFError.new("Found invalid end array token ']'", pos: pos)
          end
        else
          unless allow_keyword
            raise HexaPDF::MalformedPDFError.new("Invalid object, got token #{token}", pos: pos)
          end
        end
      end

      token
    end

    # Reads the byte (an integer) at the current position and advances the scan pointer.
    def next_byte
      prepare_string_scanner(1)
      @ss.pos += 1
      @ss.string.getbyte(@ss.pos - 1)
    end

    # Reads the cross-reference subsection entry at the current position and advances the scan
    # pointer.
    #
    # If a possible problem is detected, yields to caller.
    #
    # See: PDF1.7 7.5.4
    def next_xref_entry #:yield: matched_size
      prepare_string_scanner(20)
      unless @ss.skip(/(\d{10}) (\d{5}) ([nf])(?: \r| \n|\r\n|\r|\n)/) && @ss.matched_size == 20
        yield(@ss.matched_size)
      end
      [@ss[1].to_i, @ss[2].to_i, @ss[3]]
    end

    # Skips all whitespace at the current position.
    #
    # See: PDF1.7 s7.2.2
    def skip_whitespace
      prepare_string_scanner
      prepare_string_scanner while @ss.skip(WHITESPACE_MULTI_RE)
    end

    # Utility method for scanning until the given regular expression matches.
    #
    # If the end of the file is reached in the process, +nil+ is returned. Otherwise the matched
    # string is returned.
    def scan_until(re)
      until (data = @ss.scan_until(re))
        return nil unless prepare_string_scanner
      end
      data
    end

    private

    TOKEN_CACHE = Hash.new {|h, k| h[k] = Token.new(k) } # :nodoc:
    TOKEN_CACHE['true'] = true
    TOKEN_CACHE['false'] = false
    TOKEN_CACHE['null'] = nil

    # Parses the keyword at the current position.
    #
    # See: PDF1.7 s7.2
    def parse_keyword
      str = scan_until(WHITESPACE_OR_DELIMITER_RE) || @ss.scan(/.*/).freeze
      TOKEN_CACHE[str.freeze]
    end

    REFERENCE_RE = /[#{WHITESPACE}]+([+-]?\d+)[#{WHITESPACE}]+R#{WHITESPACE_OR_DELIMITER_RE}/ # :nodoc:

    # Parses the number (integer or real) at the current position.
    #
    # See: PDF1.7 s7.3.3
    def parse_number
      if (val = @ss.scan(/[+-]?\d++(?!\.)/))
        tmp = val.to_i
        # Handle object references, see PDF1.7 s7.3.10
        prepare_string_scanner(10)
        tmp = Reference.new(tmp, @ss[1].to_i) if @ss.scan(REFERENCE_RE)
        tmp
      elsif (val = @ss.scan(/[+-]?(?:\d+\.\d*|\.\d+)/))
        val << '0' if val.getbyte(-1) == 46 # dot '.'
        Float(val)
      else
        parse_keyword
      end
    end

    LITERAL_STRING_ESCAPE_MAP = { #:nodoc:
      'n' => "\n",
      'r' => "\r",
      't' => "\t",
      'b' => "\b",
      'f' => "\f",
      '(' => "(",
      ')' => ")",
      '\\' => "\\",
    }.freeze

    # Parses the literal string at the current position.
    #
    # See: PDF1.7 s7.3.4.2
    def parse_literal_string
      @ss.pos += 1
      str = "".b
      parentheses = 1

      while parentheses != 0
        data = scan_until(/([()\\\r])/)
        char = @ss[1]
        unless data
          raise HexaPDF::MalformedPDFError.new("Unclosed literal string found", pos: pos)
        end

        str << data
        prepare_string_scanner if @ss.eos?
        case char
        when '(' then parentheses += 1
        when ')' then parentheses -= 1
        when "\r"
          str[-1] = "\n"
          @ss.pos += 1 if @ss.peek(1) == "\n"
        when '\\'
          str.chop!
          byte = @ss.get_byte
          if (data = LITERAL_STRING_ESCAPE_MAP[byte])
            str << data
          elsif byte == "\r" || byte == "\n"
            @ss.pos += 1 if byte == "\r" && @ss.peek(1) == "\n"
          elsif byte >= '0' && byte <= '7'
            byte += @ss.scan(/[0-7]{0,2}/)
            str << byte.oct.chr
          else
            str << byte
          end
        end
      end

      str.chop! # remove last parsed closing parenthesis
      str
    end

    # Parses the hex string at the current position.
    #
    # See: PDF1.7 s7.3.4.3
    def parse_hex_string
      @ss.pos += 1
      data = scan_until(/(?=>)/)
      unless data
        raise HexaPDF::MalformedPDFError.new("Unclosed hex string found", pos: pos)
      end

      @ss.pos += 1
      data.tr!(WHITESPACE, "")
      [data].pack('H*')
    end

    # Parses the name at the current position.
    #
    # See: PDF1.7 s7.3.5
    def parse_name
      @ss.pos += 1
      str = scan_until(WHITESPACE_OR_DELIMITER_RE) || @ss.scan(/.*/)
      str.gsub!(/#[A-Fa-f0-9]{2}/) {|m| m[1, 2].hex.chr }
      if str.force_encoding(Encoding::UTF_8).valid_encoding?
        str.to_sym
      else
        str.force_encoding(Encoding::BINARY).to_sym
      end
    end

    # Parses the array at the current position.
    #
    # It is assumed that the initial '[' has already been scanned.
    #
    # See: PDF1.7 s7.3.6
    def parse_array
      result = []
      while true
        obj = next_object(allow_end_array_token: true)
        break if obj.equal?(TOKEN_ARRAY_END)
        result << obj
      end
      result
    end

    # Parses the dictionary at the current position.
    #
    # It is assumed that the initial '<<' has already been scanned.
    #
    # See: PDF1.7 s7.3.7
    def parse_dictionary
      result = {}
      while true
        # Use #next_token because we either need a Name or the '>>' token here, the latter would
        # throw an error with #next_object.
        key = next_token
        break if key.equal?(TOKEN_DICT_END)
        unless key.kind_of?(Symbol)
          raise HexaPDF::MalformedPDFError.new("Dictionary keys must be PDF name objects", pos: pos)
        end

        val = next_object
        next if val.nil?

        result[key] = val
      end
      result
    end

    # Prepares the StringScanner by filling its string instance with enough bytes.
    #
    # The number of needed bytes can be specified via the optional +needed_bytes+ argument.
    #
    # Returns +true+ if the end of the underlying IO stream has not been reached, yet.
    def prepare_string_scanner(needed_bytes = nil)
      return if needed_bytes && @ss.rest_size >= needed_bytes
      @io.seek(@next_read_pos)
      return false if @io.eof?

      @ss << @io.read(8192)
      if @ss.pos > 8192 && @ss.string.length > 16384
        @ss.string.slice!(0, 8192)
        @ss.pos -= 8192
        @original_pos += 8192
      end
      @next_read_pos = @io.pos
      true
    end

  end

end
