# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/document'
require 'hexapdf/pdf/task/optimize'

describe HexaPDF::PDF::Task::Optimize do

  class TestType < HexaPDF::PDF::Dictionary
    define_field :Optional, type: Symbol, default: :Optional
  end

  before do
    @doc = HexaPDF::PDF::Document.new(io: StringIO.new(MINIMAL_PDF))
    @obj = @doc.add(@doc.wrap({Optional: :Optional}, type: TestType))
    @doc.trailer[:Test] = @obj
    @doc.revisions.add
    @obj1 = @doc.add({Type: :UsedEntry})
    @obj2 = @doc.add({Unused: @obj1})
  end

  def assert_objstms_generated
    assert(@doc.revisions.all? {|rev| rev.any? {|obj| obj.type == :ObjStm}})
    assert(@doc.revisions.all? {|rev| rev.any? {|obj| obj.type == :XRef}})
  end

  def assert_no_objstms
    assert(@doc.each(current: false).all? {|obj| obj.type != :ObjStm})
  end

  def assert_default_deleted
    refute(@obj.value.key?(:Optional))
  end

  describe "compact" do
    it "compacts the document" do
      @doc.task(:optimize, compact: true)
      refute(@doc.object?(@obj1))
      refute(@doc.object?(@obj2))
      assert_default_deleted
      assert_equal(1, @doc.revisions.each.to_a.size)
    end

    it "compacts and generates object streams" do
      @doc.task(:optimize, compact: true, object_streams: :generate)
      assert_objstms_generated
      assert_default_deleted
      assert_default_deleted
    end

    it "compacts and deletes object streams" do
      @doc.add({Type: :ObjStm})
      @doc.task(:optimize, compact: true, object_streams: :delete)
      assert_no_objstms
      assert_default_deleted
    end

    it "compacts and preserves object streams" do
      objstm = @doc.add({Type: :ObjStm})
      @doc.task(:optimize, compact: true, object_streams: :preserve)
      assert(@doc.object?(objstm))
      assert_default_deleted
    end
  end

  describe "object_streams" do
    it "generates object streams" do
      objstm = @doc.add({Type: :ObjStm})
      xref = @doc.add({Type: :XRef})
      210.times { @doc.add(5) }
      @doc.task(:optimize, object_streams: :generate)
      assert_objstms_generated
      assert_default_deleted
      assert_nil(@doc.object(objstm).value)
      assert(3, @doc.revisions.current.find_all {|obj| obj.type == :ObjStm}.size)
      assert([xref], @doc.revisions.current.find_all {|obj| obj.type == :XRef})
    end

    it "deletes object streams" do
      @doc.add({Type: :ObjStm})
      @doc.task(:optimize, object_streams: :delete)
      assert_no_objstms
      assert_default_deleted
    end

    it "preserves object streams" do
      objstm = @doc.add({Type: :ObjStm})
      @doc.task(:optimize, object_streams: :preserve)
      assert(@doc.object?(objstm))
      assert_default_deleted
    end
  end

end
