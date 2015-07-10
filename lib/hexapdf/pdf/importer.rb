# -*- encoding: utf-8 -*-

require 'hexapdf/error'
require 'weakref'

module HexaPDF
  module PDF

    # The Importer class manages the process of copying objects from one Document to another.
    #
    # It may seem unnecessary using an importer containing state for the task. However, by retaining
    # some information about the already copied objects we can make sure that already imported
    # objects don't get imported again.
    #
    # Two types of indirect objects are *never* imported from one document to another: the catalog
    # and page tree nodes. If the catalog was imported, the whole source document would be imported.
    # And if one page tree node would imported, the whole page tree would be imported.
    #
    # See: Document#import
    class Importer

      class NullableWeakRef < WeakRef #:nodoc:
        def __getobj__ #:nodoc:
          super rescue nil
        end
      end

      # Returns the Importer object for copying objects from the +source+ to the +destination+
      # document.
      def self.for(source:, destination:)
        @map ||= {}
        @map.keep_if {|_, v| v.source.weakref_alive? && v.destination.weakref_alive?}
        source = NullableWeakRef.new(source)
        destination = NullableWeakRef.new(destination)
        @map[[source.hash, destination.hash]] ||= new(source: source, destination: destination)
      end

      private_class_method :new

      attr_reader :source, :destination #:nodoc:

      # Initializes a new importer that can import objects from the +source+ document to the
      # +destination+ document.
      def initialize(source:, destination:)
        @source = source
        @destination = destination
        @mapper = {}
      end

      # Imports the given +object+ from the source to the destination object and returns the
      # imported object.
      #
      # Note: Indirect objects are automatically added to the destination document but direct or
      # simple objects are not.
      #
      # An error is raised if the object doesn't belong to the +source+ document.
      def import(object)
        mapped_object = @mapper[object.data] if object.kind_of?(HexaPDF::PDF::Object)
        if object.kind_of?(HexaPDF::PDF::Object) && object.document? && @source != object.document
          raise HexaPDF::Error, "Import error: Incorrect document object for importer"
        elsif mapped_object && mapped_object == @destination.object(mapped_object)
          mapped_object
        else
          duplicate(object)
        end
      end

      private

      # Recursively duplicates the object.
      #
      # PDF objects are automatically added to the destination document if they are indirect objects
      # in the source document.
      def duplicate(object)
        case object
        when Hash
          object.each_with_object({}) do |(k, v), obj|
            obj[k] = duplicate(v)
          end
        when Array
          object.map {|v| duplicate(v)}
        when HexaPDF::PDF::Reference
          import(@source.object(object))
        when HexaPDF::PDF::Object
          if object.type == :Catalog || object.type == :Pages
            @mapper[object.data] = nil
          else
            obj = @mapper[object.data] = object.dup
            obj.document = @destination
            obj.instance_variable_set(:@data, obj.data.dup)
            obj.data.oid = 0
            obj.data.gen = 0
            @destination.add(obj) if object.indirect?

            obj.data.stream = obj.data.stream.dup if obj.data.stream.kind_of?(String)
            obj.data.value = duplicate(obj.data.value)
            obj
          end
        when String
          object.dup
        else
          object
        end
      end

    end

  end
end
