# -*- encoding: utf-8 -*-

require 'hexapdf/error'

module HexaPDF
  module PDF

    # Encapsulates functionality that is needed for Reference like classes.
    #
    # See: Reference, HexaPDF::PDF::Object
    module ReferenceBehavior

      # The object number of the referenced indirect object.
      attr_reader :oid

      # The generation number of the referenced indirect object.
      attr_reader :gen

      # Create a new reference for the given object and generation numbers.
      def initialize(oid, gen = 0)
        @oid = oid
        @gen = gen
        unless @oid.kind_of?(Integer) && @gen.kind_of?(Integer)
          raise HexaPDF::Error, "PDF reference oid,gen arguments need to be integers"
        end
      end

      # Return +true+ if the other object references the same PDF object as this reference object.
      def ==(other)
        other.respond_to?(:oid) && @oid == other.oid && other.respond_to?(:gen) && @gen == other.gen
      end
      alias_method :eql?, :'=='

      def hash #:nodoc:
        [@oid, @gen].hash
      end

    end

    # A reference to an indirect object.
    #
    # The PDF syntax allows for references to existing and non-existing indirect objects. Such
    # references are represented with objects of this class.
    #
    # See: PDF1.7 s7.3.10
    class Reference
      include ReferenceBehavior

      def inspect #:nodoc:
        "#<#{self.class.name} [#{oid}, #{gen}]>"
      end

    end

  end
end
