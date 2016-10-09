# -*- encoding: utf-8 -*-

require 'test_helper'
require 'stringio'
require 'hexapdf/font/true_type/font'
require_relative 'common'

describe HexaPDF::Font::TrueType::Font do
  before do
    @io = StringIO.new("TEST\x00\x01\x00\x00\x00\x00\x00\x00" \
                       "TEST----\x00\x00\x00\x1C\x00\x00\x00\x05ENTRY".b)
    @font = HexaPDF::Font::TrueType::Font.new(io: @io)
    @font.config['font.true_type.table_mapping'][:TEST] = TestHelper::TrueTypeTestTable.name
  end

  describe "[]" do
    it "returns a named table" do
      table = @font[:TEST]
      assert_equal('ENTRY', table.data)
    end

    it "always returns the same table instance" do
      assert_same(@font[:TEST], @font[:TEST])
    end

    it "returns a generic table if no mapping exists" do
      @font.config['font.true_type.table_mapping'].delete(:TEST)
      assert_kind_of(HexaPDF::Font::TrueType::Table, @font[:TEST])
    end

    it "returns nil if the named table doesn't exist in the file" do
      assert_nil(@font[:OTHE])
    end
  end

  describe "add_table" do
    it "returns the existing table if one exists" do
      assert_same(@font[:TEST], @font.add_table(:TEST))
    end

    it "creates a new table instance if needed" do
      assert_kind_of(HexaPDF::Font::TrueType::Table::Head, @font.add_table(:head))
    end
  end

  describe "getter methods" do
    before do
      @font.add_table(:name)
      @font.add_table(:post)
      @font.add_table(:head)
      @font.add_table(:hhea)
      @font.add_table(:"OS/2")
    end

    it "returns the postscript name" do
      @font[:name].add(:postscript_name, "name")
      assert_equal("name", @font.font_name)
    end

    it "returns the full name" do
      @font[:name].add(:font_name, "name")
      assert_equal("name", @font.full_name)
    end

    it "returns the family name" do
      @font[:name].add(:font_family, "name")
      assert_equal("name", @font.family_name)
    end

    it "returns the font's weight" do
      @font[:"OS/2"].weight_class = 400
      assert_equal(400, @font.weight)
    end

    it "returns the font's bounding box" do
      @font[:head].bbox = [0, 1, 2, 3]
      assert_equal([0, 1, 2, 3], @font.bounding_box)
    end

    it "returns the font's cap height" do
      @font[:"OS/2"].cap_height = 832
      assert_equal(832, @font.cap_height)
    end

    it "returns the font's x height" do
      @font[:"OS/2"].x_height = 642
      assert_equal(642, @font.x_height)
    end

    it "returns the font's ascender" do
      @font[:"OS/2"].typo_ascender = 800
      @font[:hhea].ascent = 790
      assert_equal(800, @font.ascender)
      @font.instance_eval { @tables.delete(:"OS/2") }
      assert_equal(790, @font.ascender)
    end

    it "returns the font's descender" do
      @font[:"OS/2"].typo_descender = -200
      @font[:hhea].descent = -180
      assert_equal(-200, @font.descender)
      @font.instance_eval { @tables.delete(:"OS/2") }
      assert_equal(-180, @font.descender)
    end

    it "returns the font's italic angle" do
      @font[:post].italic_angle = Rational(325, 10)
      assert_equal(32.5, @font.italic_angle)
    end

    it "returns the font's dominant vertical stem width" do
      @font[:"OS/2"].weight_class = 400
      assert_equal(80, @font.dominant_vertical_stem_width)
    end
  end

  it "is able to return the ID of the missing glyph" do
    assert_equal(0, @font.missing_glyph_id)
  end
end
