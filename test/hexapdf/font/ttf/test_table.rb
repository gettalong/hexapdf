# -*- encoding: utf-8 -*-

require 'test_helper'
require 'stringio'
require 'hexapdf/font/ttf/table'
require_relative 'common'

describe HexaPDF::Font::TTF::Table do
  before do
    io = StringIO.new('some string')
    @file = Object.new
    @file.define_singleton_method(:io) { io }
    @entry = HexaPDF::Font::TTF::Table::Directory::Entry.new('tagg', 0, 0, @file.io.string.length)
  end

  describe "initialize" do
    it "reads the data from the associated file" do
      table = TestHelper::TTFTestTable.new(@file, @entry)
      assert_equal(@file.io.string, table.data)
    end

    it "loads some default values if no entry is given" do
      table = TestHelper::TTFTestTable.new(@file)
      assert_equal('default', table.data)
    end
  end

  describe "checksum_valid?" do
    it "checks whether an entry's checksum is valid" do
      @file.io.string = 254.chr * 17 + 0.chr * 3
      @entry.checksum = (0xfefefefe * 4 + 0xfe000000) % 2**32
      @entry.length = @file.io.string.length
      table = TestHelper::TTFTestTable.new(@file, @entry)
      assert(table.checksum_valid?)
    end

    it "raises an error if the checksum can't be verified because none is available" do
      assert_raises(HexaPDF::Error) { TestHelper::TTFTestTable.new(@file).checksum_valid? }
    end
  end
end
