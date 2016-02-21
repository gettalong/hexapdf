# -*- encoding: utf-8 -*-

module HexaPDF
  module Task

    # Task for validating the document.
    #
    # All indirect objects as well as the trailer dictionary are validated and corrected if
    # possible. Furthermore it is checked that the encryption dictionary has not been changed
    # without telling the security handler.
    module Validate

      # Validates all objects of the document with auto-correction on and returns +true+ if
      # everything is fine.
      #
      # If a block is given, it is called on validation problems. See Object#validate for more
      # information.
      def self.call(doc, **, &block)
        result = true
        result &&= doc.trailer.validate(auto_correct: true, &block)
        doc.each(current: false) do |obj|
          result &&= obj.validate(auto_correct: true, &block)
        end
        if doc.encrypted? && !doc.security_handler.encryption_key_valid?
          block.call("Encryption key doesn't match encryption dictionary", false)
          result = false
        end
        result
      end

    end

  end
end
