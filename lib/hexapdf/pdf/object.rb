# -*- encoding: utf-8 -*-

require 'hexapdf/pdf/reference'

module HexaPDF
  module PDF

    # Objects of the PDF object system.
    #
    # == Overview
    #
    # A PDF object is like a normal object but with an additional *object identifier* consisting of
    # an object number and a generation number. If the object number is zero, then the PDF object
    # represents a direct object. Otherwise the object identifier uniquely identifies this object as
    # an indirect object and can be used for referencing it (from possibly multiple places).
    #
    # A PDF object is always connected to a PDF document, it cannot stand alone.
    #
    # Most PDF objects in a PDF document are represented by sub classes of this class that provide
    # additional functionality.
    #
    # == Stream Objects
    #
    # In addition to the wrapped object itself (#value), a Stream may also be associated with a PDF
    # object, but only if the value is a PDF dictionary (a Hash in the HexaPDF implementation). This
    # associated dictionary further describes the stream, like its length or how it is encoded.
    #
    # Such a stream object in PDF contains string data but of possibly unlimited length. Therefore
    # it is used for large amounts of data like images, page descriptions or embedded files.
    #
    # See: Reference, Document
    # See: PDF1.7 s7.3.10, s7.3.8
    class Object

      include ReferenceBehavior

      # The associated document.
      attr_reader :document

      # The wrapped object.
      attr_reader :value

      # The associated stream, if any.
      attr_accessor :stream


      # Create a new PDF object for +value+ that is associated with the given document.
      def initialize(document, value, oid = 0, gen = 0, stream = nil)
        super(oid, gen)
        @document = document
        @value = value
        @stream = stream
      end

      # Make this PDF object an indirect one by assigning it the given new object and generation
      # numbers.
      #
      # This method only works if the current object number is zero, i.e. if the object is not
      # already an indirect object.
      def make_indirect(new_oid, new_gen = 0)
        raise "Can't change the object or generation numbers of an indirect object" if oid != 0 #TODO e.msg
        @oid = new_oid
        @gen = new_gen
      end

    end

  end
end
