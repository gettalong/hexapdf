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
    # Note that a cross-reference table may contain a single object number only once.
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
        @oids = {}
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

      # Set the loading information for the object with the given object and generation numbers.
      #
      # If an entry with a given object number already exists, another entry is not added as per
      # Adobe's implementation notes.
      #
      # The +data+ parameter can either be an integer pointing to the byte position of the object,
      # an array of type [Reference, Integer] specifying the index of the object inside an object
      # stream, or +FREE_ENTRY+ for a free cross-reference entry.
      #
      # See: ADB1.7 sH.3-3.4.3
      def []=(oid, gen = 0, data)
        unless has_entry?(oid)
          @oids[oid] = true
          @table[[oid, gen]] = data
        end
      end

      # Return +true+ if the table has an entry for the given object number.
      #
      # Note: A single table may only contain information on objects with unique object numbers!
      def has_entry?(oid)
        @oids.has_key?(oid)
      end

    end

  end
end
