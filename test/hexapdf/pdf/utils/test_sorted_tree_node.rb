# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/document'
require 'hexapdf/pdf/name_tree_node'
require 'hexapdf/pdf/number_tree_node'

describe HexaPDF::PDF::Utils::SortedTreeNode do

  before do
    @doc = HexaPDF::PDF::Document.new
    @root = HexaPDF::PDF::NameTreeNode.new({}, document: @doc)
  end

  def add_multilevel_entries
    @kid11 = HexaPDF::PDF::NameTreeNode.new({Limits: ['c', 'f'], Names: ['c', 1, 'f', 1]},
                                           document: @doc)
    @kid12 = HexaPDF::PDF::NameTreeNode.new({Limits: ['i', 'm'], Names: ['i', 1, 'm', 1]},
                                           document: @doc)
    @kid1 = HexaPDF::PDF::NameTreeNode.new({Limits: ['c', 'm'], Kids: [@kid11, @kid12]},
                                          document: @doc)
    @kid21 = HexaPDF::PDF::NameTreeNode.new({Limits: ['o', 'q'], Names: ['o', 1, 'q', 1]},
                                           document: @doc)
    @kid221 = HexaPDF::PDF::NameTreeNode.new({Limits: ['s', 'u'], Names: ['s', 1, 'u', 1]},
                                             document: @doc)
    @kid22 = HexaPDF::PDF::NameTreeNode.new({Limits: ['s', 'u'], Kids: [@kid221]},
                                           document: @doc)
    @kid2 = HexaPDF::PDF::NameTreeNode.new({Limits: ['o', 'u'], Kids: [@kid21, @kid22]},
                                          document: @doc)
    @root[:Kids] = [@kid1, @kid2]
  end

  describe "add" do
    it "works with the root node alone" do
      @root.add('c', 1)
      @root.add('a', 2)
      @root.add('e', 3)
      assert_equal(['a', 2, 'c', 1, 'e', 3], @root[:Names])
      refute(@root[:Limits])
    end

    it "replaces an existing entry" do
      @root.add('a', 2)
      @root.add('a', 5)
      assert_equal(['a', 5], @root[:Names])
    end

    it "works with one level of intermediate nodes" do
      kid1 = HexaPDF::PDF::NameTreeNode.new({Limits: ['m', 'm'], Names: ['m', 1]}, document: @doc)
      kid2 = HexaPDF::PDF::NameTreeNode.new({Limits: ['t', 't'], Names: ['t', 1]}, document: @doc)
      @root[:Kids] = [kid1, kid2]
      @root.add('c', 1)
      @root.add('d', 1)
      @root.add('p', 1)
      @root.add('r', 1)
      @root.add('u', 1)
      assert_equal(['c', 'm'], kid1[:Limits])
      assert_equal(['c', 1, 'd', 1, 'm', 1], kid1[:Names])
      assert_equal(['p', 'u'], kid2[:Limits])
      assert_equal(['p', 1, 'r', 1, 't', 1, 'u', 1], kid2[:Names])
    end

    it "works with multiple levels of intermediate nodes" do
      add_multilevel_entries
      @root.add('a', 1)
      @root.add('e', 1)
      @root.add('g', 1)
      @root.add('j', 1)
      @root.add('n', 1)
      @root.add('p', 1)
      @root.add('r', 1)
      @root.add('v', 1)
      assert_equal(['a', 'm'], @kid1[:Limits])
      assert_equal(['a', 'f'], @kid11[:Limits])
      assert_equal(['a', 1, 'c', 1, 'e', 1, 'f', 1], @kid11[:Names])
      assert_equal(['g', 'm'], @kid12[:Limits])
      assert_equal(['g', 1, 'i', 1, 'j', 1, 'm', 1], @kid12[:Names])
      assert_equal(['n', 'v'], @kid2[:Limits])
      assert_equal(['n', 'q'], @kid21[:Limits])
      assert_equal(['n', 1, 'o', 1, 'p', 1, 'q', 1], @kid21[:Names])
      assert_equal(['r', 'v'], @kid22[:Limits])
      assert_equal(['r', 'v'], @kid221[:Limits])
      assert_equal(['r', 1, 's', 1, 'u', 1, 'v', 1], @kid221[:Names])
    end

    it "splits nodes if needed" do
      @doc.config['sorted_tree.max_leaf_node_size'] = 4
      %w[a c e m k i g d b l j f h].each {|key| @root.add(key, 1)}
      refute(@root.value.key?(:Limits))
      refute(@root.value.key?(:Names))
      assert_equal(6, @root[:Kids].size)
      assert_equal(['a', 1, 'b', 1], @root[:Kids][0][:Names])
      assert_equal(['c', 1, 'd', 1], @root[:Kids][1][:Names])
      assert_equal(['e', 1, 'f', 1], @root[:Kids][2][:Names])
      assert_equal(['g', 1, 'h', 1, 'i', 1], @root[:Kids][3][:Names])
      assert_equal(['j', 1, 'k', 1], @root[:Kids][4][:Names])
      assert_equal(['l', 1, 'm', 1], @root[:Kids][5][:Names])
    end

    it "fails if not called on the root node" do
      @root[:Limits] = ['a', 'c']
      assert_raises(HexaPDF::Error) { @root.add('b', 1) }
    end

    it "fails if the key is not a string" do
      assert_raises(HexaPDF::Error) { @root.add(5, 1) }
    end
  end

  describe "find" do
    it "finds the correct entry" do
      add_multilevel_entries
      assert_equal(1, @root.find('i'))
      assert_equal(1, @root.find('q'))
    end

    it "returns nil for non-existing entries" do
      add_multilevel_entries
      assert_nil(@root.find('non'))
    end
  end

  it "works equally well with a NumberTreeNode" do
    root = HexaPDF::PDF::NumberTreeNode.new({}, document: @doc)
    root.add(2, 1)
    root.add(1, 2)
    assert_equal([1, 2, 2, 1], root[:Nums])
  end

end
