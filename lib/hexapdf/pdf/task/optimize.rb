# -*- encoding: utf-8 -*-

module HexaPDF
  module PDF
    module Task

      # Task for optimizing the PDF document.
      #
      # For a list of optimization methods this task can perform have a look at the ::call method.
      module Optimize

        # Executes this task.
        #
        # The following optimization methods are performed if they are set to +true+:
        #
        # delete_fields_with_defaults::
        #   Deletes field entries that are optional and set to their default value.
        def self.call(doc, delete_fields_with_defaults: true)
          doc.each(current: false) do |obj, rev|
            next unless obj.kind_of?(HexaPDF::PDF::Dictionary)
            obj.each do |name, value|
              if (delete_fields_with_defaults && (field = obj.class.field(name)) &&
                  !field.required? && field.default? && value == field.default)
                obj.value.delete(name)
              end
            end
          end
        end

      end

    end
  end
end
