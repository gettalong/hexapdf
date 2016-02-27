# -*- encoding: utf-8 -*-

require 'hexapdf/stream'

module HexaPDF
  module Type

    # Represents an image XObject of a PDF document.
    #
    # See: PDF1.7 s8.8
    class Image < Stream

      define_field :Type,             type: Symbol,          default: :XObject
      define_field :Subtype,          type: Symbol,          required: true, default: :Image
      define_field :Width,            type: Integer,         required: true
      define_field :Height,           type: Integer,         required: true
      define_field :ColorSpace,       type: [Symbol, Array]
      define_field :BitsPerComponent, type: Integer
      define_field :Intent,           type: Symbol,          version: '1.1'
      define_field :ImageMask,        type: Boolean,         default: false
      define_field :Mask,             type: [Stream, Array], version: '1.3'
      define_field :Decode,           type: Array
      define_field :Interpolate,      type: Boolean,         default: false
      define_field :Alternates,       type: Array,           version: '1.3'
      define_field :SMask,            type: Stream,          version: '1.4'
      define_field :SMaskInData,      type: Integer,         version: '1.5'
      define_field :StructParent,     type: Integer,         version: '1.3'
      define_field :ID,               type: PDFByteString,   version: '1.3'
      define_field :OPI,              type: Dictionary,      version: '1.2'
      define_field :Metadata,         type: Stream,          version: '1.4'
      define_field :OC,               type: Dictionary,      version: '1.5'

      # Returns the source path that was used when creating the image object.
      #
      # This value is only set when the image object was created by using the image loading
      # facility and not when the image is part of a loaded PDF file.
      attr_accessor :source_path

    end

  end
end
