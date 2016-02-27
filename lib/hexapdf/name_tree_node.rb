# -*- encoding: utf-8 -*-

require 'hexapdf/dictionary'
require 'hexapdf/utils/sorted_tree_node'

module HexaPDF

  # Implementation of PDF name trees.
  #
  # Name trees are used in a similar fashion as dictionaries, however, the key in a name tree is
  # always a string instead of a symbol. Another difference is that the keys in a name tree are
  # always sorted to allow fast lookup of a specific key.
  #
  # A name tree consists of one or more NameTreeNodes. If there is only one node, it contains all
  # stored associations in the /Names entry. Otherwise the root node needs to have a /Kids entry
  # that points to one or more intermediate or leaf nodes. An intermediate node contains a /Kids
  # entry whereas a leaf node contains a /Names entry.
  #
  # Since this is a complex structure that must follow several restrictions, it is not advised to
  # build a name tree manually. Instead, use the provided convenience methods (see
  # Utils::SortedTreeNode) to add or retrieve entries. They ensure that the name tree stays valid.
  #
  # The public convenience methods that should be used are:
  #
  # * #add_name (alias for Utils::SortedTreeNode#add_to_tree)
  # * #delete_name (alias for Utils::SortedTreeNode#delete_from_tree)
  # * #find_name (alias for Utils::SortedTreeNode#find_in_tree)
  #
  # See: PDF1.7 s7.9.6
  class NameTreeNode < Dictionary

    include Utils::SortedTreeNode

    define_field :Kids,   type: Array
    define_field :Names,  type: Array
    define_field :Limits, type: Array

    alias_method :add_name, :add_to_tree
    alias_method :delete_name, :delete_from_tree
    alias_method :find_name, :find_in_tree
    public :add_name, :delete_name, :find_name

    private

    # Defines the dictionary entry name that contains the leaf node entries.
    def leaf_node_container_name
      :Names
    end

    # Defines the class that is used for the keys in the name tree (String).
    def key_type
      String
    end

  end

end
