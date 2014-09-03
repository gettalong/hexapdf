# -*- encoding: utf-8 -*-

require 'hexapdf/error'
require 'hexapdf/pdf/tokenizer'
require 'hexapdf/pdf/indirect_object'
require 'hexapdf/pdf/stream'
require 'hexapdf/pdf/xref_table'

module HexaPDF
  module PDF

    # Parses an IO stream according to PDF1.7 to get at the PDF objects.
    #
    # This class is normally not directly used but indirectly via HexaPDF::Document.
    #
    # See: PDF1.7 s7
    class Parser

      # Create a new parser for the given HexaPDF::Document and IO objects.
      def initialize(document, io)
        @document = document
        @io = io
        @tokenizer = Tokenizer.new(io)
      end

      # Parse the indirect object at the specified offset.
      #
      # This method is used by an XRefTable to load objects. It should **not** be used by any other
      # object because invalid object positions lead to an error.
      #
      # Returns an IndirectObject (or a subclass).
      #
      # See: PDF1.7 s7.3.10, s7.3.8
      def parse_indirect_object(offset = @tokenizer.pos)
        @tokenizer.pos = offset if @tokenizer.pos != offset
        oid = @tokenizer.next_token
        gen = @tokenizer.next_token
        tok = @tokenizer.next_token
        unless oid.kind_of?(Integer) && gen.kind_of?(Integer) &&
            tok.kind_of?(Tokenizer::Token) && tok == 'obj'
          raise HexaPDF::MalformedPDFError.new("No valid object found", offset)
        end

        object = parse_object
        object = @document.wrap_object(object, oid, gen)

        tok = @tokenizer.next_token

        if tok.kind_of?(Tokenizer::Token) && tok == 'stream'
          unless object.value.kind_of?(Hash)
            raise HexaPDF::MalformedPDFError.new("A stream needs a dictionary, not a(n) #{object.class}", offset)
          end
          tok = @tokenizer.next_byte
          tok = @tokenizer.next_byte if tok == "\r"
          unless tok == "\n"
            raise HexaPDF::MalformedPDFError.new("Keyword stream must be followed by EOL", @tokenizer.pos - 1)
          end

          # Note that dereferencing :Length might move the IO pointer
          pos = @tokenizer.pos
          length = object[:Length].kind_of?(Integer) ? object[:Length] : @document.deref(object[:Length])
          @tokenizer.pos = pos + length

          tok = @tokenizer.next_token
          unless tok.kind_of?(Tokenizer::Token) && tok == 'endstream'
            raise HexaPDF::MalformedPDFError.new("Stream content must be followed by keyword endstream", @tokenizer.pos)
          end
          tok = @tokenizer.next_token

          object.stream = Stream.new(@tokenizer.io, pos, length)
        end

        unless tok.kind_of?(Tokenizer::Token) && tok == 'endobj'
          raise HexaPDF::MalformedPDFError.new("Indirect object must be followed by keyword endobj", @tokenizer.pos)
        end

        object
      end

      # Parse the cross-reference table/stream at the given offset.
      def parse_xref(offset)
        @tokenizer.pos = offset
        token = @tokenizer.peek_token
        if token.kind_of?(Integer)
          parse_xref_stream
        else
          parse_xref_table
        end
      end

      # Return the offset of the main cross-reference table/stream.
      #
      # See: PDF1.7 s7.5.5
      def startxref_offset
        @io.seek(-50, IO::SEEK_END)
        lines = @io.read(50).split(/[\r\n]+/)

        unless lines[-1] == "%%EOF"
          raise HexaPDF::MalformedPDFError.new("PDF file trailer is missing end-of-file marker", @io.pos)
        end
        unless lines[-3] == "startxref"
          raise HexaPDF::MalformedPDFError.new("PDF file trailer is missing startxref keyword", @io.pos)
        end

        lines[-2].to_i
      end

      # Return the PDF version number that is stored in the file header.
      #
      # See: PDF1.7 s7.5.2
      def file_header_version
        @io.seek(0)
        version = /%PDF-(\d\.\d)/.match(@io.read(8))[1]
        unless version
          raise HexaPDF::MalformedPDFError.new("PDF file header is missing or corrupt", 0)
        end
        version
      end

      private

      # Parse the PDF object at the current position.
      #
      # If +allow_end_array_token+ is +true+, the ']' token is permitted to facilitate the use of
      # this method during array parsing.
      #
      # See: PDF1.7 s7.3
      def parse_object(allow_end_array_token = false)
        token = @tokenizer.next_token
        if token.kind_of?(Tokenizer::Token)
          case token
          when '['
            parse_array
          when '<<'
            parse_dictionary
          when ']'
            if allow_end_array_token
              token
            else
              raise HexaPDF::MalformedPDFError.new("Found invalid end array token ']'", @tokenizer.pos)
            end
          else
            raise HexaPDF::MalformedPDFError.new("Invalid object, got token #{token}", @tokenizer.pos)
          end
        else
          token
        end
      end

      # See: PDF1.7 s7.3.6
      def parse_array
        result = []
        loop do
          obj = parse_object(true)
          break if obj.kind_of?(Tokenizer::Token) && obj == ']'
          result << obj
        end
        result
      end

      # See: PDF1.7 s7.3.7
      def parse_dictionary
        result = {}
        loop do
          key = @tokenizer.next_token
          break if key.kind_of?(Tokenizer::Token) && key == '>>'
          unless key.kind_of?(Symbol)
            raise HexaPDF::MalformedPDFError.new("Dictionary keys must be PDF name objects", @tokenizer.pos)
          end

          val = parse_object
          next if val.nil?
          if val.kind_of?(Tokenizer::Token) && val == '>>'
            raise HexaPDF::MalformedPDFError.new("Dictionary key without associated value found", @tokenizer.pos)
          end
          result[key] = val
        end
        result
      end

      # See: PDF1.7 s7.5.4
      def parse_xref_table
        token = @tokenizer.next_token
        unless token.kind_of?(Tokenizer::Token) && token == 'xref'
          raise HexaPDF::MalformedPDFError.new("Xref table doesn't start with keyword xref", @tokenizer.pos)
        end

        xref = XRefTable.new(self)
        start = @tokenizer.next_token
        while start.kind_of?(Integer)
          number_of_entries = @tokenizer.next_token
          unless number_of_entries.kind_of?(Integer)
            raise HexaPDF::MalformedPDFError.new("Invalid cross-reference subsection start", @tokenizer.pos)
          end

          @tokenizer.skip_whitespace
          start.upto(start + number_of_entries - 1) do |oid|
            pos, gen, type = @tokenizer.next_xref_entry
            if type == 'n'
              xref[oid, gen] = pos
            else
              xref[oid, gen] = XRefTable::FREE_ENTRY
            end
          end

          start = @tokenizer.next_token
        end

        unless start.kind_of?(Tokenizer::Token) && start == 'trailer'
          raise HexaPDF::MalformedPDFError.new("Trailer doesn't start with keyword trailer", @tokenizer.pos)
        end

        trailer = parse_object
        unless trailer.kind_of?(Hash)
          raise HexaPDF::MalformedPDFError.new("Trailer is not a dictionary, but a(n) #{trailer.class}", @tokenizer.pos)
        end
        xref.trailer = trailer

        xref
      end

    end

  end
end
