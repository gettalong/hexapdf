# -*- encoding: utf-8 -*-

require 'hexapdf/dictionary'
require 'hexapdf/stream'
require 'hexapdf/utils/bit_field'

module HexaPDF
  module Type

    # This class specifies metrics and other attributes of a simple font or a CID font as a
    # whole.
    #
    # See: PDF1.7 s9.8
    class FontDescriptor < Dictionary

      extend Utils::BitField

      define_field :Type,         type: Symbol,        required: true, default: :FontDescriptor
      define_field :FontName,     type: Symbol,        required: true
      define_field :FontFamily,   type: PDFByteString, version: '1.5'
      define_field :FontStretch,  type: Symbol,        version: '1.5'
      define_field :FontWeight,   type: Numeric,       version: '1.5'
      define_field :Flags,        type: Integer,       required: true
      define_field :FontBBox,     type: Rectangle
      define_field :ItalicAngle,  type: Numeric,       required: true
      define_field :Ascent,       type: Numeric
      define_field :Descent,      type: Numeric
      define_field :Leading,      type: Numeric,       default: 0
      define_field :CapHeight,    type: Numeric
      define_field :XHeight,      type: Numeric,       default: 0
      define_field :StemV,        type: Numeric
      define_field :StemH,        type: Numeric,       default: 0
      define_field :AvgWidth,     type: Numeric,       default: 0
      define_field :MaxWidth,     type: Numeric,       default: 0
      define_field :MissingWidth, type: Numeric,       default: 0
      define_field :FontFile,     type: Stream
      define_field :FontFile2,    type: Stream,        version: '1.1'
      define_field :FontFile3,    type: Stream,        version: '1.2'
      define_field :CharSet,      type: [String,       PDFByteString], version: '1.1'

      define_field :Style,        type: Dictionary
      define_field :Lang,         type: Symbol,        version: '1.5'
      define_field :FD,           type: Dictionary
      define_field :CIDSet,       type: Stream


      bit_field(:raw_flags, {fixed_pitch: 0, serif: 1, symbolic: 2, script: 3, nonsymbolic: 5,
                             italic: 6, all_cap: 16, small_cap: 17, force_bold: 18},
                lister: "flags", getter: "flagged?", setter: "flag")

      private

      # Helper method for bit field getter access.
      def raw_flags
        self[:Flags]
      end

      # Helper method for bit field setter access.
      def raw_flags=(value)
        self[:Flags] = value
      end

      def perform_validation #:nodoc:
        super
        if [self[:FontFile], self[:FontFile2], self[:FontFile3]].compact.size > 1
          yield("Only one of /FontFile, /FontFile2 or /FontFile3 may be set", false)
        end

        descent = self[:Descent]
        if descent && descent > 0
          yield("The /Descent value needs to be a negative number", false)
        end
      end

    end

  end
end
