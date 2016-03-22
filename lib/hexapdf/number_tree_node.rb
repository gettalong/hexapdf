# -*- encoding: utf-8 -*-

require 'hexapdf/dictionary'
require 'hexapdf/utils/sorted_tree_node'

module HexaPDF

  # Implementation of PDF number trees.
  #
  # Number trees are similar to name trees but use integers as keys instead of strings. See
  # NameTreeNode for a more detailed explanation.
  #
  # See: PDF1.7 s7.9.7, NameTreeNode
  class NumberTreeNode < Dictionary

    include Utils::SortedTreeNode

    define_field :Kids,   type: Array
    define_field :Nums,  type: Array
    define_field :Limits, type: Array

    private

    # Defines the dictionary entry name that contains the leaf node entries.
    def leaf_node_container_name
      :Nums
    end

    # Defines the class that is used for the keys in the number tree (Integer).
    def key_type
      Integer
    end

  end

end
