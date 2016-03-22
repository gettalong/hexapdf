# -*- encoding: utf-8 -*-

require 'hexapdf/dictionary'
require 'hexapdf/stream'
require 'hexapdf/type/page_tree_node'
require 'hexapdf/content/parser'
require 'hexapdf/content/processor'

module HexaPDF
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

      # The predefined paper sizes in points (1/72 inch):
      #
      # * ISO sizes: A0x4, A0x2, A0-A10, B0-B10, C0-C10
      # * Letter, Legal, Ledger, Tabloid, Executive
      PAPER_SIZE = {
        A0x4: [0, 0, 4768, 6741].freeze,
        A0x2: [0, 0, 3370, 4768].freeze,
        A0: [0, 0, 2384, 3370].freeze,
        A1: [0, 0, 1684, 2384].freeze,
        A2: [0, 0, 1191, 1684].freeze,
        A3: [0, 0, 842, 1191].freeze,
        A4: [0, 0, 595, 842].freeze,
        A5: [0, 0, 420, 595].freeze,
        A6: [0, 0, 298, 420].freeze,
        A7: [0, 0, 210, 298].freeze,
        A8: [0, 0, 147, 210].freeze,
        A9: [0, 0, 105, 147].freeze,
        A10: [0, 0, 74, 105].freeze,
        B0: [0, 0, 2835, 4008].freeze,
        B1: [0, 0, 2004, 2835].freeze,
        B2: [0, 0, 1417, 2004].freeze,
        B3: [0, 0, 1001, 1417].freeze,
        B4: [0, 0, 709, 1001].freeze,
        B5: [0, 0, 499, 709].freeze,
        B6: [0, 0, 354, 499].freeze,
        B7: [0, 0, 249, 354].freeze,
        B8: [0, 0, 176, 249].freeze,
        B9: [0, 0, 125, 176].freeze,
        B10: [0, 0, 88, 125].freeze,
        C0: [0, 0, 2599, 3677].freeze,
        C1: [0, 0, 1837, 2599].freeze,
        C2: [0, 0, 1298, 1837].freeze,
        C3: [0, 0, 918, 1298].freeze,
        C4: [0, 0, 649, 918].freeze,
        C5: [0, 0, 459, 649].freeze,
        C6: [0, 0, 323, 459].freeze,
        C7: [0, 0, 230, 323].freeze,
        C8: [0, 0, 162, 230].freeze,
        C9: [0, 0, 113, 162].freeze,
        C10: [0, 0, 79, 113].freeze,
        Letter: [0, 0, 612, 792].freeze,
        Legal: [0, 0, 612, 1008].freeze,
        Ledger: [0, 0, 792, 1224].freeze,
        Tabloid: [0, 0, 1224, 792].freeze,
        Executive: [0, 0, 522, 756].freeze,
      }

      # The inheritable fields.
      INHERITABLE_FIELDS = [:Resources, :MediaBox, :CropBox, :Rotate]

      # The required inheritable fields.
      REQUIRED_INHERITABLE_FIELDS = [:Resources, :MediaBox]


      define_field :Type,                 type: Symbol, required: true, default: :Page
      define_field :Parent,               type: :Pages, required: true, indirect: true
      define_field :LastModified,         type: PDFDate, version: '1.3'
      define_field :Resources,            type: :XXResources
      define_field :MediaBox,             type: Rectangle
      define_field :CropBox,              type: Rectangle
      define_field :BleedBox,             type: Rectangle, version: '1.3'
      define_field :TrimBox,              type: Rectangle, version: '1.3'
      define_field :ArtBox,               type: Rectangle, version: '1.3'
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
        if value[name].nil? && INHERITABLE_FIELDS.include?(name)
          node = self[:Parent] || (raise InvalidPDFObjectError, "Page has no parent node")
          node = node[:Parent] while node.value[name].nil? && node.key?(:Parent)
          node[name] || super
        else
          super
        end
      end

      # Returns the rectangle defining a certain kind of box for the page.
      #
      # This method should be used instead of directly accessing any of /MediaBox, /CropBox,
      # /BleedBox, /ArtBox or /TrimBox because it also takes the fallback values into account!
      #
      # The following types are allowed:
      #
      # :media::
      #     The media box defines the boundaries of the medium the page is to be printed on.
      #
      # :crop::
      #     The crop box defines the region to which the contents of the page should be clipped
      #     when it is displayed or printed. The default is the media box.
      #
      # :bleed::
      #     The bleed box defines the region to which the contents of the page should be clipped
      #     when output in a production environment. The default is the crop box.
      #
      # :trim::
      #     The trim box defines the intended dimensions of the page after trimming. The default
      #     value is the crop box.
      #
      # :art::
      #     The art box defines the region of page's meaningful content as intended by the author.
      #     The default is the crop box.
      #
      # See: PDF1.7 s14.11.2
      def box(type = :media)
        case type
        when :media then self[:MediaBox]
        when :crop then self[:CropBox] || self[:MediaBox]
        when :bleed then self[:BleedBox] || self[:CropBox] || self[:MediaBox]
        when :trim then self[:TrimBox] || self[:CropBox] || self[:MediaBox]
        when :art then self[:ArtBox] || self[:CropBox] || self[:MediaBox]
        else
          raise ArgumentError, "Unsupported page box type provided: #{type}"
        end
      end

      # Returns the concatenated stream data from the content streams as binary string.
      #
      # Note: Any modifications done to the returned value *won't* be reflected in any of the
      # stream's data!
      def contents
        Array(self[:Contents]).each_with_object("".b) do |content_stream, content|
          content << " ".freeze unless content.empty?
          content << document.deref(content_stream).stream
        end
      end

      # Replaces the contents of the page with the given string.
      #
      # This is done by deleting all but the first content stream and reuses this content stream;
      # or by creating a new one if no content stream exists.
      def contents=(data)
        first, *rest = self[:Contents]
        rest.each {|stream| document.delete(stream)}
        if first
          self[:Contents] = first
          document.deref(first).stream = data
        else
          self[:Contents] = document.add({Filter: :FlateDecode}, stream: data)
        end
      end

      # Returns the resource dictionary which is automatically created if it doesn't exist.
      def resources
        self[:Resources] ||= document.wrap({}, type: :XXResources)
      end

      # Processes the content streams associated with the page with a Content::Processor object
      # and calls the callback methods for the found operators in the given +renderer+ object.
      #
      # The processor object is yielded if a block is given so that it can be customized before
      # use.
      def process_contents(renderer)
        self[:Resources] = {} if self[:Resources].nil?
        processor = Content::Processor.new(self[:Resources], renderer: renderer)
        yield(processor) if block_given?
        Content::Parser.parse(contents, processor)
      end

      # Creates an independent Form XObject from the page's dictionary and contents for the given
      # PDF document.
      #
      # Note: The created Form XObject is *not* added to the document automatically!
      def to_form_xobject
        first, *rest = self[:Contents]
        stream = if !first
                   nil
                 elsif !rest.empty? || first.raw_stream.kind_of?(String)
                   contents
                 else
                   first.raw_stream
                 end
        dict = {
          Type: :XObject,
          Subtype: :Form,
          BBox: HexaPDF::Object.deep_copy(box(:crop)),
          Resources: HexaPDF::Object.deep_copy(self[:Resources]),
          Filter: :FlateDecode,
        }
        document.wrap(dict, stream: stream)
      end

      private

      # Ensures that the required inheritable fields are set.
      def perform_validation(&block)
        super
        REQUIRED_INHERITABLE_FIELDS.each do |name|
          if self[name].nil?
            yield("Inheritable page field #{name} not set", name == :Resources)
            self[:Resources] = {}
            self[:Resources].validate(&block)
          end
        end
      end

    end

  end
end
