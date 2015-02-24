# -*- encoding: utf-8 -*-

require 'hexapdf/error'
require 'hexapdf/pdf/revision'

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

      include Enumerable

      # Creates a new revisions object for the given PDF document.
      #
      # If an initial revision is provided (normally the case when a PDF file is parsed), all
      # referenced revisions are also automatically added.
      def initialize(document, initial_revision: nil)
        @document = document
        @revisions = []
        if initial_revision
          @revisions << initial_revision
        else
          add
        end
        load_all
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

      # Adds a new empty revision to the document and returns it.
      def add
        if @revisions.empty?
          trailer = {}
        else
          trailer = current.trailer.value.dup
          trailer.delete(:Prev)
          trailer.delete(:XRefStm)
        end

        rev = Revision.new(@document.wrap(trailer, type: :Trailer))
        @revisions.push(rev)
        rev
      end

      # Deletes a revision from the document, either by index or by specifying the revision object
      # itself.
      #
      # Note that the oldest revision has index 0 and the current revision the highest index!
      #
      # Returns the deleted revision object, or +nil+ if the index was out of range or no matching
      # revision was found.
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
      #   revisions.each {|rev| block }   -> revisions
      #   revisions.each                  -> Enumerator
      #
      # Iterates over all revisions from current to oldest one.
      #
      # Changes in the number of revisions (i.e. if revisions are added or deleted) are *not*
      # reflected while iterating!
      def each(&block)
        return to_enum(__method__) unless block_given?
        Array.new(@revisions).reverse_each(&block)
        self
      end

      private

      # Loads all available revisions.
      def load_all
        i = @revisions.length - 1
        while i >= 0
          i += load_previous_revisions(i)
          i -= 1
        end
      end

      # :call-seq:
      #   doc.load_previous_revisions(i)     -> int
      #
      # Loads the directly previous revisions for the already loaded revision at position +i+ and
      # returns the number of newly added revisions (0, 1 or 2).
      #
      # Previous revisions are denoted by the :Prev and :XRefStm keys of the trailer.
      def load_previous_revisions(i)
        i = @revisions.length + i if i < 0
        rev = @revisions[i]
        @loaded_revisions ||= {}
        return 0 if @loaded_revisions.key?(rev)

        # PDF1.7 s7.5.5 states that :Prev needs to be indirect, Adobe's reference 3.4.4 says it
        # should be direct. Adobe's POV is followed here. Same with :XRefStm.
        xrefstm = @revisions[i].trailer.value[:XRefStm]
        prev = @revisions[i].trailer.value[:Prev]
        revisions = [(@document.parser.load_revision(prev) if prev && @document.parser),
                     (@document.parser.load_revision(xrefstm) if xrefstm && @document.parser)].compact
        @revisions.insert(i, *revisions)
        @loaded_revisions[rev] = true

        revisions.length
      end

    end

  end
end
