# -*- encoding: utf-8 -*-

require 'test_helper'
require 'stringio'
require 'hexapdf/font/true_type/table/hhea'

describe HexaPDF::Font::TrueType::Table::Hhea do
  before do
    data = [1, 0, 10, 11, 12, 100, 101, 102, 115, 1, 0, 0, 0, 0, 0, 0, 0, 10].pack('n2s>3ns>11n')
    io = StringIO.new(data)
    @file = Object.new
    @file.define_singleton_method(:io) { io }
    @entry = HexaPDF::Font::TrueType::Table::Directory::Entry.new('hhea', 0, 0, io.length)
  end

  describe "initialize" do
    it "reads the data from the associated file" do
      table = HexaPDF::Font::TrueType::Table::Hhea.new(@file, @entry)
      assert_equal(1, table.version)
      assert_equal(10, table.ascent)
      assert_equal(11, table.descent)
      assert_equal(12, table.line_gap)
      assert_equal(100, table.advance_width_max)
      assert_equal(101, table.min_left_side_bearing)
      assert_equal(102, table.min_right_side_bearing)
      assert_equal(115, table.x_max_extent)
      assert_equal(1, table.caret_slope_rise)
      assert_equal(0, table.caret_slope_run)
      assert_equal(0, table.caret_offset)
      assert_equal(10, table.num_of_long_hor_metrics)
    end
  end
end
