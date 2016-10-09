# -*- encoding: utf-8 -*-

require 'test_helper'
require 'stringio'
require 'hexapdf/font/true_type/table/os2'

describe HexaPDF::Font::TrueType::Table::OS2 do
  before do
    data = [5, -1, 2, 3, -4, -5, -6, -7, -8, -9, -10, -11, -12, -13, -14, -15,
            'PANOSPANOS', 16, 17, 'VEND', 16, 17, 18, -19, -20, -21, 22, 23, 24, -25, -26,
            27, 28, 29, 30, 31].pack('ns>n2s>12a10Q>2a4n3s>3n2Q>s>2n5')
    @file = Object.new
    @file.define_singleton_method(:io) { @io ||= StringIO.new(data) }
    @entry = HexaPDF::Font::TrueType::Table::Directory::Entry.new('OS/2', 0, 0, @file.io.length)
  end

  describe "initialize" do
    it "reads the data from the associated file" do
      table = HexaPDF::Font::TrueType::Table::OS2.new(@file, @entry)
      assert_equal(5, table.version)
      assert_equal(-1, table.x_avg_char_width)
      assert_equal(200, table.weight_class)
      assert_equal(3, table.width_class)
      assert_equal(-4, table.type)
      assert_equal(-5, table.subscript_x_size)
      assert_equal(-6, table.subscript_y_size)
      assert_equal(-7, table.subscript_x_offset)
      assert_equal(-8, table.subscript_y_offset)
      assert_equal(-9, table.superscript_x_size)
      assert_equal(-10, table.superscript_y_size)
      assert_equal(-11, table.superscript_x_offset)
      assert_equal(-12, table.superscript_y_offset)
      assert_equal(-13, table.strikeout_size)
      assert_equal(-14, table.strikeout_position)
      assert_equal(-15, table.family_class)
      assert_equal('PANOSPANOS'.b, table.panose)
      assert_equal(16 << 64 & 17, table.unicode_range)
      assert_equal('VEND'.b, table.vendor_id)
      assert_equal(16, table.selection)
      assert_equal(17, table.first_char_index)
      assert_equal(18, table.last_char_index)
      assert_equal(-19, table.typo_ascender)
      assert_equal(-20, table.typo_descender)
      assert_equal(-21, table.typo_line_gap)
      assert_equal(22, table.win_ascent)
      assert_equal(23, table.win_descent)
      assert_equal(24, table.code_page_range)
      assert_equal(-25, table.x_height)
      assert_equal(-26, table.cap_height)
      assert_equal(27, table.default_char)
      assert_equal(28, table.break_char)
      assert_equal(29, table.max_context)
      assert_equal(30, table.lower_point_size)
      assert_equal(31, table.upper_point_size)
    end

    it "loads some default values if no entry is given" do
      table = HexaPDF::Font::TrueType::Table::OS2.new(@file)
      assert_equal(5, table.version)
      assert_equal(''.b, table.panose)
      assert_equal('    '.b, table.vendor_id)
      assert_equal(0, table.default_char)
    end
  end
end
