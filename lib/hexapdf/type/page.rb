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
require 'hexapdf/dictionary'
require 'hexapdf/stream'
require 'hexapdf/type/page_tree_node'
require 'hexapdf/content'
require 'hexapdf/content/transformation_matrix'

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
      }.freeze

      # Returns the media box for the given paper size. See PAPER_SIZE for the defined paper sizes.
      def self.media_box(paper_size, orientation: :portrait)
        unless PAPER_SIZE.key?(paper_size)
          raise HexaPDF::Error, "Invalid paper size specified: #{paper_size}"
        end

        media_box = PAPER_SIZE[paper_size].dup
        media_box[2], media_box[3] = media_box[3], media_box[2] if orientation == :landscape
        media_box
      end

      # The inheritable fields.
      INHERITABLE_FIELDS = [:Resources, :MediaBox, :CropBox, :Rotate].freeze

      # The required inheritable fields.
      REQUIRED_INHERITABLE_FIELDS = [:Resources, :MediaBox].freeze

      define_type :Page

      define_field :Type,                 type: Symbol, required: true, default: type
      define_field :Parent,               type: :Pages, required: true, indirect: true
      define_field :LastModified,         type: PDFDate, version: '1.3'
      define_field :Resources,            type: :XXResources
      define_field :MediaBox,             type: Rectangle
      define_field :CropBox,              type: Rectangle
      define_field :BleedBox,             type: Rectangle, version: '1.3'
      define_field :TrimBox,              type: Rectangle, version: '1.3'
      define_field :ArtBox,               type: Rectangle, version: '1.3'
      define_field :BoxColorInfo,         type: Dictionary, version: '1.4'
      define_field :Contents,             type: [Stream, PDFArray]
      define_field :Rotate,               type: Integer, default: 0
      define_field :Group,                type: Dictionary, version: '1.4'
      define_field :Thumb,                type: Stream
      define_field :B,                    type: PDFArray, version: '1.1'
      define_field :Dur,                  type: Numeric, version: '1.1'
      define_field :Trans,                type: Dictionary, version: '1.1'
      define_field :Annots,               type: PDFArray
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
      define_field :VP,                   type: PDFArray, version: '1.6'

      # Returns +true+ since page objects must always be indirect.
      def must_be_indirect?
        true
      end

      # Returns the value for the entry +name+.
      #
      # If +name+ is an inheritable value and the value has not been set on the page object, its
      # value is retrieved from the ancestor page tree nodes.
      #
      # See: Dictionary#[]
      def [](name)
        if value[name].nil? && INHERITABLE_FIELDS.include?(name)
          node = self
          node = node[:Parent] while node.value[name].nil? && node[:Parent]
          node == self || node.value[name].nil? ? super : node[name]
        else
          super
        end
      end

      # Copies the page's inherited values from the ancestor page tree nodes into a hash and returns
      # the hash.
      #
      # The hash can then be used to update the page itself (e.g. when moving a page from one
      # position to another) or another page (e.g. when importing a page from another document).
      def copy_inherited_values
        INHERITABLE_FIELDS.each_with_object({}) do |name, hash|
          hash[name] = HexaPDF::Object.deep_copy(self[name]) if value[name].nil?
        end
      end

      # :call-seq:
      #   page.box(type = :media)              -> box
      #   page.box(type = :media, rectangle)   -> rectangle
      #
      # If no +rectangle+ is given, returns the rectangle defining a certain kind of box for the
      # page. Otherwise sets the value for the given box type to +rectangle+ (an array with four
      # values or a HexaPDF::Rectangle).
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
      #     The art box defines the region of the page's meaningful content as intended by the
      #     author. The default is the crop box.
      #
      # See: PDF1.7 s14.11.2
      def box(type = :media, rectangle = nil)
        if rectangle
          case type
          when :media, :crop, :bleed, :trim, :art
            self["#{type.capitalize}Box".to_sym] = rectangle
          else
            raise ArgumentError, "Unsupported page box type provided: #{type}"
          end
        else
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
      end

      # Returns the orientation of the media box, either :portrait or :landscape.
      def orientation
        box = self[:MediaBox]
        rotation = self[:Rotate]
        if (box.height > box.width && (rotation == 0 || rotation == 180)) ||
            (box.height < box.width && (rotation == 90 || rotation == 270))
          :portrait
        else
          :landscape
        end
      end

      # Rotates the page +angle+ degrees counterclockwise where +angle+ has to be a multiple of 90.
      #
      # Positive values rotate the page to the left, negative values to the right. If +flatten+ is
      # +true+, the rotation is not done via the page's meta data but by "rotating" the canvas
      # itself.
      #
      # Note that the :Rotate key of a page object describes the angle in a clockwise orientation
      # but this method uses counterclockwise rotation to be consistent with other rotation methods
      # (e.g. HexaPDF::Content::Canvas#rotate).
      def rotate(angle, flatten: false)
        if angle % 90 != 0
          raise ArgumentError, "Page rotation has to be multiple of 90 degrees"
        end

        cw_angle = (self[:Rotate] - angle) % 360

        if flatten
          delete(:Rotate)
          return if cw_angle == 0

          matrix, llx, lly, urx, ury = \
            case cw_angle
            when 90
              [HexaPDF::Content::TransformationMatrix.new(0, -1, 1, 0),
               box.right, box.bottom, box.left, box.top]
            when 180
              [HexaPDF::Content::TransformationMatrix.new(-1, 0, 0, -1),
               box.right, box.top, box.left, box.bottom]
            when 270
              [HexaPDF::Content::TransformationMatrix.new(0, 1, -1, 0),
               box.left, box.top, box.right, box.bottom]
            end
          [:MediaBox, :CropBox, :BleedBox, :TrimBox, :ArtBox].each do |box|
            next unless key?(box)
            self[box].value = matrix.evaluate(llx, lly).concat(matrix.evaluate(urx, ury))
          end

          before_contents = document.add({}, stream: " q #{matrix.to_a.join(' ')} cm ")
          after_contents = document.add({}, stream: " Q ")
          self[:Contents] = [before_contents, *self[:Contents], after_contents]
        else
          self[:Rotate] = cw_angle
        end
      end

      # Returns the concatenated stream data from the content streams as binary string.
      #
      # Note: Any modifications done to the returned value *won't* be reflected in any of the
      # streams' data!
      def contents
        Array(self[:Contents]).each_with_object("".b) do |content_stream, content|
          content << " " unless content.empty?
          content << content_stream.stream
        end
      end

      # Replaces the contents of the page with the given string.
      #
      # This is done by deleting all but the first content stream and reusing this content stream;
      # or by creating a new one if no content stream exists.
      def contents=(data)
        first, *rest = self[:Contents]
        rest.each {|stream| document.delete(stream) }
        if first
          self[:Contents] = first
          document.deref(first).stream = data
        else
          self[:Contents] = document.add({Filter: :FlateDecode}, stream: data)
        end
      end

      # Returns the, possibly inherited, resource dictionary which is automatically created if it
      # doesn't exist.
      def resources
        self[:Resources] ||= document.wrap({ProcSet: [:PDF, :Text, :ImageB, :ImageC, :ImageI]},
                                           type: :XXResources)
      end

      # Processes the content streams associated with the page with the given processor object.
      #
      # See: HexaPDF::Content::Processor
      def process_contents(processor)
        self[:Resources] = {} if self[:Resources].nil?
        processor.resources = self[:Resources]
        Content::Parser.parse(contents, processor)
      end

      # Returns the index of the page in the page tree.
      def index
        idx = 0
        node = self
        while (parent_node = node[:Parent])
          parent_node[:Kids].each do |kid|
            break if kid == node
            idx += (kid.type == :Page ? 1 : kid[:Count])
          end
          node = parent_node
        end
        idx
      end

      # Returns all parent nodes of the page up to the root of the page tree.
      #
      # The direct parent is the first node in the array and the root node the last.
      def ancestor_nodes
        parent = self[:Parent]
        result = [parent]
        result << parent while (parent = parent[:Parent])
        result
      end

      # Returns the requested type of canvas for the page.
      #
      # The canvas object is cached once it is created so that its graphics state is correctly
      # retained without the need for parsing its contents.
      #
      # If the media box of the page doesn't have its origin at (0, 0), the canvas origin is
      # translated into the bottom left corner so that this detail doesn't matter when using the
      # canvas. This means that the canvas' origin is always at the bottom left corner of the media
      # box.
      #
      # type::
      #    Can either be
      #    * :page for getting the canvas for the page itself (only valid for initially empty pages)
      #    * :overlay for getting the canvas for drawing over the page contents
      #    * :underlay for getting the canvas for drawing unter the page contents
      def canvas(type: :page)
        unless [:page, :overlay, :underlay].include?(type)
          raise ArgumentError, "Invalid value for 'type', expected: :page, :underlay or :overlay"
        end
        cache_key = "#{type}_canvas".intern
        return cache(cache_key) if cached?(cache_key)

        if type == :page && key?(:Contents)
          raise HexaPDF::Error, "Cannot get the canvas for a page with contents"
        end

        create_canvas = lambda do
          Content::Canvas.new(self).tap do |canvas|
            media_box = box(:media)
            if media_box.left != 0 || media_box.bottom != 0
              canvas.translate(media_box.left, media_box.bottom)
            end
          end
        end

        contents = self[:Contents]
        if contents.nil?
          page_canvas = cache(:page_canvas, create_canvas.call)
          self[:Contents] = document.add({Filter: :FlateDecode},
                                         stream: page_canvas.stream_data)
        end

        if type == :overlay || type == :underlay
          underlay_canvas = cache(:underlay_canvas, create_canvas.call)
          overlay_canvas = cache(:overlay_canvas, create_canvas.call)

          stream = HexaPDF::StreamData.new do
            Fiber.yield(" q ")
            fiber = underlay_canvas.stream_data.fiber
            while fiber.alive? && (data = fiber.resume)
              Fiber.yield(data)
            end
            " Q q "
          end
          underlay = document.add({Filter: :FlateDecode}, stream: stream)

          stream = HexaPDF::StreamData.new do
            Fiber.yield(" Q q ")
            fiber = overlay_canvas.stream_data.fiber
            while fiber.alive? && (data = fiber.resume)
              Fiber.yield(data)
            end
            " Q "
          end
          overlay = document.add({Filter: :FlateDecode}, stream: stream)

          self[:Contents] = [underlay, *self[:Contents], overlay]
        end

        cache(cache_key)
      end

      # Creates a Form XObject from the page's dictionary and contents for the given PDF document.
      #
      # If +reference+ is true, the page's contents is referenced when possible to avoid unnecessary
      # decoding/encoding.
      #
      # Note 1: The created Form XObject is *not* added to the document automatically!
      #
      # Note 2: If +reference+ is false and if a canvas is used on this page (see #canvas), this
      # method should only be called once the contents of the page has been fully defined. The
      # reason is that during the copying of the content stream data the contents may be modified to
      # make it a fully valid content stream.
      def to_form_xobject(reference: true)
        first, *rest = self[:Contents]
        stream = if !first
                   nil
                 elsif !reference || !rest.empty? || first.raw_stream.kind_of?(String)
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

      # Flattens all or the given annotations of the page. Returns an array with all the annotations
      # that couldn't be flattened because they don't have an appearance stream.
      #
      # Flattening means making the appearances of the annotations part of the content stream of the
      # page and deleting the annotations themselves. Invisible and hidden fields are deleted but
      # not rendered into the content stream.
      #
      # If an annotation is a form field widget, only the widget will be deleted but not the form
      # field itself.
      def flatten_annotations(annotations = self[:Annots])
        return [] unless key?(:Annots)

        not_flattened = annotations.to_ary
        annotations = not_flattened & self[:Annots] if annotations != self[:Annots]
        return not_flattened if annotations.empty?

        canvas = self.canvas(type: :overlay)
        canvas.save_graphics_state
        media_box = box(:media)
        if media_box.left != 0 || media_box.bottom != 0
          canvas.translate(-media_box.left, -media_box.bottom) # revert initial translation of origin
        end

        to_delete = []
        not_flattened -= annotations
        annotations.each do |annotation|
          annotation = document.wrap(annotation, type: :Annot)
          appearance = annotation.appearance
          if annotation.flagged?(:hidden) || annotation.flagged?(:invisible)
            to_delete << annotation
            next
          elsif !appearance
            not_flattened << annotation
            next
          end

          rect = annotation[:Rect]
          box = appearance.box
          matrix = appearance[:Matrix]

          # Adjust position based on matrix
          pos = [rect.left - matrix[4], rect.bottom - matrix[5]]

          # In case of a rotation we need to counter the default translation in #xobject by adding
          # box.left and box.bottom, and then translate the origin for the rotation
          angle = (-Math.atan2(matrix[2], matrix[0]) * 180 / Math::PI).to_i
          case angle
          when 0
            # Nothing to do, no rotation
          when 90
            pos[0] += box.top + box.left
            pos[1] += -box.left + box.bottom
          when -90
            pos[0] += -box.bottom + box.left
            pos[1] += box.right + box.bottom
          when 180, -180
            pos[0] += box.right + box.left
            pos[1] += box.top + box.bottom
          else
            not_flattened << annotation
            next
          end

          width, height = (angle.abs == 90 ? [rect.height, rect.width] : [rect.width, rect.height])
          canvas.xobject(appearance, at: pos, width: width, height: height)
          to_delete << annotation
        end
        canvas.restore_graphics_state

        to_delete.each do |annotation|
          if annotation[:Subtype] == :Widget
            annotation.form_field.delete_widget(annotation)
          else
            self[:Annots].delete(annotation)
            document.delete(annotation)
          end
        end

        not_flattened
      end

      private

      # Ensures that the required inheritable fields are set.
      def perform_validation(&block)
        super
        REQUIRED_INHERITABLE_FIELDS.each do |name|
          next if self[name]
          yield("Inheritable page field #{name} not set", name == :Resources)
          resources.validate(&block) if name == :Ressources
        end
      end

    end

  end
end
