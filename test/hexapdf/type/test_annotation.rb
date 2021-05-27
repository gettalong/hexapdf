# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/type/annotation'

describe HexaPDF::Type::Annotation::AppearanceDictionary do
  before do
    @doc = HexaPDF::Document.new
    @ap = @doc.add({N: :n, D: :d, R: :r}, type: :XXAppearanceDictionary)
  end

  it "resolves the normal appearance" do
    assert_equal(:n, @ap.normal_appearance)
  end

  it "resolves the rollover appearance" do
    assert_equal(:r, @ap.rollover_appearance)
    @ap.delete(:R)
    assert_equal(:n, @ap.rollover_appearance)
  end

  it "resolves the down appearance" do
    assert_equal(:d, @ap.down_appearance)
    @ap.delete(:D)
    assert_equal(:n, @ap.down_appearance)
  end
end

describe HexaPDF::Type::Annotation do
  before do
    @doc = HexaPDF::Document.new
    @annot = @doc.add({Type: :Annot, F: 0b100011})
  end

  it "must always be indirect" do
    @annot.must_be_indirect = false
    assert(@annot.must_be_indirect?)
  end

  it "returns the appearance dictionary" do
    @annot[:AP] = :yes
    assert_equal(:yes, @annot.appearance_dict)
  end

  it "returns the appearance stream of the given type" do
    assert_nil(@annot.appearance)

    @annot[:AP] = {N: {}}
    assert_nil(@annot.appearance)

    stream = @doc.wrap({}, stream: '')
    @annot[:AP][:N] = stream
    assert_nil(@annot.appearance)

    stream[:BBox] = [1, 2, 3, 4]
    appearance = @annot.appearance
    assert_same(stream.data, appearance.data)
    assert_equal(:Form, appearance[:Subtype])

    @annot[:AP][:N] = {X: {}}
    assert_nil(@annot.appearance)

    @annot[:AS] = :X
    @annot[:AP][:N][:X] = stream
    assert_same(stream.data, @annot.appearance.data)

    @annot[:AP][:D] = {X: stream}
    assert_same(stream.data, @annot.appearance(:down).data)
  end

  describe "flags" do
    it "returns all flags" do
      assert_equal([:invisible, :hidden, :no_view], @annot.flags)
    end
  end

  describe "flagged?" do
    it "returns true if the given flag is set" do
      assert(@annot.flagged?(:hidden))
      refute(@annot.flagged?(:locked))
    end

    it "raises an error if an unknown flag name is provided" do
      assert_raises(ArgumentError) { @annot.flagged?(:unknown) }
    end
  end

  describe "flag" do
    it "sets the given flag bits" do
      @annot.flag(:locked)
      assert_equal([:invisible, :hidden, :no_view, :locked], @annot.flags)
      @annot.flag(:locked, clear_existing: true)
      assert_equal([:locked], @annot.flags)
    end
  end
end
