# -*- encoding: utf-8 -*-

require 'hexapdf/dictionary'
require 'hexapdf/stream'

module HexaPDF
  module Type

    # This class specifies metrics and other attributes of a simple font or a CID font as a
    # whole.
    #
    # See: PDF1.7 s9.8
    class FontDescriptor < Dictionary

      # Mapping of flag names to flag values.
      FLAGS = {
        fixed_pitch: 1 << 0,
        serif: 1 << 1,
        symbolic: 1 << 2,
        script: 1 << 3,
        nonsymbolic: 1 << 5,
        italic: 1 << 6,
        all_cap: 1 << 16,
        small_cap: 1 << 17,
        force_bold: 1 << 18,
      }
      FLAGS.default_proc = lambda do |_hash, name|
        raise ArgumentError, "Invalid font descriptor flag name: #{name}"
      end
      FLAGS.freeze

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

      # Returns an array with symbols representing the individual flags.
      def flags
        flags_value = self[:Flags] || 0
        FLAGS.map {|name, value| flags_value & value == value ? name : nil}.compact!
      end

      # Returns +true+ if the given flag is set.
      def flagged?(name)
        (self[:Flags] || 0) & FLAGS[name] == FLAGS[name]
      end

      # Sets the given flags.
      #
      # If +clear_existing+ is +true+, then all existing flags are cleared before setting the given
      # flags.
      def flag(*names, clear_existing: true)
        self[:Flags] = 0 if clear_existing
        names.each {|name| self[:Flags] |= FLAGS[name]}
      end

      private

      def perform_validation #:nodoc:
        super
        if [self[:FontFile], self[:FontFile2], self[:FontFile3]].compact.size > 1
          yield("Only one of /FontFile, /FontFile2 or /FontFile3 may be set", false)
        end
      end

    end

  end
end
