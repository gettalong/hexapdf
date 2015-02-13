# -*- encoding: utf-8 -*-

require 'hexapdf/pdf/reference'
require 'hexapdf/error'

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
    # A PDF object *should* be connected to a PDF document, otherwise some methods may not work.
    #
    # Most PDF objects in a PDF document are represented by sub classes of this class that provide
    # additional functionality.
    #
    # See: Stream, Reference, Document
    # See: PDF1.7 s7.3.10, s7.3.8
    class Object

      include ReferenceBehavior

      # The wrapped object.
      attr_reader :value

      # Sets the associated PDF document.
      attr_writer :document

      # Creates a new PDF object for +value+.
      def initialize(value, document: nil, oid: 0, gen: 0)
        @value = value
        @document = document
        self.oid = oid
        self.gen = gen
      end

      # Returns the associated PDF document.
      #
      # If no document is associated, an error is raised.
      def document
        @document || raise(HexaPDF::Error, "No document is associated with this object (#{inspect})")
      end

      # Returns +true+ if a PDF document is associated.
      def document?
        !@document.nil?
      end

      # Returns +true+ if the object represents a PDF null object.
      def null?
        @value.nil?
      end

      def inspect #:nodoc:
        "#<#{self.class.name} [#{oid}, #{gen}] value=#{value.inspect}>"
      end

      private

      # Returns the configuration object of the PDF document.
      def config
        document.config
      end

    end

  end
end
