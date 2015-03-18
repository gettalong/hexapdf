# -*- encoding: utf-8 -*-

require 'hexapdf/error'
require 'hexapdf/pdf/tokenizer'
require 'hexapdf/pdf/stream'
require 'hexapdf/pdf/xref_section'
require 'hexapdf/pdf/revision'
require 'hexapdf/pdf/type/xref_stream'
require 'hexapdf/pdf/type/object_stream'

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
        @object_stream_data = {}
        retrieve_pdf_header_offset_and_version
      end

      # Loads the indirect (potentially compressed) object specified by the given cross-reference
      # entry.
      #
      # For information about the +xref_entry+ argument, have a look at XRefSection and
      # XRefSection::Entry.
      def load_object(xref_entry)
        obj, oid, gen, stream = case xref_entry.type
                                when :in_use
                                  parse_indirect_object(xref_entry.pos)
                                when :free
                                  [nil, xref_entry.oid, xref_entry.gen, nil]
                                when :compressed
                                  load_compressed_object(xref_entry)
                                else
                                  raise HexaPDF::Error, "Invalid cross-reference type '#{xref_entry.type}' encountered"
                                end

        if xref_entry.oid != 0 && (oid != xref_entry.oid || gen != xref_entry.gen)
          raise HexaPDF::MalformedPDFError.new("The oid,gen (#{oid},#{gen}) values of the indirect object don't " +
                                               "match the values (#{xref_entry.oid},#{xref_entry.gen}) from the xref section")
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
        oid = @tokenizer.parse_token
        gen = @tokenizer.parse_token
        tok = @tokenizer.parse_token
        unless oid.kind_of?(Integer) && gen.kind_of?(Integer) &&
            tok.kind_of?(Tokenizer::Token) && tok == 'obj'
          raise HexaPDF::MalformedPDFError.new("No valid object found", offset)
        end

        if (tok = @tokenizer.peek_token) && tok.kind_of?(Tokenizer::Token) && tok == 'endobj'
          maybe_raise("No indirect object value exists between 'obj' and 'endobj'", pos: @tokenizer.pos)
          object = nil
        else
          object = @tokenizer.parse_object
        end

        tok = @tokenizer.parse_token

        if tok.kind_of?(Tokenizer::Token) && tok == 'stream'
          unless object.kind_of?(Hash)
            raise HexaPDF::MalformedPDFError.new("A stream needs a dictionary, not a(n) #{object.class}", offset)
          end
          tok1 = @tokenizer.next_byte
          tok2 = @tokenizer.next_byte if tok1 == "\r"
          if tok1 != "\n"  && tok1 != "\r"
            raise HexaPDF::MalformedPDFError.new("Keyword stream must be followed by LF or CR/LF", @tokenizer.pos)
          elsif tok1 == "\r" && tok2 != "\n"
            maybe_raise("Keyword stream must be followed by CR or CR/LF, not CR alone", pos: @tokenizer.pos)
            @tokenizer.pos -= 1
          end

          # Note that getting :Length might move the IO pointer (when references need to be resolved)
          pos = @tokenizer.pos
          length = @document.unwrap(object[:Length]) || 0
          @tokenizer.pos = pos + length

          tok = @tokenizer.parse_token
          unless tok.kind_of?(Tokenizer::Token) && tok == 'endstream'
            maybe_raise("Invalid stream length, keyword endstream not found", pos: @tokenizer.pos)
            @tokenizer.pos = pos
            if @tokenizer.scan_until(/(?=\n?endstream)/)
              length = @tokenizer.pos - pos
              tok = @tokenizer.parse_token
            else
              raise HexaPDF::MalformedPDFError.new("Stream content must be followed by keyword endstream", @tokenizer.pos)
            end
          end
          tok = @tokenizer.parse_token

          stream = StreamData.new(@tokenizer.io, offset: pos, length: length,
                                  filter: @document.unwrap(object[:Filter]),
                                  decode_parms: @document.unwrap(object[:DecodeParms]))
        end

        unless tok.kind_of?(Tokenizer::Token) && tok == 'endobj'
          raise HexaPDF::MalformedPDFError.new("Indirect object must be followed by keyword endobj", @tokenizer.pos)
        end

        [object, oid, gen, stream]
      end

      # Loads the compressed object identified by the cross-reference entry.
      def load_compressed_object(xref_entry)
        unless @object_stream_data.key?(xref_entry.objstm)
          obj = @document.object(xref_entry.objstm)
          if !obj.respond_to?(:parse_stream)
            raise HexaPDF::MalformedPDFError.new("Object with oid=#{xref_entry.objstm} is not an object stream")
          end
          @object_stream_data[xref_entry.objstm] = obj.parse_stream
        end

        [*@object_stream_data[xref_entry.objstm].object_by_index(xref_entry.pos), xref_entry.gen, nil]
      end

      # Loads a single Revision whose cross-reference section/stream is located at the given position.
      def load_revision(pos)
        xref_section, trailer = if xref_section?(pos)
                                  parse_xref_section_and_trailer(pos)
                                else
                                  obj = load_object(XRefSection.in_use_entry(0, 0, pos))
                                  if !obj.respond_to?(:xref_section)
                                    raise HexaPDF::MalformedPDFError.new("Object is not a cross-reference stream", pos)
                                  end
                                  [obj.xref_section, obj.value]
                                end
        Revision.new(@document.wrap(trailer, type: :Trailer), xref_section: xref_section, parser: self)
      end

      # Looks at the given offset and returns +true+ if there is a cross-reference section at that position.
      def xref_section?(offset)
        @tokenizer.pos = offset + @header_offset
        token = @tokenizer.peek_token
        token.kind_of?(Tokenizer::Token) && token == 'xref'
      end

      # Parses the cross-reference section at the given position and the following trailer and returns
      # them as an array consisting of an XRefSection instance and a hash.
      #
      # This method can only parse cross-reference sections, not cross-reference streams!
      #
      # See: PDF1.7 s7.5.4, s7.5.5; ADB1.7 sH.3-3.4.3
      def parse_xref_section_and_trailer(offset)
        @tokenizer.pos = offset + @header_offset
        token = @tokenizer.parse_token
        unless token.kind_of?(Tokenizer::Token) && token == 'xref'
          raise HexaPDF::MalformedPDFError.new("Xref section doesn't start with keyword xref", @tokenizer.pos)
        end

        xref = XRefSection.new
        start = @tokenizer.parse_token
        while start.kind_of?(Integer)
          number_of_entries = @tokenizer.parse_token
          unless number_of_entries.kind_of?(Integer)
            raise HexaPDF::MalformedPDFError.new("Invalid cross-reference subsection start", @tokenizer.pos)
          end

          @tokenizer.skip_whitespace
          start.upto(start + number_of_entries - 1) do |oid|
            pos, gen, type = @tokenizer.next_xref_entry
            if xref.entry?(oid)
              next
            elsif type == 'n'
              if pos == 0 || gen > 65535
                maybe_raise("Invalid in use cross-reference entry in cross-reference section", pos: @tokenizer.pos)
                xref.add_free_entry(oid, gen)
              else
                xref.add_in_use_entry(oid, gen, pos)
              end
            else
              xref.add_free_entry(oid, gen)
            end
          end
          start = @tokenizer.parse_token
        end

        unless start.kind_of?(Tokenizer::Token) && start == 'trailer'
          raise HexaPDF::MalformedPDFError.new("Trailer doesn't start with keyword trailer", @tokenizer.pos)
        end

        trailer = @tokenizer.parse_object
        unless trailer.kind_of?(Hash)
          raise HexaPDF::MalformedPDFError.new("Trailer is not a dictionary, but a(n) #{trailer.class}", @tokenizer.pos)
        end

        [xref, trailer]
      end

      # Returns the offset of the main cross-reference section/stream.
      #
      # Implementation note: Normally, the %%EOF marker has to be on the last line, however, Adobe
      # viewers relax this restriction and so do we.
      #
      # If strict parsing is disabled, the whole file is searched for the offset.
      #
      # See: PDF1.7 s7.5.5, ADB1.7 sH.3-3.4.4
      def startxref_offset
        @io.seek(0, IO::SEEK_END)
        step_size = 1024
        pos = @io.pos
        eof_not_found = startxref_missing = false

        while pos != 0
          @io.pos = [pos - step_size, 0].max
          pos = @io.pos
          lines = @io.read(step_size + 40).split(/[\r\n]+/)

          eof_index = lines.rindex {|l| l.strip == '%%EOF' }
          (eof_not_found = true; next) unless eof_index
          (startxref_missing = true; next) unless eof_index >= 2 && lines[eof_index - 2].strip == "startxref"

          break # we found the startxref offset
        end

        if eof_not_found
          maybe_raise("PDF file trailer with end-of-file marker not found", pos: pos, force: !eof_index)
        elsif startxref_missing
          maybe_raise("PDF file trailer is missing startxref keyword", pos: pos,
                      force: eof_index < 2 || lines[eof_index - 2].strip != "startxref")
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
        @header_version.to_sym
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

      # Depending on the value of the config option +parser.strict+ raises a
      # HexaPDF::MalformedPDFError with the given message or yields to the block if one is given.
      #
      # If the options +force+ is used, an error is always raised.
      def maybe_raise(msg, pos: nil, force: false)
        if force || @document.config['parser.strict']
          error = HexaPDF::MalformedPDFError.new(msg, pos)
          error.set_backtrace(caller(1))
          raise error
        elsif block_given?
          yield
        end
      end

    end

  end
end
