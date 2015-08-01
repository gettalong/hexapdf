# -*- encoding: utf-8 -*-

require 'hexapdf/pdf/dictionary'

module HexaPDF
  module PDF
    module Type

      # Represents a node in the page tree of the PDF's document.
      #
      # The page tree is a tree structure containing page tree nodes for the root and intermediate
      # nodes and page objects for the leaf nodes (see Page). The root node of the page tree is
      # linked via the /Pages entry in the Catalog.
      #
      # All operations except #add_page on the page tree are rather expensive because page tree
      # nodes and page objects can be mixed. This means that for finding a page at a specific index
      # we have to go through all objects that come before it.
      #
      # Page indices are zero-based, not one-based. Therefore the first page has an index of 0!
      #
      # Since the page tree needs a certain structure it is not advised to directly modify page tree
      # nodes. The validation feature can correct most problems but until the page tree is in order
      # the methods may not work correctly!
      #
      # See: PDF1.7 s7.7.3.2, Page
      class PageTreeNode < Dictionary

        define_field :Type,   type: Symbol, required: true, default: :Pages
        define_field :Parent, type: Dictionary, indirect: true
        define_field :Kids,   type: Array, required: true, default: []
        define_field :Count,  type: Integer, required: true, default: 0

        # Inheritable page fields
        define_field :Resources, type: :Resources
        define_field :MediaBox,  type: Array
        define_field :CropBox,   type: Array
        define_field :Rotate,    type: Integer

        define_validator(:validate_page_tree)

        must_be_indirect

        # Returns the number of pages under this page tree.
        #
        # *Note*: If this methods is not called on the root object of the page tree, the returned
        # number is not the total number of pages in the document!
        def page_count
          self[:Count]
        end

        # Returns the page for the zero-based index or +nil+ if no such page exists.
        #
        # Negative indices count backwards from the end, i.e. -1 is the last page.
        def page(index)
          index = self[:Count] + index if index < 0
          return nil if index < 0 || index >= self[:Count]

          self[:Kids].each do |kid|
            kid = document.deref(kid)
            if kid.type == :Page
              if index == 0
                return kid
              else
                index -= 1
              end
            elsif index < kid[:Count]
              return kid.page(index)
            else
              index -= kid[:Count]
            end
          end
        end

        # Inserts the page or a new empty page at the zero-based index and returns it.
        #
        # Negative indices count backwards from the end, i.e. -1 is the last page. When using
        # negative indices, the page will be inserted after that element. So using an index of -1
        # will insert the page after the last page.
        #
        # Must be called on the root of the page tree, otherwise the /Count entries are not
        # correctly updated!
        def insert_page(index, page = nil)
          page ||= new_page
          index = self[:Count] + index + 1 if index < 0

          if index >= self[:Count]
            self[:Kids] << page
            page[:Parent] = self
          else
            self[:Kids].each_with_index do |kid, kid_index|
              kid = document.deref(kid)
              if index == 0
                self[:Kids].insert(kid_index, page)
                page[:Parent] = self
                break
              elsif kid.type == :Page
                index -= 1
              elsif index <= kid[:Count]
                kid.insert_page(index, page)
                break
              else
                index -= kid[:Count]
              end
            end
          end

          self[:Count] += 1

          page
        end

        # Adds the page or a new empty page at the end and returns it.
        def add_page(page = nil)
          insert_page(-1, page)
        end

        # Deletes the page at the position specified by the zero-based index and returns it. If an
        # invalid index is specified, +nil+ is returned.
        #
        # Negative indices count backwards from the end, i.e. -1 is the last page.
        #
        # Must be called on the root of the page tree, otherwise the /Count entries are not
        # correctly updated!
        def delete_page(index)
          index = self[:Count] + index if index < 0
          return nil if index < 0 || index >= self[:Count]

          page = nil
          self[:Count] -= 1
          self[:Kids].each_with_index do |kid, kid_index|
            kid = document.deref(kid)
            if kid.type == :Page && index == 0
              page = self[:Kids].delete_at(kid_index)
              document.delete(page)
              break
            elsif kid.type == :Page
              index -= 1
            elsif index < kid[:Count]
              page = kid.delete_page(index)
              if kid[:Count] == 0
                self[:Kids].delete_at(kid_index)
                document.delete(kid)
              elsif kid[:Count] == 1
                self[:Kids][kid_index] = kid[:Kids][0]
                kid[:Kids][0][:Parent] = self
                document.delete(kid)
              end
              break
            else
              index -= kid[:Count]
            end
          end

          page
        end

        # :call-seq:
        #   pages.each_page {|page| block }   -> pages
        #   pages.each_page                   -> Enumerator
        #
        # Iterates over all pages that are beneath this page tree node, from the first to the last
        # page.
        def each_page(&block)
          return to_enum(__method__) unless block_given?

          self[:Kids].each do |kid|
            kid = document.deref(kid)
            if kid.type == :Page
              yield(kid)
            else
              kid.each_page(&block)
            end
          end

          self
        end

        private

        # Returns a new page object, correctly initialized using the document's configuration
        # options.
        def new_page
          media_box = config['page.default_media_box']
          media_box = Page::PAPER_SIZE[media_box] if media_box.kind_of?(Symbol)
          if media_box.nil?
            raise HexaPDF::Error, "Can't create new page, page.default_media_box option is invalid"
          end
          document.add(Type: :Page, MediaBox: media_box, Resources: {})
        end

        # Ensures that the /Count and /Parent fields of the whole page tree are set up correctly and
        # that there is at least one page node. This is therefore only done for the root node of the
        # page tree!
        def validate_page_tree
          return if key?(:Parent)

          validate_node = lambda do |node|
            count = 0
            node[:Kids].reject! do |kid|
              kid = document.deref(kid)
              if !kid.kind_of?(HexaPDF::PDF::Object) || kid.null? ||
                  (kid.type != :Page && kid.type != :Pages)
                yield("Invalid object in page tree node", true)
                next true
              elsif kid.type == :Page
                count += 1
              else
                count += validate_node.call(kid)
              end
              if kid[:Parent] != node
                yield("Field Parent of page tree node (#{kid.oid},#{kid.gen}) is invalid", true)
                kid[:Parent] = node
              end
              false
            end
            if node[:Count] != count
              yield("Field Count of page tree node (#{node.oid},#{node.gen}) is invalid", true)
              node[:Count] = count
            end
            count
          end

          validate_node.call(self)

          if self[:Count] == 0
            yield("A PDF document needs at least one page", true)
            add_page.validate {|msg, correctable| yield(msg, correctable)}
          end
        end

      end

    end
  end
end
