# -*- encoding: utf-8 -*-

require 'hexapdf/error'

module HexaPDF
  module PDF

    # A reference to an indirect object.
    #
    # The PDF syntax allows for references to existing and non-existing indirect objects. Such
    # references are represented with objects of this class.
    #
    # Note that after initialization changing the object or generation numbers is not possible
    # anymore!
    #
    # The methods #hash and #eql? are implemented so that objects of this class can be used as hash
    # keys. Furthermore the implementation is compatible to the one of Object, i.e. the hash of a
    # Reference object is the same as the hash of an indirect Object.
    #
    # See: PDF1.7 s7.3.10, Object
    class Reference

      include Comparable

      # Returns the object number of the referenced indirect object.
      attr_reader :oid

      # Returns the generation number of the referenced indirect object.
      attr_reader :gen

      # Creates a new Reference with the given object number and, optionally, generation number.
      def initialize(oid, gen = 0)
        @oid = Integer(oid)
        @gen = Integer(gen)
      end

      # Compares this object to another object.
      #
      # If the other object does not respond to +oid+ or +gen+, +nil+ is returned. Otherwise objects
      # are ordered first by object number and then by generation number.
      def <=>(other)
        return nil unless other.respond_to?(:oid) && other.respond_to?(:gen)
        (oid == other.oid ? gen <=> other.gen : oid <=> other.oid)
      end

      # Returns +true+ if the other object is a Reference and has the same object and generation
      # numbers.
      def ==(other)
        Reference === other && oid == other.oid && gen == other.gen
      end

      # Returns +true+ if the other object references the same PDF object as this reference object.
      def eql?(other)
        other.respond_to?(:oid) && oid == other.oid && other.respond_to?(:gen) && gen == other.gen
      end

      # Computes the hash value based on the object and generation numbers.
      def hash
        oid.hash ^ gen.hash
      end

      def inspect #:nodoc:
        "#<#{self.class.name} [#{oid}, #{gen}]>"
      end

    end

  end
end
