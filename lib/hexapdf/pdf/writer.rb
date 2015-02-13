# -*- encoding: utf-8 -*-

require 'hexapdf/error'
require 'hexapdf/pdf/serializer'
require 'hexapdf/pdf/xref_section'

module HexaPDF
  module PDF

    # Writes the contents of a PDF document to an IO stream.
    class Writer

      def initialize(document, io)
        @document = document
        @io = io

        @io.binmode
        @io.seek(0, IO::SEEK_SET) #TODO: incremental update!

        @serializer = Serializer.new
      end

      def write
        write_file_header

        pos = nil
        @document.revisions.reverse_each do |rev|
          pos = write_revision(rev, pos)
        end
      end

      private

      def write_file_header
        #TODO: Need some method to calculate pdf version
        @io << "%PDF-1.7\n%\xCF\xEC\xFF\xE8\xD7\xCB\xCD\n"
      end

      def write_revision(rev, previous_xref_pos = nil)
        xref_section = XRefSection.new

        rev.each do |obj|
          if obj.null?
            xref_section.add_free_entry(obj.oid, obj.gen)
          else
            xref_section.add_in_use_entry(obj.oid, obj.gen, @io.pos)
            write_indirect_object(obj)
          end
        end

        start_xref = @io.pos
        write_xref_section(xref_section)

        trailer = rev.trailer.value.dup
        if previous_xref_pos
          trailer[:Prev] = previous_xref_pos
        else
          trailer.delete(:Prev)
        end
        write_trailer(trailer, start_xref)

        start_xref
      end

      def write_indirect_object(obj)
        @io << "#{obj.oid} #{obj.gen} obj\n"
        write_object(obj)
        @io << "\nendobj\n"
      end

      def write_object(obj)
        if obj.kind_of?(HexaPDF::PDF::Stream)
          data = Filter.string_from_source(obj.stream_encoder)
          obj.value[:Length] = data.size
        end

        @io << @serializer.serialize(obj)

        if obj.kind_of?(HexaPDF::PDF::Stream)
          @io << "stream\n"
          @io << data
          @io << "\nendstream"
        end
      end

      def write_xref_section(xref_section)
        @io << "xref\n"
        xref_section.each_subsection do |entries|
          @io << "#{entries.empty? ? 0 : entries.first.oid} #{entries.size}\n"
          entries.each do |entry|
            if entry.in_use?
              @io << "%010d %05d n \n" % [entry.pos, entry.gen]
            elsif entry.free?
              @io << "0000000000 65535 f \n"
            else
              raise HexaPDF::Error, "Cannot use xref type #{entry.type} in cross-reference section"
            end
          end
        end
      end

      def write_trailer(trailer, start_xref)
        @io << "trailer\n#{@serializer.serialize(trailer)}\n"
        @io << "startxref\n#{start_xref}\n%%EOF\n"
      end

    end

  end
end
