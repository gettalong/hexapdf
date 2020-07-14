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

module HexaPDF
  class Document

    # This class provides methods for managing the pages of a PDF file.
    #
    # It uses the methods of HexaPDF::Type::PageTreeNode underneath but provides a more convenient
    # interface.
    class Pages

      include Enumerable

      # Creates a new Pages object for the given PDF document.
      def initialize(document)
        @document = document
      end

      # Returns the root of the page tree, a HexaPDF::Type::PageTreeNode object.
      def root
        @document.catalog.pages
      end

      # :call-seq:
      #   pages.add                                     -> new_page
      #   pages.add(media_box, orientation: :portrait)  -> new_page
      #   pages.add(page)                               -> page
      #
      # Adds the page or a new empty page at the end and returns it.
      #
      # If no argument is given, a new page with the default dimensions (see configuration option
      # 'page.default_media_box') is used.
      #
      # If the single argument is an array with four numbers (specifying the media box), the new
      # page will have these dimensions.
      #
      # If the single argument is a symbol, it is taken as referencing a pre-defined media box in
      # HexaPDF::Type::Page::PAPER_SIZE for the new page. The optional argument +orientation+ can be
      # used to change the orientation to :landscape if needed.
      def add(page = nil, orientation: :portrait)
        if page.kind_of?(Array)
          page = @document.add({Type: :Page, MediaBox: page})
        elsif page.kind_of?(Symbol)
          box = Type::Page.media_box(page, orientation: orientation)
          page = @document.add({Type: :Page, MediaBox: box})
        end
        @document.catalog.pages.add_page(page)
      end

      # :call-seq:
      #   pages << page            -> pages
      #
      # Appends the given page at the end and returns the pages object itself to allow chaining.
      def <<(page)
        add(page)
        self
      end

      # Inserts the page or a new empty page at the zero-based index and returns it.
      #
      # Negative indices count backwards from the end, i.e. -1 is the last page. When using
      # negative indices, the page will be inserted after that element. So using an index of -1
      # will insert the page after the last page.
      def insert(index, page = nil)
        @document.catalog.pages.insert_page(index, page)
      end

      # Deletes the given page object from the document's page tree and the document.
      #
      # Also see: HexaPDF::Type::PageTreeNode#delete_page
      def delete(page)
        @document.catalog.pages.delete_page(page)
      end

      # Deletes the page object at the given index from the document's page tree and the document.
      #
      # Also see: HexaPDF::Type::PageTreeNode#delete_page
      def delete_at(index)
        @document.catalog.pages.delete_page(index)
      end

      # Returns the page for the zero-based index, or +nil+ if no such page exists.
      #
      # Negative indices count backwards from the end, i.e. -1 is the last page.
      def [](index)
        @document.catalog.pages.page(index)
      end

      # :call-seq:
      #   pages.each {|page| block }   -> pages
      #   pages.each                   -> Enumerator
      #
      # Iterates over all pages inorder.
      def each(&block)
        @document.catalog.pages.each_page(&block)
      end

      # Returns the number of pages in the PDF document. May be zero if the document has no pages.
      def count
        @document.catalog.pages.page_count
      end
      alias size count
      alias length count

    end

  end
end
