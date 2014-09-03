# -*- encoding: utf-8 -*-

require 'hexapdf/pdf/reference'

module HexaPDF
  module PDF

    # Indirect objects of the PDF object system.
    #
    # == Overview
    #
    # An indirect object in PDF is like a normal object but with an additional *object identifier*
    # consisting of an object number and a generation number. This object identifier uniquely
    # identifies the object and can be used for referencing it (from possibly multiple places).
    #
    # == Stream Objects
    #
    # In addition to the wrapped object itself (#value), a Stream may also be associated with an
    # indirect object, but only if the value is a PDF dictionary (a Hash in this implementation).
    # This associated dictionary further describes the stream, like its length or how it is encoded.
    #
    # Such a stream object in PDF contains string data but of possibly unlimited length. Therefore
    # it is used for large amounts of data like images, page descriptions or embedded files.
    #
    # See: Reference
    # See: PDF1.7 s7.3.10, s7.3.8
    class IndirectObject < Reference

      # The wrapped object.
      attr_reader :value

      # Create a new indirect object for +value+.
      def initialize(value, object_number, generation_number = 0, stream = nil)
        super(object_number, generation_number)
        @value = value
      end

    end

  end
end
