# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/font/ttf/table/directory'

describe HexaPDF::Font::TTF::Table::Directory do
  before do
    io = StringIO.new("TEST\x00\x01\x00\x00\x00\x00\x00\x00" \
                      "CUST----\x00\x00\x00\x1C\x00\x00\x00\x05ENTRY".b)
    @file = Object.new
    @file.define_singleton_method(:io) { io }
    @self_entry = HexaPDF::Font::TTF::Table::Directory::SELF_ENTRY
  end

  it "has a dummy entry referring to itself" do
    assert_equal(0, @self_entry.offset)
    assert_equal(12, @self_entry.length)
  end

  describe "initialize" do
    it "loads the table entries from the IO" do
      dir = HexaPDF::Font::TTF::Table::Directory.new(@file, @self_entry)
      entry = dir.entry('CUST')
      assert_equal('CUST', entry.tag)
      assert_equal('----'.unpack('N').first, entry.checksum)
      assert_equal(28, entry.offset)
      assert_equal(5, entry.length)
    end

    it "loads the default values if no entry is given" do
      dir = HexaPDF::Font::TTF::Table::Directory.new(@file)
      assert_equal(0, dir.instance_eval { @tables }.length)
    end
  end
end
