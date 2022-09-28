# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/type/outline_item'

describe HexaPDF::Type::OutlineItem do
  before do
    @doc = HexaPDF::Document.new
    @item = @doc.add({Title: "root", Count: 0}, type: :XXOutlineItem)
  end

  describe "title" do
    it "returns the set title" do
      @item[:Title] = 'Test'
      assert_equal('Test', @item.title)
    end

    it "sets the title to the given value" do
      @item.title('Test')
      assert_equal('Test', @item[:Title])
    end
  end

  describe "text_color" do
    it "returns the default color if none is set" do
      assert_equal([0, 0, 0], @item.text_color.components)
    end

    it "returns the set color" do
      @item[:C] = [0, 0.5, 1]
      assert_equal([0, 0.5, 1], @item.text_color.components)
    end

    it "sets the text color to the given value" do
      @item.text_color([51, 51, 255])
      assert_equal([0.2, 0.2, 1], @item[:C])
    end

    it "fails if a color in another color space is set" do
      assert_raises(ArgumentError) { @item.text_color(5) }
    end
  end

  describe "destination" do
    it "returns the set destination" do
      @item[:Dest] = [5, :Fit]
      assert_equal([5, :Fit], @item.destination)
    end

    it "sets the destination to the given value" do
      @item.destination(@doc.pages.add)
      assert_equal([@doc.pages[0], :Fit], @item[:Dest])
    end

    it "deletes an existing action entry when setting a value" do
      @item[:A] = {S: :GoTo}
      @item.destination(@doc.pages.add)
      refute(@item.key?(:A))
    end
  end

  describe "action" do
    it "returns the set action" do
      @item[:A] = {S: :GoTo}
      assert_equal({S: :GoTo}, @item.action.value)
    end

    it "sets the action to the given value" do
      @item.action({S: :GoTo})
      assert_equal({S: :GoTo}, @item[:A].value)
    end

    it "deletes an existing destination entry when setting a value" do
      @item[:Dest] = [1, :Fit]
      @item.action({S: :GoTo})
      refute(@item.key?(:Dest))
    end
  end

  describe "add" do
    it "returns the created item" do
      new_item = @item.add_item("Test")
      assert_equal("Test", new_item.title)
      assert_equal(0, new_item[:Count])
      assert_same(@item, new_item[:Parent])
      assert(new_item.indirect?)
    end

    it "sets the item's text color" do
      new_item = @item.add_item("Test", text_color: "red")
      assert_equal([1, 0, 0], new_item.text_color.components)
    end

    it "sets the item's flags" do
      new_item = @item.add_item("Test", flags: [:bold, :italic])
      assert_equal([:italic, :bold], new_item.flags)
    end

    it "doesn't set the item's /Count when it should not be open" do
      new_item = @item.add_item("Test", open: false)
      refute(new_item.key?(:Count))
    end

    it "sets the item's destination if given" do
      new_item = @item.add_item("Test", destination: @doc.pages.add)
      assert_equal([@doc.pages[0], :Fit], new_item.destination)
    end

    it "sets the item's action if given" do
      new_item = @item.add_item("Test", action: {S: :GoTo, D: [1, :Fit]})
      assert_equal({S: :GoTo, D: [1, :Fit]}, new_item.action.value)
    end

    it "yields the item" do
      yielded_item = nil
      new_item = @item.add_item("Test") {|i| yielded_item = i }
      assert_same(new_item, yielded_item)
    end

    describe "position" do
      it "works for an empty item" do
        new_item = @item.add_item("Test")
        assert_same(new_item, @item[:First])
        assert_same(new_item, @item[:Last])
        assert_nil(new_item[:Next])
        assert_nil(new_item[:Prev])
      end

      it "inserts an item at the last position with at least one existing sub-item" do
        first_item = @item.add_item("Test")
        second_item = @item.add_item("Test", position: :last)
        assert_same(first_item, @item[:First])
        assert_same(second_item, @item[:Last])
        assert_same(second_item, first_item[:Next])
        assert_same(first_item, second_item[:Prev])
      end

      it "inserts an item at the first position with at least one existing sub-item" do
        second_item = @item.add_item("Test")
        first_item = @item.add_item("Test", position: :first)
        assert_same(first_item, @item[:First])
        assert_same(second_item, @item[:Last])
        assert_same(second_item, first_item[:Next])
        assert_same(first_item, second_item[:Prev])
      end

      it "inserts an item at an arbitrary positive index" do
        5.times {|i| @item.add_item("Test#{i}") }
        @item.add_item("Test", position: 3)
        item = @item[:First]
        %w[Test0 Test1 Test2 Test Test3 Test4].each do |title|
          assert_equal(title, item.title)
          item = item[:Next]
        end
      end

      it "inserts an item at an arbitrary negative index" do
        5.times {|i| @item.add_item("Test#{i}") }
        @item.add_item("Test", position: -3)
        item = @item[:First]
        %w[Test0 Test1 Test2 Test Test3 Test4].each do |title|
          assert_equal(title, item.title)
          item = item[:Next]
        end
      end

      it "raises an out of bounds error for invalid integer values" do
        5.times {|i| @item.add_item("Test#{i}") }
        assert_raises(ArgumentError) { @item.add_item("Test", position: 10) }
        assert_raises(ArgumentError) { @item.add_item("Test", position: -10) }
      end

      it "raises an error for an invalid value" do
        assert_raises(ArgumentError) { @item.add_item("Test", position: :luck) }
      end
    end

    it "calculcates the /Count values correctly" do
      [
        [[true, true], [6, 4, 0, 1, 0, 0, 0]],
        [[true, false], [5, 3, 0, -1, 0, 0, 0]],
        [[false, true], [2, -4, 0, 1, 0, 0, 0]],
        [[false, false], [2, -3, 0, -1, 0, 0, 0]],
      ].each do |(states, result)|
        # reset list
        @item[:First] = @item[:Last] = nil
        @item[:Count] = 0

        items = [@item]
        @item.add_item("Document", open: states[0]) do |idoc|
          items << idoc
          items << idoc.add_item("Section 1", open: false)
          idoc.add_item("Section 2", open: states[1]) do |isec|
            items << isec
            items << isec.add_item("Subsection 1")
          end
          items << idoc.add_item("Section 3")
        end
        items << @item.add_item("Summary")
        items.each_with_index {|item, index| assert_equal(result.shift, item[:Count] || 0, "item#{index}") }
      end
    end
  end

  it "recursively iterates over all descendant items" do
    @item.add_item("Item1") do |item1|
      item1.add_item("Item2")
      item1.add_item("Item3") do |item3|
        item3.add_item("Item4")
      end
      item1.add_item("Item5")
    end
    assert_equal(%w[Item1 Item2 Item3 Item4 Item5], @item.each_item.map(&:title))
  end

  describe "perform_validation" do
    before do
      5.times { @item.add_item("Test1") }
      @item[:Parent] = @doc.add({})
    end

    it "fixes a missing /First entry" do
      @item.delete(:First)
      called = false
      @item.validate do |msg, correctable, _|
        called = true
        assert_match(/missing an endpoint reference/, msg)
        assert(correctable)
      end
      assert(called)
    end

    it "fixes a missing /Last entry" do
      @item.delete(:Last)
      called = false
      @item.validate do |msg, correctable, _|
        called = true
        assert_match(/missing an endpoint reference/, msg)
        assert(correctable)
      end
      assert(called)
    end

    it "deletes the /Count entry if no /First and /Last entries exist" do
      @item.delete(:Last)
      @item.delete(:First)
      assert_equal(5, @item[:Count])
      @item.validate do |msg, correctable, _|
        assert_match(/\/Count set but no descendants/, msg)
        assert(correctable)
      end
      refute(@item.key?(:Count))
    end

    it "fails validation if the previous item's /Next points somewhere else" do
      item = @item[:First][:Next]
      item[:Prev][:Next] = item[:Next]
      item.validate do |msg, correctable, _|
        assert_match(/\/Prev points to item whose \/Next points somewhere else/, msg)
        refute(correctable)
      end
    end

    it "corrects the previous item's missing /Next entry" do
      item = @item[:First][:Next]
      item[:Prev].delete(:Next)
      item.validate do |msg, correctable, _|
        assert_match(/\/Prev points to item without \/Next/, msg)
        assert(correctable)
      end
    end

    it "fails validation if the next item's /Prev points somewhere else" do
      item = @item[:First][:Next]
      item[:Next][:Prev] = item[:Prev]
      item.validate do |msg, correctable, _|
        assert_match(/\/Next points to item whose \/Prev points somewhere else/, msg)
        refute(correctable)
      end
    end

    it "corrects the next item's missing /Prev entry" do
      item = @item[:First][:Next]
      item[:Next].delete(:Prev)
      item.validate do |msg, correctable, _|
        assert_match(/\/Next points to item without \/Prev/, msg)
        assert(correctable)
      end
    end
  end
end
