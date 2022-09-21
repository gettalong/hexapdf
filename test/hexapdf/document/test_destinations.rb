# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'

describe HexaPDF::Document::Destinations::Destination do
  def destination(dest)
    HexaPDF::Document::Destinations::Destination.new(dest)
  end

  describe "self.valid?" do
    before do
      @klass = HexaPDF::Document::Destinations::Destination
    end

    it "validates the type" do
      assert(@klass.valid?([5, :Fit]))
      refute(@klass.valid?([5, :FitNone]))
    end

    it "validates the page entry" do
      assert(@klass.valid?([5, :Fit]))
      refute(@klass.valid?([HexaPDF::Dictionary.new({Type: :Page}), :FitNone]))
    end

    it "validates the arguments" do
      assert(@klass.valid?([5, :FitH, 5]))
      refute(@klass.valid?([5, :FitH, :other]))
    end
  end

  it "can be asked whether the referenced page is in a remote document" do
    assert(destination([5, :Fit]).remote?)
    refute(destination([HexaPDF::Dictionary.new({}), :Fit]).remote?)
  end

  it "returns the page object" do
    assert_equal(:page, destination([:page, :Fit]).page)
  end

  it "can validate a destination" do
    assert(destination([5, :Fit]).valid?)
  end

  describe "type :xyz" do
    before do
      @dest = destination([:page, :XYZ, :left, :top, :zoom])
    end

    it "returns the type of the destination" do
      assert_equal(:xyz, @dest.type)
    end

    it "returns the argument left" do
      assert_equal(:left, @dest.left)
    end

    it "returns the argument top" do
      assert_equal(:top, @dest.top)
    end

    it "returns the argument zoom" do
      assert_equal(:zoom, @dest.zoom)
    end

    it "raises an error if the bottom and right properties are accessed" do
      assert_raises(HexaPDF::Error) { @dest.bottom }
      assert_raises(HexaPDF::Error) { @dest.right }
    end
  end

  describe "type :fit_page" do
    before do
      @dest = destination([:page, :Fit])
    end

    it "returns the type of the destination" do
      assert_equal(:fit_page, @dest.type)
    end

    it "raises an error if the top, left, bottom, right, zoom properties are accessed" do
      assert_raises(HexaPDF::Error) { @dest.top }
      assert_raises(HexaPDF::Error) { @dest.left }
      assert_raises(HexaPDF::Error) { @dest.bottom }
      assert_raises(HexaPDF::Error) { @dest.right }
      assert_raises(HexaPDF::Error) { @dest.zoom }
    end
  end

  describe "type :fit_page_horizontal" do
    before do
      @dest = destination([:page, :FitH, :top])
    end

    it "returns the type of the destination" do
      assert_equal(:fit_page_horizontal, @dest.type)
    end

    it "returns the argument top" do
      assert_equal(:top, @dest.top)
    end

    it "raises an error if the left, bottom, right, zoom properties are accessed" do
      assert_raises(HexaPDF::Error) { @dest.left }
      assert_raises(HexaPDF::Error) { @dest.bottom }
      assert_raises(HexaPDF::Error) { @dest.right }
      assert_raises(HexaPDF::Error) { @dest.zoom }
    end
  end

  describe "type :fit_page_vertical" do
    before do
      @dest = destination([:page, :FitV, :left])
    end

    it "returns the type of the destination" do
      assert_equal(:fit_page_vertical, @dest.type)
    end

    it "returns the argument left" do
      assert_equal(:left, @dest.left)
    end

    it "raises an error if the top, bottom, right, zoom properties are accessed" do
      assert_raises(HexaPDF::Error) { @dest.top }
      assert_raises(HexaPDF::Error) { @dest.bottom }
      assert_raises(HexaPDF::Error) { @dest.right }
      assert_raises(HexaPDF::Error) { @dest.zoom }
    end
  end

  describe "type :fit_rectangle" do
    before do
      @dest = destination([:page, :FitR, :left, :bottom, :right, :top])
    end

    it "returns the type of the destination" do
      assert_equal(:fit_rectangle, @dest.type)
    end

    it "returns the argument left" do
      assert_equal(:left, @dest.left)
    end

    it "returns the argument top" do
      assert_equal(:top, @dest.top)
    end

    it "returns the argument right" do
      assert_equal(:right, @dest.right)
    end

    it "returns the argument bottom" do
      assert_equal(:bottom, @dest.bottom)
    end

    it "raises an error if the zoom property is accessed" do
      assert_raises(HexaPDF::Error) { @dest.zoom }
    end
  end

  describe "type :fit_bounding_box" do
    before do
      @dest = destination([:page, :FitB])
    end

    it "returns the type of the destination" do
      assert_equal(:fit_bounding_box, @dest.type)
    end

    it "raises an error if the bottom and right properties are accessed" do
      assert_raises(HexaPDF::Error) { @dest.left }
      assert_raises(HexaPDF::Error) { @dest.bottom }
      assert_raises(HexaPDF::Error) { @dest.right }
      assert_raises(HexaPDF::Error) { @dest.top }
      assert_raises(HexaPDF::Error) { @dest.zoom }
    end
  end

  describe "type :fit_bounding_box_horizontal" do
    before do
      @dest = destination([:page, :FitBH, :top])
    end

    it "returns the type of the destination" do
      assert_equal(:fit_bounding_box_horizontal, @dest.type)
    end

    it "returns the argument top" do
      assert_equal(:top, @dest.top)
    end

    it "raises an error if the left, bottom, right, zoom properties are accessed" do
      assert_raises(HexaPDF::Error) { @dest.left }
      assert_raises(HexaPDF::Error) { @dest.bottom }
      assert_raises(HexaPDF::Error) { @dest.right }
      assert_raises(HexaPDF::Error) { @dest.zoom }
    end
  end

  describe "type :fit_bounding_box_vertical::" do
    before do
      @dest = destination([:page, :FitBV, :left])
    end

    it "returns the type of the destination" do
      assert_equal(:fit_bounding_box_vertical, @dest.type)
    end

    it "returns the argument left" do
      assert_equal(:left, @dest.left)
    end

    it "raises an error if the left, bottom, right, zoom properties are accessed" do
      assert_raises(HexaPDF::Error) { @dest.top }
      assert_raises(HexaPDF::Error) { @dest.bottom }
      assert_raises(HexaPDF::Error) { @dest.right }
      assert_raises(HexaPDF::Error) { @dest.zoom }
    end
  end
