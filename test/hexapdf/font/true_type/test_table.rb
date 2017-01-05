# -*- encoding: utf-8 -*-

require 'test_helper'
require 'stringio'
require 'hexapdf/font/true_type/table'
require_relative 'common'

describe HexaPDF::Font::TrueType::Table do
  before do
    io = StringIO.new('some string')
    @file = Object.new
    @file.define_singleton_method(:io) { io }
    @entry = HexaPDF::Font::TrueType::Table::Directory::Entry.new('tagg', 0, 0, @file.io.string.length)
  end

  describe "initialize" do
    it "reads the data from the associated file" do
      table = TestHelper::TrueTypeTestTable.new(@file, @entry)
      assert_equal(@file.io.string, table.data)
    end
  end

  describe "checksum_valid?" do
    it "checks whether an entry's checksum is valid" do
      @file.io.string = 254.chr * 17 + 0.chr * 3
      @entry.checksum = (0xfefefefe * 4 + 0xfe000000) % 2**32
      @entry.length = @file.io.string.length
      table = TestHelper::TrueTypeTestTable.new(@file, @entry)
      assert(table.checksum_valid?)
    end
  end

  describe "read_fixed" do
    it "works for unsigned values" do
      @file.io.string = [1, 20480].pack('nn')
      @entry.length = @file.io.string.length
      table = TestHelper::TrueTypeTestTable.new(@file, @entry)
      assert_equal(1 + Rational(20480, 65536), table.send(:read_fixed))
    end

    it "works for signed values" do
      @file.io.string = [-1, 20480].pack('nn')
      @entry.length = @file.io.string.length
      table = TestHelper::TrueTypeTestTable.new(@file, @entry)
      assert_equal(-1 + Rational(20480, 65536), table.send(:read_fixed))
    end
  end
end
