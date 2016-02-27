# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/type/page_tree_node'

describe HexaPDF::Type::PageTreeNode do
  before do
    @doc = HexaPDF::Document.new
    @root = @doc.add(Type: :Pages)
  end

  # Defines the following page tree:
  #
  #   @root
  #     @kid1
  #       @kid11
  #         @pages[0]
  #         @pages[1]
  #       @kid12
  #         @pages[2]
  #         @pages[3]
  #         @pages[4]
  #     @pages[5]
  #     @kid2
  #       @pages[6]
  #       @pages[7]
  def define_multilevel_page_tree
    @pages = 8.times.map { @doc.add(Type: :Page) }
    @kid1 = @doc.add(Type: :Pages, Parent: @root, Count: 5)
    @kid11 = @doc.add(Type: :Pages, Parent: @kid1)
    @kid11.add_page(@pages[0])
    @kid11.add_page(@pages[1])
    @kid12 = @doc.add(Type: :Pages, Parent: @kid1)
    @kid12.add_page(@pages[2])
    @kid12.add_page(@pages[3])
    @kid12.add_page(@pages[4])
    @kid1[:Kids] << @kid11 << @kid12
    @root[:Kids] << @kid1

    @pages[5][:Parent] = @root
    @root[:Kids] << @pages[5]

    @kid2 = @doc.add(Type: :Pages, Parent: @root)
    @kid2.add_page(@pages[6])
    @kid2.add_page(@pages[7])
    @root[:Kids] << @kid2
    @root[:Count] = 8
  end

  describe "page" do
    before do
      define_multilevel_page_tree
    end

    it "returns the page for a given index" do
      assert_equal(@pages[0], @root.page(0))
      assert_equal(@pages[3], @root.page(3))
      assert_equal(@pages[5], @root.page(5))
      assert_equal(@pages[7], @root.page(7))
    end

    it "works with negative indicies counting backwards from the end" do
      assert_equal(@pages[0], @root.page(-8))
      assert_equal(@pages[3], @root.page(-5))
      assert_equal(@pages[5], @root.page(-3))
      assert_equal(@pages[7], @root.page(-1))
    end

    it "returns nil for bad indices" do
      assert_nil(@root.page(20))
      assert_nil(@root.page(-20))
    end
  end

  describe "insert_page" do
    it "uses an empty new page when none is provided" do
      page = @root.insert_page(3)
      assert_equal([page], @root[:Kids])
      assert_equal(1, @root.page_count)
      assert_equal(:Page, page[:Type])
      assert_equal(@root, page[:Parent])
      assert_kind_of(HexaPDF::Rectangle, page[:MediaBox])
      assert_equal({}, page[:Resources].value)
      refute(@root.value.key?(:Parent))
    end

    it "doesn't create a /Resources entry if an inherited one exists" do
      @root[:Resources] = {Font: {F1: nil}}
      page = @root.insert_page(3)
      assert_equal(@root[:Resources], page[:Resources])
    end

    it "inserts the provided page at the given index" do
      page = @doc.wrap(Type: :Page)
      assert_equal(page, @root.insert_page(3, page))
      assert_equal([page], @root[:Kids])
      assert_equal(@root, page[:Parent])
      refute(@root.value.key?(:Parent))
    end

    it "inserts multiple pages correctly in an empty root node" do
      page3 = @root.insert_page(5)
      page1 = @root.insert_page(0)
      page2 = @root.insert_page(1)
      assert_equal([page1, page2, page3], @root[:Kids])
      assert_equal(3, @root.page_count)
    end

    it "inserts multiple pages correctly in a multilevel page tree" do
      define_multilevel_page_tree
      page = @root.insert_page(2)
      assert_equal([@pages[0], @pages[1], page], @kid11[:Kids])
      assert_equal(3, @kid11.page_count)
      assert_equal(6, @kid1.page_count)
      assert_equal(9, @root.page_count)

      page = @root.insert_page(4)
      assert_equal([@pages[2], page, @pages[3], @pages[4]], @kid12[:Kids])
      assert_equal(4, @kid12.page_count)
      assert_equal(7, @kid1.page_count)
      assert_equal(10, @root.page_count)

      page = @root.insert_page(8)
      assert_equal([@kid1, @pages[5], page, @kid2], @root[:Kids])
      assert_equal(11, @root.page_count)

      page = @root.insert_page(100)
      assert_equal([@kid1, @pages[5], @root[:Kids][2], @kid2, page], @root[:Kids])
      assert_equal(12, @root.page_count)
    end

    it "allows negative indices to be specified" do
      define_multilevel_page_tree
      page = @root.insert_page(-1)
      assert_equal(page, @root[:Kids].last)

      page = @root.insert_page(-4)
      assert_equal(page, @root[:Kids][2])
    end

    it "fails when adding a new page if the media box config option is invalid" do
      @doc.config['page.default_media_box'] = :S101
      assert_raises(HexaPDF::Error) { @root.add_page }
    end
  end

  describe "delete_page" do
    before do
      define_multilevel_page_tree
    end

    it "does nothing if the page index is not valid" do
      assert_nil(@root.delete_page(20))
      assert_nil(@root.delete_page(-20))
      assert_equal(8, @root.page_count)
    end

    it "deletes the correct page" do
      assert_equal(@pages[2], @root.delete_page(2))
      assert_equal(2, @kid12.page_count)
      assert_equal(4, @kid1.page_count)
      assert_equal(7, @root.page_count)

      assert_equal(@pages[5], @root.delete_page(4))
      assert_equal(6, @root.page_count)
    end

    it "deletes intermediate page tree nodes if they contain only one child after deletion" do
      assert_equal(@pages[0], @root.delete_page(0))
      assert_equal(4, @kid1.page_count)
      assert_equal(7, @root.page_count)
      assert_nil(@doc.object(@kid11).value)
      assert_equal(@pages[1], @kid1[:Kids][0])
    end

    it "deletes intermediate page tree nodes if they don't have any children after deletion" do
      node = @doc.add(Type: :Pages, Parent: @root)
      page = node.add_page
      @root[:Kids] << node
      @root[:Count] += 1

      assert_equal(page, @root.delete_page(-1))
      assert_nil(@doc.object(node).value)
      refute_equal(node, @root[:Kids].last)
      assert(8, @root.page_count)
    end
  end

  describe "each_page" do
    before do
      define_multilevel_page_tree
    end

    it "iterates over a simple, one-level page tree" do
      assert_equal([@pages[2], @pages[3], @pages[4]], @kid12.each_page.to_a)
    end

    it "iterates over a multilevel page tree" do
      assert_equal(@pages, @root.each_page.to_a)
    end
  end

  describe "validation" do
    it "corrects faulty /Count entries" do
      define_multilevel_page_tree
      root_count = @root.page_count
      @root[:Count] = -5
      kid_count = @kid12.page_count
      @kid12[:Count] = 100

      called_msg = ''
      refute(@root.validate(auto_correct: false) {|msg, _| called_msg = msg})
      assert_match(/Count.*invalid/, called_msg)

      assert(@root.validate)
      assert_equal(root_count, @root.page_count)
      assert_equal(kid_count, @kid12.page_count)
    end

    it "corrects faulty /Parent entries" do
      define_multilevel_page_tree
      @kid12.delete(:Parent)
      @kid2.delete(:Parent)

      called_msg = ''
      refute(@root.validate(auto_correct: false) {|msg, _| called_msg = msg})
      assert_match(/Parent.*invalid/, called_msg)

      assert(@root.validate)
      assert_equal(@kid1, @kid12[:Parent])
      assert_equal(@root, @kid2[:Parent])
    end

    it "removes invalid objects from the page tree (like null objects)" do
      define_multilevel_page_tree
      assert(@root.validate(auto_correct: false) {|m, _| p m})

      @doc.delete(@pages[3])
      refute(@root.validate(auto_correct: false)) do |msg, _|
        assert_match(/invalid object/i, msg)
      end
      assert(@root.validate)
      assert_equal(2, @kid12[:Count])
      assert_equal([@pages[2], @pages[4]], @kid12[:Kids])
    end

    it "needs at least one page node" do
      refute(@root.validate(auto_correct: false))
      assert(@root.validate)
      assert_equal(1, @root.page_count)
    end
  end
end
