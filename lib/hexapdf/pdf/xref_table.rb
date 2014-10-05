# -*- encoding: utf-8 -*-

require 'hexapdf/pdf/utils/object_hash'

module HexaPDF
  module PDF

    # Manages the indirect objects of one cross-reference table or stream.
    #
    # A PDF file can have more than one cross-reference table or stream which are all daisy-chained
    # together. This allows later tables to override entries in prior ones. This is automatically
    # and transparently done by HexaPDF.
    #
    # Note that a cross-reference table may contain a single object number only once.
    #
    # See: Revision
    # See: PDF1.7 s7.5.4, s7.5.8
    class XRefTable < Utils::ObjectHash

      # One entry of a cross-reference table or stream.
      #
      # An entry has the attributes +type+, +pos+ and +objstm+ and can be created like this:
      #
      #   Entry.new(type, pos, objstm)   -> entry
      #
      # The +type+ attribute can be:
      #
      # :free:: Denotes a free entry.
      #
      # :used:: A used entry that resides in the body of the PDF file. The +pos+ attribute defines
      #         the position in the file at which the object can be found.
      #
      # :compressed:: A used entry that resides in an object stream. The +objstm+ attribute contains
      #               the object stream in which the object can be found and the +pos+ attribute
      #               contains the index into the object stream.
      #
      # See: PDF1.7 s7.5.4, s7.5.8
      Entry = Struct.new(:type, :pos, :objstm)

      # Represents a free entry in the cross-reference table.
      FREE_ENTRY = Entry.new(:free)

      # Create a cross-reference entry. See Entry for details on the parameters.
      def self.entry(type, pos: nil, objstm: nil)
        if type == :free
          FREE_ENTRY
        else
          Entry.new(type, pos, objstm)
        end
      end

    end

  end
end
