# -*- encoding: utf-8 -*-

require 'hexapdf/error'
require 'hexapdf/pdf/reference'
require 'hexapdf/pdf/pdf_object'
require 'hexapdf/pdf/xref_table'

module HexaPDF
  module PDF

    # Handles loaded or added objects of one PDF file.
    class ObjectStore

      # Create a new object store.
      #
      # If a Parser is provided, then this object store can read PDF objects from an existing PDF,
      # otherwise it only contains created PDF objects.
      def initialize(document, parser = nil)
        @document = document
        @parser = parser
        @objects = {}

        @xref_tables = []
        @loaded_xref_tables = {}
        if parser
          @xref_tables << load_xref_table(@parser.startxref_offset)
        end

        @next_oid = @xref_tables.first && @xref_tables.first.trailer[:Size] || 1
      end

      # Return the indirect object for the given reference or for the given object and generation
      # numbers.
      #
      # For references to unknown or free objects, +nil+ is returned.
      #
      # See: Reference, IndirectObject
      # See: PDF1.7 s7.3.9
      def [](ref, gen = 0)
        ref = Reference.new(ref, gen) if !ref.kind_of?(Reference)

        if @objects.has_key?(ref)
          @objects[ref]
        elsif (data = xref_entry(oid, gen))
          if data != XRefTable::FREE_ENTRY && data != XRefTable::NOT_FOUND
            @objects[ref] = load_object(oid, gen, data)
          else
            nil
          end
        else
          nil
        end
      end

      # Dereference the given object.
      #
      # Return the object itself if it is a direct object, or the dereferenced indirect object.
      def deref(obj)
        obj.kind_of?(Reference) ? self[obj] : obj
      end

      # Create an indirect object from the given one.
      def ref(obj)
        if obj.kind_of?(PDFObject) && obj.oid == 0
          obj.make_indirect(@next_oid, 0)
          @objects[Reference.new(obj.oid, obj.gen)] = obj
          @next_oid += 1
        elsif !obj.kind_of?(PDFObject)
          obj = @document.wrap_object(obj, @next_oid)
          @objects[Reference.new(obj.oid, obj.gen)] = obj
          @next_oid += 1
        end
        obj
      end

      # Wrap the given object inside a PDFObject class.
      #
      # This allows one to use convenience functions to work with the object.
      def wrap_object(obj, oid = 0, gen = 0, stream = nil)
        PDFObject.new(self, obj, oid, gen, stream) #TODO: select subclass based on Type and possibly SubType
      end

      private

      # Return the data necessary from the cross-reference tables to load the object with the given
      # object and generation numbers.
      def xref_entry(oid, gen)
        i = 0
        result = XRefTable::NOT_FOUND
        while i < @xref_tables.length
          result = @xref_tables[i][oid, gen]
          break if result != NOT_FOUND

          load_xref_tables(i) if !@loaded_xref_tables[@xref_tables[i]]
          i += 1
        end

        result
      end

      # Load the dependent cross-reference tables for the cross-reference table at position +i+ in
      # the list of loaded tables.
      def load_xref_tables(i)
        # PDF1.7 s7.5.5 states that :Prev needs to be indirect, Adobe's reference 3.4.4 says it
        # should be direct. Adobe's POV is followed here. Same with :XRefStm.
        xrefstm = @xref_tables[i].trailer[:XRefStm]
        prev = @xref_tables[i].trailer[:Prev]
        tables = [(load_xref_table(xrefstm) if xrefstm),
                  (load_xref_table(pref) if prev)].compact
        @xref_tables.insert(i + 1, *tables)
        @loaded_xref_tables[@xref_tables[i]] = true
      end

      # Load a single cross-reference table located at the given position.
      def load_xref_table(pos)
        if @parser.xref_table?(pos)
          @parser.parse_xref_table(pos)
        else
          obj = wrap(*@parser.parse_indirect_object(pos))
          if obj[:Type] != :XRef
            raise MalformedPDFError.new("Object is not a cross-reference stream", pos)
          end
          obj.parse_xref_table
        end
      end

      # Load an indirect object via the associated Parser.
      #
      # For information about the +data+ parameter, have a look at XRefTable#[].
      def load_object(oid, gen, data)
        if data.kind_of?(Integer)
          wrap(*@parser.parse_indirect_object(data))
        else
          raise "not implemented" #TODO: object streams!
        end
      end

    end

  end
end
