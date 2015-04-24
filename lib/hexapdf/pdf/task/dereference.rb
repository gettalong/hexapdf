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
        # objects that are never referenced.
        #
        # If the optional argument +object+ is provided, only the given object is dereferenced and
        # nothing is returned.
        def self.call(doc, object: nil)
          if object
            dereference(doc, object)
            nil
          else
            done = {}
            dereference(doc, doc.trailer, done)
            doc.each(current: false).with_object([]) do |obj, unused|
              unused << obj unless done.key?(obj) || obj.type == :ObjStm || obj.type == :XRef
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
              (val.oid == 0 ? recurse.call(val.value) : dereference(doc, val, done))
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
