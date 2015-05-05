# -*- encoding: utf-8 -*-

require 'hexapdf/pdf/dictionary'
require 'hexapdf/pdf/stream'
require 'hexapdf/pdf/type/page_tree_node'

module HexaPDF
  module PDF
    module Type

      # Represents a page of a PDF document.
      #
      # A page object contains the meta information for a page. Most of the fields are independent
      # from the page's content like the /Dur field. However, some of them (like /Resources or
      # /UserUnit) influence how or if the page's content can be rendered correctly.
      #
      # A number of field values can also be inherited: /Resources, /MediaBox, /CropBox, /Rotate.
      # Field inheritance means that if a field is not set on the page object itself, the value is
      # taken from the nearest page tree ancestor that has this value set.
      #
      # See: PDF1.7 s7.7.3.3, s7.7.3.4, Pages
      class Page < Dictionary

        # The inheritable fields.
        INHERITABLE_FIELDS = [:Resources, :MediaBox, :CropBox, :Rotate]

        define_field :Type,                 type: Symbol, required: true, default: :Page
        define_field :Parent,               type: PageTreeNode, indirect: true
        define_field :LastModified,         type: PDFDate, version: '1.3'
        define_field :Resources,            type: Hash
        define_field :MediaBox,             type: Array
        define_field :CropBox,              type: Array
        define_field :BleedBox,             type: Array, version: '1.3'
        define_field :TrimBox,              type: Array, version: '1.3'
        define_field :ArtBox,               type: Array, version: '1.3'
        define_field :BoxColorInfo,         type: Dictionary, version: '1.4'
        define_field :Contents,             type: [Array, Stream]
        define_field :Rotate,               type: Integer, default: 0
        define_field :Group,                type: Dictionary, version: '1.4'
        define_field :Thumb,                type: Stream
        define_field :B,                    type: Array, version: '1.1'
        define_field :Dur,                  type: Numeric, version: '1.1'
        define_field :Trans,                type: Dictionary, version: '1.1'
        define_field :Annots,               type: Array
        define_field :AA,                   type: Dictionary, version: '1.2'
        define_field :Metadata,             type: Stream, version: '1.4'
        define_field :PieceInfo,            type: Dictionary, version: '1.3'
        define_field :StructParents,        type: Integer, version: '1.3'
        define_field :ID,                   type: PDFByteString, version: '1.3'
        define_field :PZ,                   type: Numeric, version: '1.3'
        define_field :SeparationInfo,       type: Dictionary, version: '1.3'
        define_field :Tabs,                 type: Symbol, version: '1.5'
        define_field :TemplateInstantiated, type: Symbol, version: '1.5'
        define_field :PresSteps,            type: Dictionary, version: '1.5'
        define_field :UserUnit,             type: Numeric, version: '1.6'
        define_field :VP,                   type: Dictionary, version: '1.6'

        must_be_indirect

        # Returns the value for the entry +name+.
        #
        # If +name+ is an inheritable value and the value has not been set on the page object, its
        # value is retrieved from the ancestor page tree nodes.
        #
        # See: Dictionary#[]
        def [](name)
          value = super
          if value.nil? && INHERITABLE_FIELDS.include?(name)
            node = self[:Parent]
            node = node[:Parent] while !node.value.key?(name) && node.value.key?(:Parent)
            value = node[name]
          end
          value
        end

      end

    end
  end
end
