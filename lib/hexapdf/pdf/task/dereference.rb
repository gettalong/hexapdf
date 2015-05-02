# -*- encoding: utf-8 -*-

module HexaPDF
  module PDF
    module Task

      # Task for recursively dereferencing a single object or the reachable parts of the whole PDF
      # document. Dereferencing means that the references are replaced with the actual objects.
      #
      # Running this task is most often done to prepare for other steps in a PDF transformation
      # process.
      module Dereference

        # Recursively dereferences the reachable parts of the document and returns an array of
        # objects that are never referenced. This includes indirect objects that are used as values
        # for the /Length entry of a stream.
        #
        # If the optional argument +object+ is provided, only the given object is dereferenced and
        # nothing is returned.
        def self.call(doc, object: nil)
          if object
            dereference(doc, object)
            nil
          else
            visited = {}
            dereference(doc, doc.trailer, visited)
            doc.each(current: false).with_object([]) do |obj, unused|
              if !visited.key?(obj) && obj.type != :ObjStm && obj.type != :XRef
                unused << obj
              elsif obj.kind_of?(HexaPDF::PDF::Stream) && (val = obj.value[:Length]) &&
                  val.kind_of?(HexaPDF::PDF::Object) && val.indirect?
                unused << val
              end
            end
          end
        end

        # Dereferences a single PDF object.
        def self.dereference(doc, object, done = {})
          return object if done.key?(object)
          done[object] = true

          recurse = lambda do |val|
            case val
            when Hash
              val.each do |k, v|
                val[k] = recurse.call(v)
              end
            when Array
              val.map! {|v| recurse.call(v)}
            when HexaPDF::PDF::Reference
              dereference(doc, doc.object(val), done)
            when HexaPDF::PDF::Object
              (val.indirect? ? dereference(doc, val, done) : recurse.call(val.value))
            else
              val
            end
          end

          object.value = recurse.call(object.value)
          object
        end

      end

    end
  end
end
