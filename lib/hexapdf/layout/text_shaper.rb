# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2026 Thomas Leitner
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
require 'hexapdf/layout/numeric_refinements'

HARFBUZZ_AVAILABLE = begin
                       require 'harfbuzz'
                       true
                     rescue LoadError
                     end

module HexaPDF
  module Layout

    using NumericRefinements

    # This class is used to perform text shaping, i.e. changing the position of glyphs (e.g. for
    # kerning) or substituting one or more glyphs for other glyphs (e.g. for ligatures).
    #
    # The class contains two shaping engines: A very limited custom one and one based on
    # HarfBuzz. Which one is used for shaping can be selected via the Style#shaping_engine property.
    #
    # The custom implementation is always used for Type1 fonts and supports kerning and ligature
    # substitution. It also supports the 'kern' table for TrueType fonts if HarfBuzz is not used.
    #
    # For complex scripts or the need of special font features it is recommended to use the shaping
    # engine based on HarfBuzz, even though it is slightly slower. For it to work the
    # +harfbuzz-ruby+ gem needs to be installed. OpenType features can be activated and deactivated
    # using Style#font_features.
    class TextShaper

      # Shapes the given text fragment. Returns either the in-place modified fragment or, for
      # complex shaping, an array of fragments.
      #
      # The style properties Style#shaping_engine, Style#font_features, Style#font_script,
      # Style#language and Style#direction are used for shaping.
      def shape_text(text_fragment)
        font = text_fragment.style.font
        if text_fragment.style.shaping_engine == :harfbuzz && font.font_type == :TrueType
          unless HARFBUZZ_AVAILABLE
            raise HexaPDF::Error, "Shaping engine harfbuzz required but the needed Rubygem " \
              "harfbuzz-ruby is not available"
          end
          return harfbuzz_shape_text(text_fragment)
        end

        if text_fragment.style.font_features[:liga] && font.wrapped_font.features.include?(:liga)
          if font.font_type == :Type1
            process_type1_ligatures(text_fragment)
          end
          text_fragment.clear_cache
        end
        if text_fragment.style.font_features[:kern] && font.wrapped_font.features.include?(:kern)
          case font.font_type
          when :TrueType
            process_true_type_kerning(text_fragment)
          when :Type1
            process_type1_kerning(text_fragment)
          end
          text_fragment.clear_cache
        end

        text_fragment
      end

      private

      # Shapes the text fragment with HarfBuzz.
      def harfbuzz_shape_text(text_fragment, text = nil)
        text ||= text_fragment.items.map(&:str).join
        style = text_fragment.style

        # Cache the used main Harfbuzz font objects
        hb_font = style.font.pdf_object.document.cache('harfbuzz', style.font.filename) do
          blob = HarfBuzz::Blob.from_file!(style.font.filename)
          face = HarfBuzz::Face.new(blob, 0)
          HarfBuzz::Font.new(face)
        end

        # Prepare the buffer and then shape the text. We are using cluster level 1 as this is the
        # recommended level.
        buffer = HarfBuzz::Buffer.new
        buffer.add_utf8(text)
        buffer.cluster_level = 1
        buffer.direction = style.direction
        buffer.script = style.font_script if style.font_script?
        buffer.language = style.language if style.language?
        buffer.guess_segment_properties
        HarfBuzz.shape(hb_font, buffer, HarfBuzz::Feature.from_hash(style.font_features))

        # Prepare the iteration over the shaping result. The final output will either be
        # +text_fragment+ (no non-zero y_offsets) or +result+ containing at least two TextFragment
        # instances.
        result = nil
        font = style.font
        fragment = text_fragment
        fragment.clear_cache
        items = text_fragment.items.clear
        last_cluster = nil
        last_y_offset = 0
        buffer.each_glyph_with_clusters do |glyph_id, cluster, next_cluster, x_advance, y_advance, x_offset, y_offset|
          advance = (x_advance - x_offset) * font.scaling_factor

          # 1. Determine the source characters for each glyph via their cluster numbers. If two or
          # more glyphs have the same cluster number, the first gets the resulting string while the
          # rest map to an empty string. Otherwise copying from the PDF would result in multiple
          # copies of the resulting string.
          str = (cluster == last_cluster ? '' : text.byteslice(cluster...(next_cluster || text.bytesize)))

          # 2. Handle invalid glyphs with id=0 by mapping them to an InvalidGlyph instance
          if glyph_id.zero?
            glyph = font.decode_codepoint(str.ord)
            advance = glyph.width
          else
            glyph = font.glyph(glyph_id, str)
          end

          # 3. Handle differing y_offsets by creating TextFragment instances with appropriate text
          # rise properties.
          if y_offset != last_y_offset
            (result ||= []) << fragment
            items = []
            if y_offset.zero?
              fragment = text_fragment.dup_attributes(items)
            else
              fragment = TextFragment.new(items, style.dup, properties: text_fragment.properties)
              fragment.style.text_rise += y_offset * font.scaling_factor * fragment.style.font_size *
                                          fragment.style.font.pdf_object.glyph_scaling_factor
            end
          end

          # 4. Handle the correct x-positioning using x_offset. Also addjust the horizontal advance
          # based on the glyph's fixed advance width as well as x_advance and x_offset (via
          # +advance+).
          items << -x_offset * font.scaling_factor unless x_offset.zero?
          items << glyph
          items << glyph.width - advance if glyph.width - advance != 0

          last_cluster = cluster
          last_y_offset = y_offset
        end

        result ? result.append(fragment) : text_fragment
      end

      # Processes the text fragment and substitutes ligatures.
      def process_type1_ligatures(text_fragment)
        items = text_fragment.items
        font = text_fragment.style.font
        pairs = font.wrapped_font.metrics.ligature_pairs
        each_glyph_pair(items) do |left_item, right_item, left, right|
          if (ligature = pairs.dig(left_item.id, right_item.id))
            items[left..right] = font.glyph(ligature)
            left
          else
            right
          end
        end
      end

      # Processes the text fragment and does pair-wise kerning.
      def process_type1_kerning(text_fragment)
        pairs = text_fragment.style.font.wrapped_font.metrics.kerning_pairs
        items = text_fragment.items
        each_glyph_pair(items) do |left_item, right_item, left, right|
          if (left + 1 == right) && (kerning = pairs.dig(left_item.id, right_item.id))
            items.insert(right, -kerning)
            right + 1
          else
            right
          end
        end
      end

      # Processes the text fragment and does pair-wise kerning.
      def process_true_type_kerning(text_fragment)
        font = text_fragment.style.font
        table = font.wrapped_font[:kern].horizontal_kerning_subtable
        items = text_fragment.items
        each_glyph_pair(items) do |left_item, right_item, left, right|
          if (left + 1 == right) && (kerning = table.kern(left_item.id, right_item.id))
            items.insert(right, -kerning * font.scaling_factor)
            right + 1
          else
            right
          end
        end
      end

      # :call-seq:
      #    each_glyph_pair(items) {|left_item, right_item, left, right}
      #
      # Yields each pair of glyphs of the items array (so left must not be right + 1 if between two
      # glyphs are one or more kerning values).
      #
      # The return value of the block is taken as the next *left* item position.
      def each_glyph_pair(items)
        left = 0
        left_item = items[left]
        right = 1
        right_item = items[right]
        while left_item && right_item
          if left_item.kind_of?(Numeric)
            left += 1
            left_item = items[left]
            right = left + 1
          elsif right_item.kind_of?(Numeric)
            right += 1
          else
            left = yield(left_item, right_item, left, right)
            left_item = items[left]
            right = left + 1
          end
          right_item = items[right]
        end
      end

    end

  end
end
