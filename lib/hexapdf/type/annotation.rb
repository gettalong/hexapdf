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

require 'hexapdf/dictionary'
require 'hexapdf/utils/bit_field'

module HexaPDF
  module Type

    # Annotations are used to associate objects like notes, sounds or movies with a location on a
    # PDF page or allow the user to interact with a PDF document using a keyboard or mouse.
    #
    # See: PDF1.7 s12.5
    class Annotation < Dictionary

      # The appearance dictionary references appearance streams for various use cases.
      #
      # Each appearance can either be an XObject or a dictionary mapping names to XObjects. The
      # latter is used when the appearance depends on the state of the annotation, e.g. a check box
      # widget that can be checked or unchecked.
      #
      # See: PDF1.7 s12.5.5
      class AppearanceDictionary < Dictionary

        define_type :XXAppearanceDictionary

        define_field :N, type: [Dictionary, Stream], required: true
        define_field :R, type: [Dictionary, Stream]
        define_field :D, type: [Dictionary, Stream]

        # The annotation's normal appearance.
        def normal_appearance
          self[:N]
        end

        # The rollover appearance which should be used when the cursor is moved into the active area
        # of the annotation without pressing a button.
        def rollover_appearance
          self[:R] || self[:N]
        end

        # The down appearance which should be used when the mouse button is pressed or held down
        # inside the active area of the annotation.
        def down_appearance
          self[:D] || self[:N]
        end

      end

      # Border style dictionary used by various annotation types.
      #
      # See: PDF1.7 s12.5.4
      class Border < Dictionary

        define_type :Border

        define_field :Type, type: Symbol, default: type
        define_field :W,    type: [Integer, Float], default: 1
        define_field :S,    type: Symbol, default: :S, allowed_values: [:S, :D, :B, :I, :U]
        define_field :D,    type: PDFArray, default: [3]

      end

      extend Utils::BitField

      define_type :Annot

      define_field :Type,         type: Symbol, default: type
      define_field :Subtype,      type: Symbol, required: true
      define_field :Rect,         type: Rectangle, required: true
      define_field :Contents,     type: String
      define_field :P,            type: Dictionary, version: '1.3'
      define_field :NM,           type: String, version: '1.4'
      define_field :M,            type: PDFDate, version: '1.1'
      define_field :F,            type: Integer, default: 0, version: '1.1'
      define_field :AP,           type: :XXAppearanceDictionary, version: '1.2'
      define_field :AS,           type: Symbol, version: '1.2'
      define_field :Border,       type: PDFArray, default: [0, 0, 1]
      define_field :C,            type: PDFArray, version: '1.1'
      define_field :StructParent, type: Integer, version: '1.3'
      define_field :OC,           type: Dictionary, version: '1.5'

      bit_field(:raw_flags, {invisible: 0, hidden: 1, print: 2, no_zoom: 3, no_rotate: 4,
                             no_view: 5, read_only: 6, locked: 7, toggle_no_view: 8,
                             locked_contents: 9},
                lister: "flags", getter: "flagged?", setter: "flag", unsetter: "unflag")

      # Returns +true+ because annotation objects must always be indirect objects.
      def must_be_indirect?
        true
      end

      # Returns the AppearanceDictionary instance associated with the annotation or +nil+ if none is
      # set.
      def appearance_dict
        self[:AP]
      end

      # Returns the annotation's appearance stream of the given type (:normal, :rollover, or :down)
      # or +nil+ if it doesn't exist.
      #
      # The appearance state is taken into account if necessary.
      def appearance(type = :normal)
        entry = appearance_dict&.send("#{type}_appearance")
        if entry.kind_of?(HexaPDF::Dictionary) && !entry.kind_of?(HexaPDF::Stream)
          entry = entry[self[:AS]]
        end
        return unless entry.kind_of?(HexaPDF::Stream)

        if entry.type == :XObject && entry[:Subtype] == :Form
          entry
        elsif (entry[:Type].nil? || entry[:Type] == :XObject) &&
            (entry[:Subtype].nil? || entry[:Subtype] == :Form) && entry[:BBox]
          document.wrap(entry, type: :XObject, subtype: :Form)
        end
      end
      alias appearance? appearance

      private

      # Helper method for bit field getter access.
      def raw_flags
        self[:F]
      end

      # Helper method for bit field setter access.
      def raw_flags=(value)
        self[:F] = value
      end

    end

  end
end
