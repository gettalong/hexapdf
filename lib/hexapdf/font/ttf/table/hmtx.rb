# -*- encoding: utf-8 -*-

require 'hexapdf/font/ttf/table'

module HexaPDF
  module Font
    module TTF
      class Table

        # The 'hmtx' (horizontal metrics) table contains information for the horizontal layout
        # of each glyph in the font.
        #
        # See: https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6hmtx.html
        class Hmtx < Table

          # Contains the horizontal layout information for one glyph, namely the :advance_width and
          # the :left_side_bearing.
          Metric = Struct.new(:advance_width, :left_side_bearing)

          # An array of Metric objects, one for each glyph in the font.
          attr_accessor :horizontal_metrics

          # Returns the Metric object for the give glyph ID.
          def [](glyph_id)
            @horizontal_metrics[glyph_id]
          end

          private

          def parse_table #:nodoc:
            nr_entries = file[:hhea].num_of_long_hor_metrics
            @horizontal_metrics = nr_entries.times.map { Metric.new(*read_formatted(4, 'ns>')) }
            last_advance_width = @horizontal_metrics[-1].advance_width
            read_formatted(directory_entry.length - 4 * nr_entries, 's>*').map do |lsb|
              @horizontal_metrics << Metric.new(last_advance_width, lsb)
            end
          end

          def load_default #:nodoc:
            @horizontal_metrics = []
          end

        end

      end
    end
  end
end
