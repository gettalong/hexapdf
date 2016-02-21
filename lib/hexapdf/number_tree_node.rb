# -*- encoding: utf-8 -*-

require 'hexapdf/dictionary'
require 'hexapdf/pdf/utils/sorted_tree_node'

module HexaPDF

  # Implementation of PDF number trees.
  #
  # Number trees are similar to name trees but use integers as keys instead of strings. See
  # NameTreeNode for a more detailed explanation.
  #
  # The public convenience methods that should be used are:
  #
  # * #add_number (alias for Utils::SortedTreeNode#add_to_tree)
  # * #delete_number (alias for Utils::SortedTreeNode#delete_from_tree)
  # * #find_number (alias for Utils::SortedTreeNode#find_in_tree)
  #
  # See: PDF1.7 s7.9.7, NameTreeNode
  class NumberTreeNode < Dictionary

    include HexaPDF::PDF::Utils::SortedTreeNode

    define_field :Kids,   type: Array
    define_field :Nums,  type: Array
    define_field :Limits, type: Array

    alias_method :add_number, :add_to_tree
    alias_method :delete_number, :delete_from_tree
    alias_method :find_number, :find_in_tree
    public :add_number, :delete_number, :find_number

    private

    # Defines the dictionary entry name that contains the leaf node entries.
    def leaf_node_container_name
      :Nums
    end

    # Defines the class that is used for the keys in the name tree (String).
    def key_type
      Integer
    end

  end

end