end

describe HexaPDF::Document::Destinations do
  before do
    @doc = HexaPDF::Document.new
    @page = @doc.pages.add
  end

  describe "create" do
    it "creates the destination using a HexaDPF destination name" do
      dest = @doc.destinations.create(:fit_page_horizontal, @page, top: 5, name: 'fph')
      assert_equal('fph', dest)
      dest = @doc.destinations['fph']
      assert_equal(:FitH, dest[1])
      assert_equal(5, dest[2])
    end

    it "creates the destination using a PDF internal name" do
      dest = @doc.destinations.create(:FitH, @page, top: 5)
      assert_equal(:FitH, dest[1])
      assert_equal(5, dest[2])
    end

    it "returns the given destination array" do
      dest = [@page, :Fit]
      assert_same(dest, @doc.destinations.create(dest))
    end

    it "returns the name for the given destination array" do
      assert_equal("page", @doc.destinations.create([@page, :Fit], name: "page"))
    end
  end

  describe "create_xyz" do
    it "creates the destination" do
      dest = @doc.destinations.create_xyz(@page, left: 1, top: 2, zoom: 3)
      assert_equal([@page, :XYZ, 1, 2, 3], dest)
    end

    it "creates the destination and registers it under the given name" do
      dest = @doc.destinations.create_xyz(@page, name: 'xyz')
      assert_equal([@page, :XYZ, nil, nil, nil], @doc.destinations[dest])
    end
  end

  describe "create_fit_page" do
    it "creates the destination" do
      dest = @doc.destinations.create_fit_page(@page)
      assert_equal([@page, :Fit], dest)
    end

    it "creates the destination and registers it under the given name" do
      dest = @doc.destinations.create_fit_page(@page, name: 'xyz')
      assert_equal([@page, :Fit], @doc.destinations[dest])
    end
  end

  describe "create_fit_page_horizontal" do
    it "creates the destination" do
      dest = @doc.destinations.create_fit_page_horizontal(@page, top: 2)
      assert_equal([@page, :FitH, 2], dest)
    end

    it "creates the destination and registers it under the given name" do
      dest = @doc.destinations.create_fit_page_horizontal(@page, name: 'xyz')
      assert_equal([@page, :FitH, nil], @doc.destinations[dest])
    end
  end

  describe "create_fit_page_vertical" do
    it "creates the destination" do
      dest = @doc.destinations.create_fit_page_vertical(@page, left: 2)
      assert_equal([@page, :FitV, 2], dest)
    end

    it "creates the destination and registers it under the given name" do
      dest = @doc.destinations.create_fit_page_vertical(@page, name: 'xyz')
      assert_equal([@page, :FitV, nil], @doc.destinations[dest])
    end
  end

  describe "create_fit_rectangle" do
    it "creates the destination" do
      dest = @doc.destinations.create_fit_rectangle(@page, left: 1, bottom: 2, right: 3, top: 4)
      assert_equal([@page, :FitR, 1, 2, 3, 4], dest)
    end

    it "creates the destination and registers it under the given name" do
      dest = @doc.destinations.create_fit_rectangle(@page, name: 'xyz', left: 1, bottom: 2, right: 3, top: 4)
      assert_equal([@page, :FitR, 1, 2, 3, 4], @doc.destinations[dest])
    end
  end

  describe "create_fit_bounding_box" do
    it "creates the destination" do
      dest = @doc.destinations.create_fit_bounding_box(@page)
      assert_equal([@page, :FitB], dest)
    end

    it "creates the destination and registers it under the given name" do
      dest = @doc.destinations.create_fit_bounding_box(@page, name: 'xyz')
      assert_equal([@page, :FitB], @doc.destinations[dest])
    end
  end

  describe "create_fit_bounding_box_horizontal" do
    it "creates the destination" do
      dest = @doc.destinations.create_fit_bounding_box_horizontal(@page, top: 2)
      assert_equal([@page, :FitBH, 2], dest)
    end

    it "creates the destination and registers it under the given name" do
      dest = @doc.destinations.create_fit_bounding_box_horizontal(@page, name: 'xyz')
      assert_equal([@page, :FitBH, nil], @doc.destinations[dest])
    end
  end

  describe "create_fit_bounding_box_vertical" do
    it "creates the destination" do
      dest = @doc.destinations.create_fit_bounding_box_vertical(@page, left: 2)
      assert_equal([@page, :FitBV, 2], dest)
    end

    it "creates the destination and registers it under the given name" do
      dest = @doc.destinations.create_fit_bounding_box_vertical(@page, name: 'xyz')
      assert_equal([@page, :FitBV, nil], @doc.destinations[dest])
    end
  end

  it "adds a destination array to the destinations name tree and allows to retrieve it" do
    @doc.destinations.add('abc', [:page, :Fit])
    assert_equal([:page, :Fit], @doc.destinations['abc'])
  end

  it "deletes a named destination" do
    @doc.destinations.add('abc', [:page, :Fit])
    assert(@doc.destinations['abc'])
    @doc.destinations.delete('abc')
    refute(@doc.destinations['abc'])
  end

  describe "each" do
    before do
      3.times {|i| @doc.destinations.add("abc#{i}", [:page, :Fit]) }
    end

    it "returns an enumerator if no block is given" do
      enum = @doc.destinations.each
      assert_equal('abc0', enum.next.first)
      assert_equal('abc1', enum.next.first)
      assert_equal('abc2', enum.next.first)
      assert_raises(StopIteration) { enum.next }
    end

    it "iterates over all name-destination pairs in order" do
      result = [
        ['abc0', :fit_page],
        ['abc1', :fit_page],
        ['abc2', :fit_page],
      ]
      @doc.destinations.each do |name, dest|
        exp_name, exp_type = result.shift
        assert_equal(exp_name, name)
        assert_equal(exp_type, dest.type)
      end
    end
  end
end
