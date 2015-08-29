# -*- encoding: utf-8 -*-

require 'hexapdf/pdf/stream'

module HexaPDF
  module PDF
    module Type

      # Represents a form XObject of a PDF document.
      #
      # See: PDF1.7 s8.10
      class Form < Stream

        define_field :Type,          type: Symbol,     default: :XObject
        define_field :Subtype,       type: Symbol,     required: true, default: :Form
        define_field :FormType,      type: Integer,    default: 1
        define_field :BBox,          type: Array,      required: true
        define_field :Matrix,        type: Array
        define_field :Resources,     type: :Resources, version: '1.2'
        define_field :Group,         type: Dictionary, version: '1.4'
        define_field :Ref,           type: Dictionary, version: '1.4'
        define_field :Metadata,      type: Stream,     version: '1.4'
        define_field :PieceInfo,     type: Dictionary, version: '1.3'
        define_field :LastModified,  type: PDFDate,    version: '1.3'
        define_field :StructParent,  type: Integer,    version: '1.3'
        define_field :StructParents, type: Integer,    version: '1.3'
        define_field :OPI,           type: Dictionary, version: '1.2'
        define_field :OC,            type: Dictionary, version: '1.5'

        # Returns the path to the PDF file that was used when creating the form object.
        #
        # This value is only set when the form object was created by using the image loading
        # facility (i.e. when treating a single page PDF file as image) and not when the form object
        # was created in any other way (i.e. manually created or already part of a loaded PDF file).
        attr_accessor :source_path

        # Returns the rectangle defining the bounding box of the form.
        def box
          self[:BBox]
        end

        # Returns the contents of the form XObject.
        #
        # Note: This is the same as #stream but here for interface compatibility with Page.
        def contents
          stream
        end

        # Replaces the contents of the form XObject with the given string.
        #
        #
        # Note: This is the same as #stream= but here for interface compatibility with Page.
        def contents=(data)
          self.stream = data
        end

        # Returns the resource dictionary which is automatically created if it doesn't exist.
        def resources
          self[:Resources] ||= document.wrap({}, type: :Resources)
        end

      end

    end
  end
end
