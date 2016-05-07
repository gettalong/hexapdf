# -*- encoding: utf-8 -*-

require 'test_helper'
require 'stringio'
require 'hexapdf/font/ttf/table/head'
require 'hexapdf/font/ttf/table/loca'

describe HexaPDF::Font::TTF::Table::Loca do
  before do
    @file = Object.new
    @file.define_singleton_method(:io) { @io ||= StringIO.new('') }
    head = HexaPDF::Font::TTF::Table::Head.new(@file)
    head.index_to_loc_format = 0
    @file.define_singleton_method(:[]) {|_arg| head }
    @entry = HexaPDF::Font::TTF::Table::Directory::Entry.new('loca', 0, 0, @file.io.length)
  end

  describe "initialize" do
    it "reads the data in short format from the associated file" do
      @file.io.string = [0, 10, 30, 50, 90].pack('n*')
      @entry.length = @file.io.length
      table = HexaPDF::Font::TTF::Table::Loca.new(@file, @entry)
      assert_equal([0, 20, 60, 100, 180], table.offsets)
      assert_equal(0, table.offset(0))
      assert_equal(100, table.offset(3))
      assert_equal(20, table.length(0))
      assert_equal(80, table.length(3))
    end

    it "reads the data in long format from the associated file" do
      @file.io.string = [0, 10, 30, 50, 90].pack('N*')
      @file[:head].index_to_loc_format = 1
      @entry.length = @file.io.length
      table = HexaPDF::Font::TTF::Table::Loca.new(@file, @entry)
      assert_equal([0, 10, 30, 50, 90], table.offsets)
    end

    it "loads some default values if no entry is given" do
      table = HexaPDF::Font::TTF::Table::Loca.new(@file)
      assert_equal([], table.offsets)
    end
  end
end
