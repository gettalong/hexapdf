# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2020 Thomas Leitner
#
# HexaPDF is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License version 3 as
# published by the Free Software Foundation with the addition of the
# following permission added to Section 15 as permitted in Section 7(a):
# FOR ANY PART OF THE COVERED WORK IN WHICH THE COPYRIGHT IS OWNED BY
# THOMAS LEITNER, THOMAS LEITNER DISCLAIMS THE WARRANTY OF NON
# INFRINGEMENT OF THIRD PARTY RIGHTS.
#
# HexaPDF is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public
# License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with HexaPDF. If not, see <http://www.gnu.org/licenses/>.
#
# The interactive user interfaces in modified source and object code
# versions of HexaPDF must display Appropriate Legal Notices, as required
# under Section 5 of the GNU Affero General Public License version 3.
#
# In accordance with Section 7(b) of the GNU Affero General Public
# License, a covered work must retain the producer line in every PDF that
# is created or manipulated using HexaPDF.
#
# If the GNU Affero General Public License doesn't fit your need,
# commercial licenses are available at <https://gettalong.at/hexapdf/>.
#++

require 'hexapdf/error'
require 'hexapdf/parser'
require 'hexapdf/revision'
require 'hexapdf/type/trailer'

module HexaPDF

  # Manages the revisions of a PDF document.
  #
  # A PDF document has one revision when it is created. Later, new revisions are added when changes
  # are made. This allows for adding information/content to a PDF file without changing the original
  # content.
  #
  # The order of the revisions is important. In HexaPDF the oldest revision always has index 0 and
  # the newest revision the highest index. This is also the order in which the revisions get
  # written.
  #
  # See: PDF1.7 s7.5.6, HexaPDF::Revision
  class Revisions

    class << self

      # Loads all revisions for the document from the given IO and returns the created Revisions
      # object.
      #
      # If the +io+ object is +nil+, an empty Revisions object is returned.
      def from_io(document, io)
        return new(document) if io.nil?

        parser = Parser.new(io, document)
        object_loader = lambda {|xref_entry| parser.load_object(xref_entry) }

        revisions = []
        begin
          xref_section, trailer = parser.load_revision(parser.startxref_offset)
          revisions << Revision.new(document.wrap(trailer, type: :XXTrailer),
                                    xref_section: xref_section, loader: object_loader)
          seen_xref_offsets = {parser.startxref_offset => true}

          while (prev = revisions[0].trailer.value[:Prev]) &&
              !seen_xref_offsets.key?(prev)
            # PDF1.7 s7.5.5 states that :Prev needs to be indirect, Adobe's reference 3.4.4 says it
            # should be direct. Adobe's POV is followed here. Same with :XRefStm.
            xref_section, trailer = parser.load_revision(prev)
            seen_xref_offsets[prev] = true

            stm = revisions[0].trailer.value[:XRefStm]
            if stm && !seen_xref_offsets.key?(stm)
              stm_xref_section, = parser.load_revision(stm)
              xref_section.merge!(stm_xref_section)
              seen_xref_offsets[stm] = true
            end

            revisions.unshift(Revision.new(document.wrap(trailer, type: :XXTrailer),
                                           xref_section: xref_section, loader: object_loader))
          end
        rescue HexaPDF::MalformedPDFError
          reconstructed_revision = parser.reconstructed_revision
          if revisions.size > 0
            reconstructed_revision.trailer.data.value = revisions.last.trailer.data.value
          end
          revisions << reconstructed_revision
        end

        document.version = parser.file_header_version rescue '1.0'
        new(document, initial_revisions: revisions, parser: parser)
      end

    end

    include Enumerable

    # The Parser instance used for reading the initial revisions.
    attr_reader :parser

    # Creates a new revisions object for the given PDF document.
    #
    # Options:
    #
    # initial_revisions::
    #     An array of revisions that should initially be used. If this option is not specified, a
    #     single empty revision is added.
    #
    # parser::
    #     The parser with which the initial revisions were read. If this option is not specified
    #     even though the document was read from an IO stream, some parts may not work, like
    #     incremental writing.
    def initialize(document, initial_revisions: nil, parser: nil)
      @document = document
      @parser = parser

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
    alias [] revision

    # Returns the current revision.
    def current
      @revisions.last
    end

    # Returns the number of HexaPDF::Revision objects managed by this object.
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

      rev = Revision.new(@document.wrap(trailer, type: :XXTrailer))
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
          if obj.data != prev_rev.object(obj)&.data
            prev_rev.delete(obj.oid, mark_as_free: false)
            prev_rev.add(obj)
          end
        end
      end
      _first, *other = *@revisions[range]
      other.each {|rev| @revisions.delete(rev) }
      self
    end

    # :call-seq:
    #   revisions.each {|rev| block }   -> revisions
    #   revisions.each                  -> Enumerator
    #
    # Iterates over all revisions from oldest to current one.
    def each(&block)
      return to_enum(__method__) unless block_given?
      @revisions.each(&block)
      self
    end

  end

end
