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
      # See: PDF1.7 s7.7.3.2, Page
      class PageTreeNode < Dictionary

        define_field :Type,   type: Symbol,  required: true, default: :Pages
        define_field :Parent, type: Hash,    indirect: true
        define_field :Kids,   type: Array,   required: true, default: []
        define_field :Count,  type: Integer, required: true, default: 0

        define_validator(:validate_page_tree)

        must_be_indirect

        # Returns the page for the index or +nil+ if no such page exists.
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

        # Inserts the page or a new empty page at the index and returns it.
        #
        # Negative indices count backwards from the end, i.e. -1 is the last page. When using
        # negative indices, the page will be inserted after that element. So using an index of -1
        # will insert the page after the last page.
        #
        # Must be called on the root of the page tree, otherwise the /Count entries are not
        # correctly updated!
        def insert_page(index, page = nil)
          page ||= document.add({Type: :Page})
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

        # Deletes the page at the position specified by index and returns it. If an invalid index is
        # specified, +nil+ is returned.
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

        private

        # Ensures that the /Count and /Parent fields of the whole page tree are set up correctly.
        # This is therefore only done for the root node of the page tree!
        def validate_page_tree
          return if value.key?(:Parent)

          validate_node = lambda do |node|
            count = 0
            node[:Kids].each do |kid|
              kid = document.deref(kid)
              if kid.type == :Page
                count += 1
              else
                count += validate_node.call(kid)
              end
              if kid[:Parent] != node
                yield("Field Parent of page tree node (#{kid.oid},#{kid.gen}) is invalid", true)
                kid[:Parent] = node
              end
            end
            if node[:Count] != count
              yield("Field Count of page tree node (#{node.oid},#{node.gen}) is invalid", true)
              node[:Count] = count
            end
            count
          end

          validate_node.call(self)
        end

      end

    end
  end
end
