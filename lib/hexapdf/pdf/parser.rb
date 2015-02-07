# -*- encoding: utf-8 -*-

require 'hexapdf/error'
require 'hexapdf/pdf/tokenizer'
require 'hexapdf/pdf/stream'
require 'hexapdf/pdf/xref_table'
require 'hexapdf/pdf/revision'

module HexaPDF
  module PDF

    # Parses an IO stream according to PDF1.7 to get at the contained objects.
    #
    # This class also contains higher-level methods for getting indirect objects and revisions.
    #
    # See: PDF1.7 s7
    class Parser

      # Creates a new parser for the given IO object.
      #
      # PDF references are resolved using the associated Document object.
      def initialize(io, document)
        @io = io
        @tokenizer = Tokenizer.new(io)
        @document = document
        retrieve_pdf_header_offset_and_version
      end

      # Loads the indirect (potentially compressed) object specified by the given cross-reference
      # entry.
      #
      # For information about the +xref_entry+ parameter, have a look at XRefTable and
      # XRefTable::Entry.
      def load_object(xref_entry)
        obj, oid, gen, stream = case xref_entry.type
                                when :in_use
                                  parse_indirect_object(xref_entry.pos)
                                when :free
                                  [nil, xref_entry.oid, xref_entry.gen, nil]
                                when :compressed
                                  raise "Object streams are not implemented yet"
                                else
                                  raise HexaPDF::Error, "Invalid cross-reference type '#{xref_entry.type}' encountered"
                                end

        if xref_entry.oid != 0 && (oid != xref_entry.oid || gen != xref_entry.gen)
          raise HexaPDF::MalformedPDFError.new("The oid,gen (#{oid},#{gen}) values of the indirect object don't " +
                                               "match the values (#{xref_entry.oid},#{xref_entry.gen}) from the xref table")
        end

        @document.wrap(obj, oid: oid, gen: gen, stream: stream)
      end

      # Parses the indirect object at the specified offset.
      #
      # This method is used by a PDF Document to load objects. It should **not** be used by any
      # other object because invalid object positions lead to errors.
      #
      # Returns an array containing [object, oid, gen, stream].
      #
      # See: PDF1.7 s7.3.10, s7.3.8
      def parse_indirect_object(offset = nil)
        @tokenizer.pos = offset + @header_offset if offset
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
          length = @document.unwrap(object[:Length]) || 0
          @tokenizer.pos = pos + length

          tok = @tokenizer.next_token
          unless tok.kind_of?(Tokenizer::Token) && tok == 'endstream'
            raise HexaPDF::MalformedPDFError.new("Stream content must be followed by keyword endstream", @tokenizer.pos)
          end
          tok = @tokenizer.next_token

          stream = StreamData.new(@tokenizer.io, offset: pos, length: length,
                                  filter: @document.unwrap(object[:Filter]),
                                  decode_parms: @document.unwrap(object[:DecodeParms]))
        end

        unless tok.kind_of?(Tokenizer::Token) && tok == 'endobj'
          raise HexaPDF::MalformedPDFError.new("Indirect object must be followed by keyword endobj", @tokenizer.pos)
        end

        [object, oid, gen, stream]
      end

      # Loads a single Revision whose cross-reference table/stream is located at the given position.
      def load_revision(pos)
        xref_table, trailer = if xref_table?(pos)
                                parse_xref_table_and_trailer(pos)
                              else
                                obj = load_object(XRefTable.in_use_entry(0, 0, pos))
                                if !obj.value.kind_of?(Hash) || obj.value[:Type] != :XRef
                                  raise HexaPDF::MalformedPDFError.new("Object is not a cross-reference stream", pos)
                                end
                                [obj.xref_table, obj.value]
                              end
        Revision.new(@document.wrap(trailer, type: :Trailer), xref_table: xref_table, parser: self)
      end

      # Looks at the given offset and returns +true+ if there is a cross-reference table at that position.
      def xref_table?(offset)
        @tokenizer.pos = offset + @header_offset
        token = @tokenizer.peek_token
        token.kind_of?(Tokenizer::Token) && token == 'xref'
      end

      # Parses the cross-reference table at the given position and the following trailer and returns
      # them as an array consisting of an XRefTable instance and a hash.
      #
      # Note that this method can only parse cross-reference tables, not cross-reference streams!
      #
      # See: PDF1.7 s7.5.4, s7.5.5; ADB1.7 sH.3-3.4.3
      def parse_xref_table_and_trailer(offset)
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
            if xref.entry?(oid)
              next
            elsif type == 'n'
              xref.add_in_use_entry(oid, gen, pos)
            else
              xref.add_free_entry(oid, gen)
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

        [xref, trailer]
      end

      # Returns the offset of the main cross-reference table/stream.
      #
      # Implementation note: Normally, the %%EOF marker has to be on the last line, however, Adobe
      # viewers relax this restriction and so do we.
      #
      # See: PDF1.7 s7.5.5, ADB1.7 sH.3-3.4.4
      def startxref_offset
        # 1024 for %%EOF + 30 for startxref and offset lines
        @io.seek(-1054, IO::SEEK_END) rescue @io.seek(0)
        lines = @io.read(1054).split(/[\r\n]+/)

        eof_index = lines.rindex {|l| l.strip == '%%EOF' }
        unless eof_index
          raise HexaPDF::MalformedPDFError.new("PDF file trailer is missing end-of-file marker", @io.pos)
        end

        unless lines[eof_index - 2].strip == "startxref"
          raise HexaPDF::MalformedPDFError.new("PDF file trailer is missing startxref keyword", @io.pos)
        end

        lines[eof_index - 1].to_i
      end

      # Returns the PDF version number that is stored in the file header.
      #
      # See: PDF1.7 s7.5.2
      def file_header_version
        unless @header_version
          raise HexaPDF::MalformedPDFError.new("PDF file header is missing or corrupt", 0)
        end
        @header_version
      end

      private

      # Retrieves the offset of the PDF header and the PDF version number in it.
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

      # Parses the PDF object at the current position.
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
