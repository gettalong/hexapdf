# -*- encoding: utf-8 -*-

require 'hexapdf/error'
require 'hexapdf/pdf/revision'

module HexaPDF
  module PDF

    # Manages the revisions of a PDF document.
    class Revisions

      include Enumerable

      # Creates a new revisions object for the given PDF document.
      def initialize(document, initial_revision: nil)
        @document = document
        @revisions = []
        if initial_revision
          @revisions << initial_revision
        else
          add
        end
      end

      # Returns the revision at the specified index.
      def revision(index)
        load_all
        @revisions[index]
      end

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
        load_all
        if @revisions.length == 1
          raise HexaPDF::Error, "A document must have a least one revision, can't delete last one"
        elsif index_or_rev.kind_of?(Integer)
          @revisions.delete_at(index_or_rev)
        else
          @revisions.delete(index_or_rev)
        end
      end

      # Iterates over all revisions from current to oldest one, potentially loading revisions for
      # cross-reference tables/streams of the underlying PDF document.
      def each
        return to_enum(__method__) unless block_given?

        i = @revisions.length - 1
        while i >= 0
          yield(@revisions[i])
          i += load_previous_revisions(i)
          i -= 1
        end
        self
      end

      # Loads all available revisions.
      def load_all
        return if defined?(@all_revisions_loaded)
        @all_revisions_loaded = true

        each {}
      end

      private

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
