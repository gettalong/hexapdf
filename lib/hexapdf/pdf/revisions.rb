# -*- encoding: utf-8 -*-

require 'hexapdf/error'
require 'hexapdf/pdf/parser'
require 'hexapdf/pdf/revision'
require 'hexapdf/pdf/type/trailer'

module HexaPDF
  module PDF

    # Manages the revisions of a PDF document.
    #
    # A PDF document has one revision when it is created. Later new revisions are added when changes
    # are made. This allows for adding information/content to a PDF file without changing the
    # original content.
    #
    # The order of the revisions is important. In HexaPDF the oldest revision always has index 0 and
    # the newest revision the highest index. This is also the order in which the revisions get
    # written.
    #
    # See: PDF1.7 s7.5.6, Revision
    class Revisions

      class << self

        # Loads all revisions for the document from the given IO and returns the created Revisions
        # object.
        #
        # If the +io+ object is +nil+, an empty Revisions object is returned.
        def from_io(document, io)
          return self.new(document) if io.nil?

          parser = Parser.new(io, document)
          object_loader = lambda {|xref_entry| parser.load_object(xref_entry)}
          revision_loader = lambda do |offset|
            xref_section, trailer = parser.load_revision(offset)
            Revision.new(document.wrap(trailer, type: Type::Trailer), xref_section: xref_section,
                         loader: object_loader)
          end

          revisions = [revision_loader.call(parser.startxref_offset)]

          i = revisions.length - 1
          while i >= 0
            # PDF1.7 s7.5.5 states that :Prev needs to be indirect, Adobe's reference 3.4.4 says it
            # should be direct. Adobe's POV is followed here. Same with :XRefStm.
            xrefstm = revisions[i].trailer.value[:XRefStm]
            prev = revisions[i].trailer.value[:Prev]
            new_revisions = [(revision_loader.call(prev) if prev),
                             (revision_loader.call(xrefstm) if xrefstm)].compact
            revisions.insert(i, *new_revisions)
            i += new_revisions.length - 1
          end

          document.version = parser.file_header_version
          self.new(document, initial_revisions: revisions)
        end

      end

      include Enumerable

      # Creates a new revisions object for the given PDF document.
      #
      # Options:
      #
      # initial_revisions::
      #     An array of revisions that should initially be used. If this option is not specified, a
      #     single empty revision is added.
      def initialize(document, initial_revisions: nil)
        @document = document
        @revisions = []
        if initial_revisions
          @revisions += initial_revisions
        else
          add
        end
      end

      # Returns the revision at the specified index.
      def revision(index)
        @revisions[index]
      end
      alias :[] :revision

      # Returns the current revision.
      def current
        @revisions.last
      end

      # Returns the number of Revision objects managed by this object.
      def size
        @revisions.size
      end

      # Adds a new empty revision to the document and returns it.
      def add
        if @revisions.empty?
          trailer = {}
        else
          trailer = current.trailer.value.dup
          trailer.delete(:Prev)
          trailer.delete(:XRefStm)
        end

        rev = Revision.new(@document.wrap(trailer, type: Type::Trailer))
        @revisions.push(rev)
        rev
      end

      # :call-seq:
      #   revisions.delete(index)    -> rev or nil
      #   revisions.delete(oid)      -> rev or nil
      #
      # Deletes a revision from the document, either by index or by specifying the revision object
      # itself.
      #
      # Returns the deleted revision object, or +nil+ if the index was out of range or no matching
      # revision was found.
      #
      # Regarding the index: The oldest revision has index 0 and the current revision the highest
      # index!
      def delete(index_or_rev)
        if @revisions.length == 1
          raise HexaPDF::Error, "A document must have a least one revision, can't delete last one"
        elsif index_or_rev.kind_of?(Integer)
          @revisions.delete_at(index_or_rev)
        else
          @revisions.delete(index_or_rev)
        end
      end

      # :call-seq:
      #   revisions.merge(range = 0..-1)    -> revisions
      #
      # Merges the revisions specified by the given range into one. Objects from newer revisions
      # overwrite those from older ones.
      def merge(range = 0..-1)
        @revisions[range].reverse.each_cons(2) do |rev, prev_rev|
          prev_rev.trailer.value.replace(rev.trailer.value)
          rev.each do |obj|
            prev_rev.delete(obj.oid, mark_as_free: false)
            prev_rev.add(obj)
          end
        end
        _first, *other = *@revisions[range]
        other.each {|rev| @revisions.delete(rev)}
        self
      end

      # :call-seq:
      #   revisions.each {|rev| block }   -> revisions
      #   revisions.each                  -> Enumerator
      #
      # Iterates over all revisions from oldest to current one.
      #
      # Changes in the number of revisions (i.e. if revisions are added or deleted) are *not*
      # reflected while iterating!
      def each(&block)
        return to_enum(__method__) unless block_given?
        Array.new(@revisions).each(&block)
        self
      end

    end

  end
end
