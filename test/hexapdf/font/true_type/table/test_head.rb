# -*- encoding: utf-8 -*-

require 'test_helper'
require 'stringio'
require 'hexapdf/font/true_type/table/head'

describe HexaPDF::Font::TrueType::Table::Head do
  before do
    data = [1, 0, 2, 6554, 0, 42, 0x5f0f, 0x3CF5, 3, 64].pack('n*')
    @time = Time.new(2016, 05, 01)
    data << ([(@time - HexaPDF::Font::TrueType::Table::TIME_EPOCH).to_i] * 2).pack('Q>*')
    data << [-132, -152, 3423, 4231, 3, 9, -2, 0, 0].pack('s>4n2s>3')
    io = StringIO.new(data)
    @file = Object.new
    @file.define_singleton_method(:io) { io }
    @entry = HexaPDF::Font::TrueType::Table::Directory::Entry.new('head', 0, 0, io.length)
  end

  describe "initialize" do
    it "reads the data from the associated file" do
      table = HexaPDF::Font::TrueType::Table::Head.new(@file, @entry)
      assert_equal('1.0', '%1.1f' % table.version)
      assert_equal('2.1', '%1.1f' % table.font_revision)
      assert_equal(42, table.checksum_adjustment)
      assert_equal(3, table.flags)
      assert_equal(64, table.units_per_em)
      assert_equal(@time, table.created)
      assert_equal(@time, table.modified)
      assert_equal([-132, -152, 3423, 4231], table.bbox)
      assert_equal(3, table.mac_style)
      assert_equal(9, table.smallest_readable_size)
      assert_equal(-2, table.font_direction_hint)
      assert_equal(0, table.index_to_loc_format)
    end

    it "loads some default values if no entry is given" do
      table = HexaPDF::Font::TrueType::Table::Head.new(@file)
      assert_equal(1.0, table.version.to_f)
      assert_equal(1.0, table.font_revision.to_f)
      assert_equal(0, table.checksum_adjustment)
      assert_equal(0, table.flags)
      assert_equal(64, table.units_per_em)
      assert(Time.now - table.created < 2)
      assert(Time.now - table.created < 2)
      assert_equal([0, 0, 0, 0], table.bbox)
      assert_equal(0, table.mac_style)
      assert_equal(0, table.smallest_readable_size)
      assert_equal(0, table.font_direction_hint)
      assert_equal(0, table.index_to_loc_format)
    end

    it "raises an error if the magic number is false when reading from a file" do
      @file.io.string[12, 1] = '\x5e'
      assert_raises(HexaPDF::Error) { HexaPDF::Font::TrueType::Table::Head.new(@file, @entry) }
    end

    it "raises an error if an invalid glyph format is specified when reading from a file" do
      @file.io.string[-1] = '\x5e'
      assert_raises(HexaPDF::Error) { HexaPDF::Font::TrueType::Table::Head.new(@file, @entry) }
    end
  end

  describe "checksum_valid?" do
    it "checks whether an entry's checksum is valid" do
      @file.io.string = 254.chr * 12 + [0x5F0F3CF5].pack('N') + 254.chr * 36 + 0.chr * 4
      @entry.checksum = (0xfefefefe * 11 + 0x5F0F3CF5) % 2**32
      @entry.length = @file.io.string.length
      table = HexaPDF::Font::TrueType::Table::Head.new(@file, @entry)
      assert(table.checksum_valid?)
    end

    it "raises an error if the checksum can't be verified because none is available" do
      assert_raises(HexaPDF::Error) { HexaPDF::Font::TrueType::Table::Head.new(@file).checksum_valid? }
    end
  end
end
