# -*- encoding: utf-8 -*-

module HexaPDF
  module PDF
    module Task

      # Task for recursively dereferencing a single object or the reachable parts of the whole PDF
      # document. Dereferencing means that the references are replaced with the actual objects.
      #
      # Running this task is most often done to prepare for other steps in a PDF transformation
      # process.
      class Dereference

        # Recursively dereferences the reachable parts of the document and returns an array of
        # objects that are never referenced. This includes indirect objects that are used as values
        # for the /Length entry of a stream.
        #
        # If the optional argument +object+ is provided, only the given object is dereferenced and
        # nothing is returned.
        def self.call(doc, object: nil)
          new(doc, object).result
        end

        attr_reader :result # :nodoc:

        def initialize(doc, object = nil) #:nodoc:
          @doc = doc
          @object = object
          @seen = {}
          @result = nil
          execute
        end

        private

        def execute #:nodoc:
          if @object
            dereference(@object)
          else
            dereference(@doc.trailer)
            @result = []
            @doc.each(current: false) do |obj|
              if !@seen.key?(obj) && obj.type != :ObjStm && obj.type != :XRef
                @result << obj
              elsif obj.kind_of?(HexaPDF::PDF::Stream) && (val = obj.value[:Length]) &&
                  val.kind_of?(HexaPDF::PDF::Object) && val.indirect?
                @result << val
              end
            end
          end
        end

        def dereference(object) #:nodoc:
          return object if @seen.key?(object)
          @seen[object] = true
          recurse(object.value)
          object
        end

        def recurse(val) #:nodoc:
          case val
          when Hash
            val.each {|k, v| val[k] = recurse(v)}
          when Array
            val.map! {|v| recurse(v)}
          when HexaPDF::PDF::Reference
            dereference(@doc.object(val))
          when HexaPDF::PDF::Object
            (val.indirect? ? dereference(val) : recurse(val.value))
            val
          else
            val
          end
        end

      end

    end
  end
end
