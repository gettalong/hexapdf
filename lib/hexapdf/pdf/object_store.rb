# -*- encoding: utf-8 -*-

require 'hexapdf/pdf/reference'
require 'hexapdf/pdf/xref_table'

module HexaPDF
  module PDF

    # Handles loaded or added objects of one PDF file.
    class ObjectStore

      # Create a new object store.
      #
      # If a cross-reference table object (XRefTable) is provided, then this object store can read
      # PDF objects from an existing PDF, otherwise it only contains created PDF objects.
      def initialize(document, xref_table = nil)
        @document = document
        @objects = {}
        @xref_table = xref_table
        @next_oid = @xref_table && @xref_table.trailer[:Size] || 1
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
        elsif @xref_table
          obj = @xref_table[ref.oid, ref.gen]
          if obj != XRefTable::FREE_ENTRY && obj != XRefTable::NOT_FOUND
            @objects[ref] = obj
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

    end

  end
end
