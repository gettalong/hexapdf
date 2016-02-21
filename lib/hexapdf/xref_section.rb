# -*- encoding: utf-8 -*-

require 'hexapdf/pdf/utils/object_hash'

module HexaPDF

  # Manages the indirect objects of one cross-reference section or stream.
  #
  # A PDF file can have more than one cross-reference section or stream which are all
  # daisy-chained together. This allows later sections to override entries in prior ones. This is
  # automatically and transparently done by HexaPDF.
  #
  # Note that a cross-reference section may contain a single object number only once.
  #
  # See: Revision
  # See: PDF1.7 s7.5.4, s7.5.8
  class XRefSection < HexaPDF::PDF::Utils::ObjectHash

    # One entry of a cross-reference section or stream.
    #
    # An entry has the attributes +type+, +oid+, +gen+, +pos+ and +objstm+ and can be created like
    # this:
    #
    #   Entry.new(type, oid, gen, pos, objstm)   -> entry
    #
    # The +type+ attribute can be:
    #
    # :free:: Denotes a free entry.
    #
    # :in_use:: A used entry that resides in the body of the PDF file. The +pos+ attribute defines
    #           the position in the file at which the object can be found.
    #
    # :compressed:: A used entry that resides in an object stream. The +objstm+ attribute contains
    #               the reference to the object stream in which the object can be found and the
    #               +pos+ attribute contains the index into the object stream.
    #
    #               Objects in an object stream always have a generation number of 0!
    #
    # See: PDF1.7 s7.5.4, s7.5.8
    Entry = Struct.new(:type, :oid, :gen, :pos, :objstm) do
      def free?
        type == :free
      end

      def in_use?
        type == :in_use
      end

      def compressed?
        type == :compressed
      end
    end

    # Creates an in-use cross-reference entry. See Entry for details on the arguments.
    def self.in_use_entry(oid, gen, pos)
      Entry.new(:in_use, oid, gen, pos)
    end

    # Creates a free cross-reference entry. See Entry for details on the arguments.
    def self.free_entry(oid, gen)
      Entry.new(:free, oid, gen)
    end

    # Creates a compressed cross-reference entry. See Entry for details on the arguments.
    def self.compressed_entry(oid, objstm, pos)
      Entry.new(:compressed, oid, 0, pos, objstm)
    end

    # Make the assignment method private so that only the provided convenience methods can be
    # used.
    private :"[]="

    # Adds an in-use entry to the cross-reference section.
    #
    # See: ::in_use_entry
    def add_in_use_entry(oid, gen, pos)
      self[oid, gen] = self.class.in_use_entry(oid, gen, pos)
    end

    # Adds a free entry to the cross-reference section.
    #
    # See: ::free_entry
    def add_free_entry(oid, gen)
      self[oid, gen] = self.class.free_entry(oid, gen)
    end

    # Adds a compressed entry to the cross-reference section.
    #
    # See: ::compressed_entry
    def add_compressed_entry(oid, objstm, pos)
      self[oid, 0] = self.class.compressed_entry(oid, objstm, pos)
    end

    # :call-seq:
    #   xref_section.each_subsection {|sub| block }   -> xref_section
    #   xref_section.each_subsection                  -> Enumerator
    #
    # Calls the given block once for every subsection of this cross-reference section. Each
    # yielded subsection is a sorted array of cross-reference entries.
    #
    # If this section contains no objects, a single empty array is yielded (corresponding to a
    # subsection with zero elements).
    #
    # The subsections are dynamically generated based on the object numbers in this section.
    def each_subsection
      return to_enum(__method__) unless block_given?

      temp = []
      oids.sort.each do |oid|
        if !temp.empty? && temp[-1].oid + 1 != oid
          yield(temp)
          temp = []
        end
        temp << self[oid]
      end
      yield(temp)
      self
    end

  end

end
