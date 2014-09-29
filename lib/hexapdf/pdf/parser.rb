# -*- encoding: utf-8 -*-

require 'hexapdf/error'
require 'hexapdf/pdf/tokenizer'
require 'hexapdf/pdf/stream'
require 'hexapdf/pdf/xref_table'

module HexaPDF
  module PDF

    # Parses an IO stream according to PDF1.7 to get at the PDF objects.
    #
    # This class is not directly used but indirectly via HexaPDF::PDF::Document.
    #
    # See: PDF1.7 s7
    class Parser

      # Create a new parser for the given IO object.
      #
      # PDF references are resolved using the +resolver+ object which needs to respond to +unwrap+.
      def initialize(io, resolver)
        @io = io
        @tokenizer = Tokenizer.new(io)
        @resolver = resolver
        retrieve_pdf_header_offset_and_version
      end

      # Parse the indirect object at the specified offset.
      #
      # This method is used by a PDF Document to load objects. It should **not** be used by any
      # other object because invalid object positions lead to errors.
      #
      # Returns an array containing [object, oid, gen, stream].
      #
      # See: PDF1.7 s7.3.10, s7.3.8
      def parse_indirect_object(offset = @tokenizer.pos)
        @tokenizer.pos = offset + @header_offset
        oid = @tokenizer.next_token
        gen = @tokenizer.next_token
        tok = @tokenizer.next_token
        unless oid.kind_of?(Integer) && gen.kind_of?(Integer) &&
            tok.kind_of?(Tokenizer::Token) && tok == 'obj'
          raise HexaPDF::MalformedPDFError.new("No valid object found", offset)
        end

        object = parse_object

        tok = @tokenizer.next_token

        if tok.kind_of?(Tokenizer::Token) && tok == 'stream'
          unless object.kind_of?(Hash)
            raise HexaPDF::MalformedPDFError.new("A stream needs a dictionary, not a(n) #{object.class}", offset)
          end
          tok = @tokenizer.next_byte
          tok = @tokenizer.next_byte if tok == "\r"
          unless tok == "\n"
            raise HexaPDF::MalformedPDFError.new("Keyword stream must be followed by EOL", @tokenizer.pos - 1)
          end

          # Note that getting :Length might move the IO pointer (when references need to be resolved)
          pos = @tokenizer.pos
          length = @resolver.unwrap(object[:Length]) || 0
          @tokenizer.pos = pos + length

          tok = @tokenizer.next_token
          unless tok.kind_of?(Tokenizer::Token) && tok == 'endstream'
            raise HexaPDF::MalformedPDFError.new("Stream content must be followed by keyword endstream", @tokenizer.pos)
          end
          tok = @tokenizer.next_token

          stream = StreamData.new(@tokenizer.io, offset: pos, length: length,
                                  filter: @resolver.unwrap(object[:Filter]),
                                  decode_parms: @resolver.unwrap(object[:DecodeParms]))
        end

        unless tok.kind_of?(Tokenizer::Token) && tok == 'endobj'
          raise HexaPDF::MalformedPDFError.new("Indirect object must be followed by keyword endobj", @tokenizer.pos)
        end

        [object, oid, gen, stream]
      end

      # Look at the given offset and return +true+ if there is a cross-reference table at that position.
      def xref_table?(offset)
        @tokenizer.pos = offset + @header_offset
        token = @tokenizer.peek_token
        token.kind_of?(Tokenizer::Token) && token == 'xref'
      end

      # Parse the cross-reference table at the given position and return it as XRefTable instance.
      #
      # Note that this method can only parse cross-reference tables, not cross-reference streams!
      #
      # See: PDF1.7 s7.5.4
      def parse_xref_table(offset)
        @tokenizer.pos = offset + @header_offset
        token = @tokenizer.next_token
        unless token.kind_of?(Tokenizer::Token) && token == 'xref'
          raise HexaPDF::MalformedPDFError.new("Xref table doesn't start with keyword xref", @tokenizer.pos)
        end

        xref = XRefTable.new
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

      # Return the offset of the main cross-reference table/stream.
      #
      # Implementation note: Normally, the %%EOF marker has to be on the last line, however, Adobe
      # viewers relax this restriction and so do we.
      #
      # See: PDF1.7 s7.5.5, ADB1.7 sH.3-3.4.4
      def startxref_offset
        # 1024 for %%EOF + 30 for startxref and offset lines
        @io.seek(-1054, IO::SEEK_END) rescue @io.seek(0)
        lines = @io.read(1054).split(/[\r\n]+/)

        eof_index = lines.index {|l| l.strip == '%%EOF' }
        unless eof_index
          raise HexaPDF::MalformedPDFError.new("PDF file trailer is missing end-of-file marker", @io.pos)
        end

        unless lines[eof_index - 2].strip == "startxref"
          raise HexaPDF::MalformedPDFError.new("PDF file trailer is missing startxref keyword", @io.pos)
        end

        lines[eof_index - 1].to_i
      end

      # Return the PDF version number that is stored in the file header.
      #
      # See: PDF1.7 s7.5.2
      def file_header_version
        unless @header_version
          raise HexaPDF::MalformedPDFError.new("PDF file header is missing or corrupt", 0)
        end
        @header_version
      end

      private

      # Retrieve the offset of the PDF header and the PDF version number in it.
      #
      # The PDF header should normally appear on the first line. However, Adobe relaxes this
      # restriction so that the header may appear in the first 1024 bytes. We follow the Adobe
      # convention.
      #
      # See: PDF1.7 s7.5.2, ADB1.7 sH.3-3.4.1
      def retrieve_pdf_header_offset_and_version
        @io.seek(0)
        @header_offset = @io.read(1024).index(/%PDF-(\d\.\d)/) || 0
        @header_version = $1
      end

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
          # Use Tokenizer directly because we either need a Name or the '>>' token here, the latter
          # would throw an error with #parse_object.
          key = @tokenizer.next_token
          break if key.kind_of?(Tokenizer::Token) && key == '>>'
          unless key.kind_of?(Symbol)
            raise HexaPDF::MalformedPDFError.new("Dictionary keys must be PDF name objects", @tokenizer.pos)
          end

          val = parse_object
          next if val.nil?

          result[key] = val
        end
        result
      end

    end

  end
end
