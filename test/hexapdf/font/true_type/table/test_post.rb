# -*- encoding: utf-8 -*-

require 'test_helper'
require 'stringio'
require 'hexapdf/font/true_type/table/post'

describe HexaPDF::Font::TrueType::Table::Post do
  before do
    data = [1, 0, 1, 0, -142, 15, 0, 0, 0, 0, 0].pack('n4s>2N5')
    @file = Object.new
    @file.define_singleton_method(:io) { @io ||= StringIO.new(data) }
    @entry = HexaPDF::Font::TrueType::Table::Directory::Entry.new('post', 0, 0, @file.io.length)
  end

  describe "initialize" do
    it "reads the format 1 data from the associated file" do
      table = HexaPDF::Font::TrueType::Table::Post.new(@file, @entry)
      assert_equal(1, table.format)
      assert_equal(1, table.italic_angle)
      assert_equal(-142, table.underline_position)
      assert_equal(15, table.underline_thickness)
      assert_equal(0, table.is_fixed_pitch)
      refute(table.is_fixed_pitch?)
      assert_equal(0, table.min_mem_type42)
      assert_equal(0, table.max_mem_type42)
      assert_equal(0, table.min_mem_type1)
      assert_equal(0, table.max_mem_type1)
      assert_equal('.notdef', table[0])
      assert_equal('A', table[36])
      assert_equal('Delta', table[168])
      assert_equal('.notdef', table[1000])
    end

    it "reads the format 2 data from the associated file" do
      @file.io.string[0, 2] = [2].pack('n')
      @file.io.string << ([260, 0] + (1..257).to_a.reverse + [258, 259]).pack('n*')
      @file.io.string << [4, "hexa", 3, "pdf"].pack('CA4CA3')
      @entry.length = @file.io.length
      table = HexaPDF::Font::TrueType::Table::Post.new(@file, @entry)
      assert_equal(2, table.format)
      assert_equal('.notdef', table[0])
      assert_equal('A', table[258 - 36])
      assert_equal('Delta', table[258 - 168])
      assert_equal('hexa', table[258])
      assert_equal('pdf', table[259])
      assert_equal('.notdef', table[1000])
    end

    it "reads the format 3 data from the associated file" do
      @file.io.string[0, 2] = [3].pack('n')
      table = HexaPDF::Font::TrueType::Table::Post.new(@file, @entry)
      assert_equal(3, table.format)
      assert_equal('.notdef', table[0])
      assert_equal('.notdef', table[36])
      assert_equal('.notdef', table[1000])
    end

    it "reads the format 4 data from the associated file" do
      @file.io.string[0, 2] = [4].pack('n')
      @file.io.string << [0x1234, 0x5678].pack('n*')
      @entry.length = @file.io.length
      table = HexaPDF::Font::TrueType::Table::Post.new(@file, @entry)
      assert_equal(4, table.format)
      assert_equal(0x1234, table[0])
      assert_equal(0x5678, table[1])
      assert_equal(0xFFFF, table[2])
      assert_equal(0xFFFF, table[36])
      assert_equal(0xFFFF, table[1_000_000])
    end

    it "loads some default values if no entry is given" do
      table = HexaPDF::Font::TrueType::Table::Post.new(@file)
      assert_equal(1, table.format)
      assert_equal(0, table.italic_angle)
      assert_equal(0, table.underline_position)
      assert_equal(0, table.underline_thickness)
      assert_equal(0, table.is_fixed_pitch)
      assert_equal(0, table.min_mem_type42)
      assert_equal(0, table.max_mem_type42)
      assert_equal(0, table.min_mem_type1)
      assert_equal(0, table.max_mem_type1)
    end

    it "raises an error if an unsupported format is given" do
      @file.io.string[0, 2] = [5].pack('n')
      assert_raises(HexaPDF::Error) { HexaPDF::Font::TrueType::Table::Post.new(@file, @entry) }
    end
  end
end
