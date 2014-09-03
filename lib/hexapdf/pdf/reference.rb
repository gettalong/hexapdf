# -*- encoding: utf-8 -*-

module HexaPDF
  module PDF

    # A reference to an indirect object.
    #
    # The PDF syntax allows for references to existing and non-existing indirect objects. Such
    # references are represented with objects of this class.
    #
    # See: PDF1.7 s7.3.10
    class Reference

      # The object number of the referenced indirect object.
      attr_reader :object_number
      alias_method :oid, :object_number

      # The generation number of the referenced indirect object.
      attr_reader :generation_number
      alias_method :gen, :generation_number

      # Create a new reference for the given object and generation numbers.
      def initialize(object_number, generation_number = 0)
        @object_number, @generation_number = object_number, generation_number
        unless @object_number.kind_of?(Integer) && @generation_number.kind_of?(Integer)
          raise ArgumentError, "Method arguments need to be integers"
        end
      end

      # Return +true+ if the other object references the same PDF object as this reference object.
      def ==(other)
        other.kind_of?(self.class) && @object_number == other.object_number &&
          @generation_number == other.generation_number
      end
      alias_method :eql?, :'=='

      def hash #:nodoc:
        [@object_number, @generation_number].hash
      end

    end

  end
end
