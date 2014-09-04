# -*- encoding: utf-8 -*-

module HexaPDF
  module PDF

    # Manages the indirect objects of one cross-reference table or stream as well as the associated
    # trailer.
    #
    # A PDF file can have more than one cross-reference table or stream which are all daisy-chained
    # together. This allows later tables to override entries in prior ones. This is automatically
    # and transparently done.
    #
    # See: PDF1.7 s7.5.4, s7.5.8
    class XRefTable

      # The value if a requested object could not be found.
      NOT_FOUND = Object.new

      # Represents a free entry in the cross-reference table.
      FREE_ENTRY = Object.new

      # The trailer dictionary associated with this cross-reference table.
      attr_accessor :trailer

      # Create a new cross-reference table.
      def initialize
        @table, @trailer = {}, {}
      end

      # Return information for loading the object with the given object and generation numbers.
      #
      # The returned data is either an integer specifying the byte position in the PDF file where
      # the indirect object resides or an array of type [Reference, Integer] specifying the index
      # into the object stream.
      #
      # If an object could not be found in this table, +NOT_FOUND+ is returned. If +FREE_ENTRY+ is
      # returned, it means that the object is currently not associated with any value and free for
      # possible re-use (but which shouldn't be done anymore).
      def [](oid, gen = 0)
        @table.fetch([oid, gen], NOT_FOUND)
      end

      # Assign the byte position where the object resides or +FREE_ENTRY+ for the object with the
      # given object and generation numbers.
      #
      # This should not be called by any class other than Parser!
      def []=(oid, gen = 0, data)
        @table[[oid, gen]] = data
      end

    end

  end
end
