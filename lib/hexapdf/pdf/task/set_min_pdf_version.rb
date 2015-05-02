# -*- encoding: utf-8 -*-

module HexaPDF
  module PDF
    module Task

      # Task for setting the PDF documents version to at least the minimum version required by the
      # fields of all PDF objects.
      #
      # See: Dictionary.define_field
      module SetMinPDFVersion

        # Executes this task.
        def self.call(doc, **)
          version = process_object(doc.trailer, '1.2')
          doc.each(current: false) {|obj| version = process_object(obj, version)}
          doc.version = version if version > doc.version
        end

        # Determines the minimum version required by the object and returns it or the given version,
        # whichever is higher.
        def self.process_object(obj, version)
          return version unless obj.kind_of?(HexaPDF::PDF::Dictionary)

          obj.class.each_field do |name, field|
            if field.version > version && obj.value.key?(name)
              version = field.version
            end
            if obj.value[name].kind_of?(HexaPDF::PDF::Dictionary) && !obj.indirect?
              version = process_object(obj.value[name], version)
            end
          end
          version
        end

      end

    end
  end
end
