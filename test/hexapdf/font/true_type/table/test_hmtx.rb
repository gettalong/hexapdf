# -*- encoding: utf-8 -*-

require 'test_helper'
require 'stringio'
require 'hexapdf/font/true_type/table/hhea'
require 'hexapdf/font/true_type/table/hmtx'

describe HexaPDF::Font::TrueType::Table::Hhea do
  before do
    data = [1, -2, 3, -4, 5, -6].pack('ns>ns>s>2')
    io = StringIO.new(data)
    @file = Object.new
    @file.define_singleton_method(:io) { io }
    hhea = Object.new
    hhea.define_singleton_method(:num_of_long_hor_metrics) { 2 }
    @file.define_singleton_method(:[]) {|_arg| hhea }
    @entry = HexaPDF::Font::TrueType::Table::Directory::Entry.new('hmtx', 0, 0, io.length)
  end

  describe "initialize" do
    it "reads the data from the associated file" do
      table = HexaPDF::Font::TrueType::Table::Hmtx.new(@file, @entry)
      assert_equal(1, table[0].advance_width)
      assert_equal(-2, table[0].left_side_bearing)
      assert_equal(3, table[1].advance_width)
      assert_equal(-4, table[1].left_side_bearing)
      assert_equal(3, table[2].advance_width)
      assert_equal(5, table[2].left_side_bearing)
      assert_equal(3, table[3].advance_width)
      assert_equal(-6, table[3].left_side_bearing)
    end
  end
end
