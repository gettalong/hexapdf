# -*- encoding: utf-8 -*-

require 'hexapdf/error'

module HexaPDF
  module PDF

    # Encapsulates functionality that is needed for Reference like classes.
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
      # If the other object is not the same kind, returns +nil+. Otherwise references are ordered
      # first by object number and then by generation number.
      def <=>(other)
        return nil unless other.kind_of?(ReferenceBehavior)
        (oid == other.oid ? gen <=> other.gen : oid <=> other.oid)
      end

      # Returns +true+ if the other object references the same PDF object as this reference object.
      def ==(other)
        other.respond_to?(:oid) && oid == other.oid && other.respond_to?(:gen) && gen == other.gen
      end
      alias_method :eql?, :'=='

      def hash #:nodoc:
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
