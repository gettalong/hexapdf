# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'

describe HexaPDF::Document::Pages do
  before do
    @doc = HexaPDF::Document.new
  end

  describe "root" do
    it "returns the root of the page tree" do
      assert_same(@doc.catalog.pages, @doc.pages.root)
    end
  end

  describe "add" do
    it "adds a new empty page when no page is given" do
      page = @doc.pages.add
      assert_equal([page], @doc.pages.root[:Kids].value)
    end

    it "adds a new empty page with the given dimensions" do
      page = @doc.pages.add([0, 0, 20, 20])
      assert_same(page, @doc.pages[0])
      assert_equal([0, 0, 20, 20], @doc.pages[0].box(:media).value)
    end

    it "adds a new empty page with the given page format" do
      page = @doc.pages.add(:A4, orientation: :landscape)
      assert_same(page, @doc.pages[0])
      assert_equal([0, 0, 842, 595], @doc.pages[0].box(:media).value)
    end

    it "adds the given page to the end" do
      page = @doc.pages.add
      new_page = @doc.add({Type: :Page})
      assert_same(new_page, @doc.pages.add(new_page))
      assert_equal([page, new_page], @doc.pages.root[:Kids].value)
    end

    it "fails if an unknown page format is given" do
      assert_raises(HexaPDF::Error) { @doc.pages.add(:A953) }
    end
  end

  describe "<<" do
    it "works like add but always needs a page returns self" do
      page1 = @doc.add({Type: :Page})
      page2 = @doc.add({Type: :Page})
      @doc.pages << page1 << page2
      assert_equal([page1, page2], @doc.pages.root[:Kids].value)
    end
  end

  describe "insert" do
    before do
      @doc.pages.add
      @doc.pages.add
      @doc.pages.add
    end

    it "insert a new page at a given index" do
      page = @doc.pages.insert(2)
      assert_equal(page, @doc.pages.root[:Kids][2])
    end

    it "insert a given page at a given index" do
      new_page = @doc.add({Type: :Page})
      assert_same(new_page, @doc.pages.insert(2, new_page))
      assert_equal(new_page, @doc.pages.root[:Kids][2])
    end
  end

  describe "delete" do
    it "deletes a given page" do
      page1 = @doc.pages.add
      page2 = @doc.pages.add

      @doc.pages.delete(page1)
      assert_equal([page2], @doc.pages.root[:Kids].value)
    end
  end

  describe "delete_at" do
    it "deletes a page at a given index" do
      page1 = @doc.pages.add
      @doc.pages.add
      page3 = @doc.pages.add
      @doc.pages.delete_at(1)
      assert_equal([page1, page3], @doc.pages.root[:Kids].value)
    end
  end

  describe "[]" do
    it "returns the page at the given index" do
      page1 = @doc.pages.add
      page2 = @doc.pages.add
      page3 = @doc.pages.add

      assert_equal(page1, @doc.pages[0])
      assert_equal(page2, @doc.pages[1])
      assert_equal(page3, @doc.pages[2])
      assert_nil(@doc.pages[3])
      assert_equal(page3, @doc.pages[-1])
      assert_equal(page2, @doc.pages[-2])
      assert_equal(page1, @doc.pages[-3])
      assert_nil(@doc.pages[-4])
    end
  end

  describe "each" do
    it "iterates over all pages" do
      page1 = @doc.pages.add
      page2 = @doc.pages.add
      page3 = @doc.pages.add
      assert_equal([page1, page2, page3], @doc.pages.to_a)
    end
  end

  describe "count" do
    it "returns the number of pages in the page tree" do
      assert_equal(0, @doc.pages.count)
      @doc.pages.add
      @doc.pages.add
      @doc.pages.add
      assert_equal(3, @doc.pages.count)
    end
  end
end
