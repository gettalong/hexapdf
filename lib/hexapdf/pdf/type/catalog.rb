# -*- encoding: utf-8 -*-

require 'hexapdf/pdf/dictionary'
require 'hexapdf/pdf/number_tree_node'
require 'hexapdf/pdf/stream'

module HexaPDF
  module PDF
    module Type

      # Represents the PDF's catalog dictionary which is at the root of the document's object
      # hierarchy.
      #
      # The catalog dictionary is linked via the /Root entry from the Trailer.
      #
      # See: PDF1.7 s7.7.2, Trailer
      class Catalog < Dictionary

        define_field :Type,              type: Symbol,     required: true, default: :Catalog
        define_field :Version,           type: Symbol,     version: '1.4'
        define_field :Extensions,        type: Dictionary, version: '1.7'
        # Pages field is required but this is handled in validator
        define_field :Pages,             type: 'HexaPDF::PDF::Type::PageTreeNode', indirect: true
        define_field :PageLabels,        type: NumberTreeNode, version: '1.3'
        define_field :Names,             type: 'HexaPDF::PDF::Type::Names', version: '1.2'
        define_field :Dests,             type: Dictionary, version: '1.1'
        define_field :ViewerPreferences, type: 'HexaPDF::PDF::Type::ViewerPreferences', version: '1.2'
        define_field :PageLayout,        type: Symbol,     default: :SinglePage
        define_field :PageMode,          type: Symbol,     default: :UseNone
        define_field :Outlines,          type: Dictionary, indirect: true
        define_field :Threads,           type: Array,      version: '1.1'
        define_field :OpenAction,        type: [Array, Dictionary, Hash], version: '1.1'
        define_field :AA,                type: Dictionary, version: '1.4'
        define_field :URI,               type: Dictionary, version: '1.1'
        define_field :AcroForm,          type: Dictionary, version: '1.2'
        define_field :Metadata,          type: Stream,     indirect: true, version: '1.4'
        define_field :StructTreeRoot,    type: Dictionary, version: '1.3'
        define_field :MarkInfo,          type: Dictionary, version: '1.4'
        define_field :Lang,              type: String,     version: '1.4'
        define_field :SpiderInfo,        type: Dictionary, version: '1.3'
        define_field :OutputIntents,     type: Array,      version: '1.4'
        define_field :PieceInfo,         type: Dictionary, version: '1.4'
        define_field :OCProperties,      type: Dictionary, version: '1.5'
        define_field :Perms,             type: Dictionary, version: '1.5'
        define_field :Legal,             type: Dictionary, version: '1.5'
        define_field :Requirements,      type: Array,      version: '1.7'
        define_field :Collection,        type: Dictionary, version: '1.7'
        define_field :NeedsRendering,    type: Boolean,    version: '1.7'

        define_validator(:validate_catalog)

        must_be_indirect

        # Returns the root node of the page tree.
        #
        # See: PageTreeNode
        def pages
          self[:Pages] ||= document.add(Type: :Pages)
        end

        private

        # Ensures that there is a valid page tree.
        def validate_catalog
          unless key?(:Pages)
            yield("A PDF document needs a page tree", true)
            value[:Pages] = document.add(Type: :Pages)
            value[:Pages].validate {|msg, correctable| yield(msg, correctable)}
          end
        end

      end

    end
  end
end
