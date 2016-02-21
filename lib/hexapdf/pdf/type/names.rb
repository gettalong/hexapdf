# -*- encoding: utf-8 -*-

require 'hexapdf/dictionary'
require 'hexapdf/name_tree_node'

module HexaPDF
  module PDF
    module Type

      # Represents the PDF's names dictionary which associates names with data for various purposes.
      #
      # Each field corresponds to a name tree that holds the information and can be used to find,
      # add or delete an entry.
      #
      # This dictionary is linked via the /Names entry from the Catalog.
      #
      # See: PDF1.7 s7.7.4, Catalog, NameTreeNode
      class Names < Dictionary

        define_field :Dests,                  type: NameTreeNode, version: '1.2'
        define_field :AP,                     type: NameTreeNode, version: '1.3'
        define_field :JavaScript,             type: NameTreeNode, version: '1.3'
        define_field :Pages,                  type: NameTreeNode, version: '1.3'
        define_field :Templates,              type: NameTreeNode, version: '1.3'
        define_field :IDS,                    type: NameTreeNode, version: '1.3'
        define_field :URLS,                   type: NameTreeNode, version: '1.3'
        define_field :EmbeddedFiles,          type: NameTreeNode, version: '1.4'
        define_field :AlternatePresentations, type: NameTreeNode, version: '1.4'
        define_field :Renditions,             type: NameTreeNode, version: '1.5'

      end

    end
  end
end
