# -*- encoding: utf-8 -*-

require 'hexapdf/error'

module HexaPDF
  module PDF

    # Encapsulates functionality that is needed for Reference like classes.
    #
    # Anywhere where the functionality of this mix-in module is needed, i.e. anywhere where a
    # ReferenceBehavior can be passed, a custom class can be used provided it responds to +oid+ and
    # conforms to the mix-in spec.
    #
    # See: Reference, HexaPDF::PDF::Object
    module ReferenceBehavior

      include Comparable

      # Returns the object number of the referenced indirect object.
      def oid
        @_oid ||= 0
      end

      # Sets the object number.
      def oid=(oid)
        unless oid.kind_of?(Integer)
          raise HexaPDF::Error, "PDF reference oid needs to be an Integer"
        end
        @_oid = oid
      end

      # Returns the generation number of the referenced indirect object.
      def gen
        @_gen ||= 0
      end

      # Sets the generation number.
      def gen=(gen)
        unless gen.kind_of?(Integer)
          raise HexaPDF::Error, "PDF reference gen needs to be an Integer"
        end
        @_gen = gen
      end

      # Compares the ReferenceBehavior object to the other object.
      #
      # If the other object does not respond to +oid+ or +gen+, +nil+ is returned. Otherwise
      # references are ordered first by object number and then by generation number.
      def <=>(other)
        return nil unless other.respond_to?(:oid) && other.respond_to?(:gen)
        (oid == other.oid ? gen <=> other.gen : oid <=> other.oid)
      end

      # Returns +true+ if the other object references the same PDF object as this reference object.
      def ==(other)
        other.respond_to?(:oid) && oid == other.oid && other.respond_to?(:gen) && gen == other.gen
      end
      alias_method :eql?, :'=='

      # Computes the hash value based on the object and generation numbers.
      def hash
        [oid, gen].hash
      end

    end

    # A reference to an indirect object.
    #
    # The PDF syntax allows for references to existing and non-existing indirect objects. Such
    # references are represented with objects of this class.
    #
    # Note that after initialization changing the object or generation numbers is not possible
    # anymore!
    #
    # See: PDF1.7 s7.3.10
    class Reference

      include ReferenceBehavior
      private(:oid=, :gen=)

      # Creates a new Reference with the given object number and, optionally, generation number.
      def initialize(oid, gen = 0)
        self.oid = oid
        self.gen = gen
      end

      def inspect #:nodoc:
        "#<#{self.class.name} [#{oid}, #{gen}]>"
      end

    end

  end
end
