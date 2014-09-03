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

      # The parser used to load the indirect objects.
      attr_reader :parser

      # Create a new cross-reference table. The parser that created this table and is needed to load
      # indirect objects also has to be provided.
      def initialize(parser)
        @parser = parser
        @chained_tables = {}
        @table, @trailer = {}, {}
      end

      # Return the object with the given object and generation numbers.
      #
      # If an object could not be found in this table or any daisy-chained one, +NOT_FOUND+ is
      # returned. If +FREE_ENTRY+ is returned, it means that the object is currently not associated
      # with any value and free for possible re-use (but which shouldn't be done anymore).
      def [](oid, gen = 0)
        data = @table.fetch([oid, gen], NOT_FOUND)

        # PDF1.7 s7.5.5 states that :Prev needs to be indirect, Adobe's reference 3.4.4 says it
        # should be direct. Adobe's POV is followed here. Same with :XRefStm.
        if data == NOT_FOUND && (table = chained_table(:XRefStm))
          data = table[oid, gen]
        end
        if data == NOT_FOUND && (table = chained_table(:Prev))
          data = table[oid, gen]
        end

        if data != FREE_ENTRY && data != NOT_FOUND
          data = @parser.parse_indirect_object(data)
        end

        data
      end

      # Assign the byte position where the object resides or +FREE_ENTRY+ for the object with the
      # given object and generation numbers.
      #
      # This should not be called by any class other than Parser!
      def []=(oid, gen = 0, data)
        @table[[oid, gen]] = data
      end

      # Return the object if it is a direcct one, or resolve the given Reference.
      def deref(obj)
        obj.kind_of?(Reference) ? self[obj.oid, obj.gen] : obj
      end

      private

      # Return the chained table of the given +type+ which may either be :XRefStm or :Prev.
      def chained_table(type)
        if !@chained_tables.has_key?(type)
          value = @trailer[type]
          @chained_tables[type] = value.kind_of?(Integer) ? @parser.parse_xref(value) : nil
        end
        @chained_tables[type]
      end

    end

  end
end
