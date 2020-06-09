# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/task/optimize'

describe HexaPDF::Task::Optimize do
  class TestType < HexaPDF::Dictionary

    define_type :Test
    define_field :Optional, type: Symbol, default: :Optional

  end

  before do
    HexaPDF::GlobalConfiguration['object.type_map'][:Test] = TestType
    @doc = HexaPDF::Document.new
    @obj1 = @doc.add({Type: :Test, Optional: :Optional})
    @doc.trailer[:Test] = @doc.wrap(@obj1)
    @doc.revisions.add
    @obj2 = @doc.add({Type: :UsedEntry})
    @obj3 = @doc.add({Unused: @obj2})
    @obj4 = @doc.add({Test: :Test})
    @obj1[:Test] = @doc.wrap(@obj4, type: TestType)
  end

  after do
    HexaPDF::GlobalConfiguration['object.type_map'].delete(:Test)
  end

  def assert_objstms_generated
    assert(@doc.revisions.all? {|rev| rev.any? {|obj| obj.type == :ObjStm } })
    assert(@doc.revisions.all? {|rev| rev.any? {|obj| obj.type == :XRef } })
  end

  def assert_xrefstms_generated
    assert(@doc.revisions.all? {|rev| rev.find_all {|obj| obj.type == :XRef }.size == 1 })
  end

  def assert_no_objstms
    assert(@doc.each(only_current: false).all? {|obj| obj.type != :ObjStm })
  end

  def assert_no_xrefstms
    assert(@doc.each(only_current: false).all? {|obj| obj.type != :XRef })
  end

  def assert_default_deleted
    refute(@doc.object(1).key?(:Optional))
  end

  describe "compact" do
    it "compacts the document" do
      @doc.task(:optimize, compact: true)
      assert_equal(1, @doc.revisions.size)
      assert_equal(2, @doc.each(only_current: false).to_a.size)
      refute_equal(@obj2, @doc.object(@obj2))
      refute_equal(@obj3, @doc.object(@obj3))
      assert_default_deleted
      assert_equal(2, @obj4.oid)
      assert_equal(@obj1[:Test], @obj4)
    end

    it "compacts and generates object streams" do
      @doc.task(:optimize, compact: true, object_streams: :generate)
      assert_objstms_generated
      assert_default_deleted
    end

    it "compacts and deletes object streams" do
      @doc.add({Type: :ObjStm})
      @doc.task(:optimize, compact: true, object_streams: :delete)
      assert_no_objstms
      assert_default_deleted
    end

    it "compacts and generates xref streams" do
      @doc.task(:optimize, compact: true, xref_streams: :generate)
      assert_xrefstms_generated
      assert_default_deleted
    end

    it "compacts and deletes xref streams" do
      @doc.add({Type: :XRef}, revision: 0)
      @doc.add({Type: :XRef}, revision: 1)
      @doc.task(:optimize, compact: true, xref_streams: :delete)
      assert_no_xrefstms
      assert_default_deleted
    end
  end

  describe "object_streams" do
    def reload_document_with_objstm_from_io
      io = StringIO.new
      objstm = @doc.add({Type: :ObjStm})
      @doc.add({Type: :XRef})
      objstm.add_object(@doc.add({Type: :Test}))
      @doc.write(io)
      io.rewind
      @doc = HexaPDF::Document.new(io: io)
    end

    it "generates object streams" do
      210.times { @doc.add(5) }
      objstm = @doc.add({Type: :ObjStm})
      reload_document_with_objstm_from_io
      @doc.task(:optimize, object_streams: :generate)
      assert_objstms_generated
      assert_default_deleted
      assert_nil(@doc.object(objstm).value)
      assert_equal(2, @doc.revisions.current.find_all {|obj| obj.type == :ObjStm }.size)
    end

    it "deletes object and xref streams" do
      reload_document_with_objstm_from_io
      @doc.task(:optimize, object_streams: :delete, xref_streams: :delete)
      assert_no_objstms
      assert_no_xrefstms
      assert_default_deleted
    end

    it "deletes object and generates xref streams" do
      @doc.add({Type: :ObjStm})
      xref = @doc.add({Type: :XRef})
      @doc.task(:optimize, object_streams: :delete, xref_streams: :generate)
      assert_no_objstms
      assert_xrefstms_generated
      assert_equal([xref], @doc.revisions.current.find_all {|obj| obj.type == :XRef })
      assert_default_deleted
    end
  end

  describe "xref_streams" do
    it "generates xref streams" do
      @doc.task(:optimize, xref_streams: :generate)
      assert_xrefstms_generated
      assert_default_deleted
    end

    it "reuses an xref stream in generatation mode" do
      @doc.add({Type: :XRef})
      @doc.task(:optimize, xref_streams: :generate)
      assert_xrefstms_generated
    end

    it "deletes xref streams" do
      @doc.add({Type: :XRef})
      @doc.task(:optimize, xref_streams: :delete)
      assert_no_xrefstms
      assert_default_deleted
    end
  end

  describe "compress_pages" do
    it "compresses pages streams" do
      page = @doc.pages.add
      page.contents = "   10  10   m    q            Q    BI /Name   5 ID dataEI   "
      @doc.task(:optimize, compress_pages: true)
      assert_equal("10 10 m\nq\nQ\nBI\n/Name 5 ID\ndataEI\n", page.contents)
    end
  end
end
