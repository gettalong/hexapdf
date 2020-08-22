# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/revisions'
require 'hexapdf/document'
require 'stringio'

describe HexaPDF::Revisions do
  before do
    @io = StringIO.new(<<~EOF)
      %PDF-1.7
      1 0 obj
      10
      endobj

      2 0 obj
      20
      endobj

      xref
      0 3
      0000000000 65535 f 
      0000000009 00000 n 
      0000000028 00000 n 
      trailer
      << /Size 3 >>
      startxref
      47
      %%EOF

      2 0 obj
      300
      endobj

      3 0 obj
      << /Type /XRef /Size 4 /Index [2 1] /W [1 1 1] /Filter /ASCIIHexDecode /Length 6
      >>stream
      019E00
      endstream
      endobj

      2 0 obj
      200
      endobj

      xref
      2 2
      0000000301 00000 n 
      0000000178 00000 n 
      trailer
      << /Size 4 /Prev 47 >>
      startxref
      321
      %%EOF

      2 0 obj
      400
      endobj

      xref
      2 1
      0000000422 00000 n 
      trailer
      << /Size 4 /Prev 321 /XRefStm 178 >>
      startxref
      442
      %%EOF
    EOF
    @doc = HexaPDF::Document.new(io: @io)
    @revisions = @doc.revisions
  end

  describe "add" do
    it "adds an empty revision as the current revision" do
      rev = @revisions.add
      assert_equal({Size: 4}, rev.trailer.value)
      assert_equal(rev, @revisions.current)
    end
  end

  describe "delete_revision" do
    it "allows deleting a revision by index" do
      rev = @revisions.revision(0)
      @revisions.delete(0)
      refute(@revisions.any? {|r| r == rev })
    end

    it "allows deleting a revision by specifying a revision" do
      rev = @revisions.revision(0)
      @revisions.delete(rev)
      refute(@revisions.any? {|r| r == rev })
    end

    it "fails when trying to delete the only existing revision" do
      assert_raises(HexaPDF::Error) { @revisions.delete(0) while @revisions.current }
    end
  end

  describe "merge" do
    it "does nothing when only one revision is specified" do
      @revisions.merge(1..1)
      assert_equal(3, @revisions.each.to_a.size)
    end

    it "merges the higher into the the lower revision" do
      @revisions.merge
      assert_equal(1, @revisions.each.to_a.size)
      assert_equal([10, 400, @doc.object(3).value], @revisions.current.each.to_a.sort.map(&:value))
    end

    it "handles objects correctly that are in multiple revisions" do
      @revisions.current.add(@revisions[0].object(1))
      @revisions.merge
      assert_equal(1, @revisions.each.to_a.size)
      assert_equal([10, 400, @doc.object(3).value], @revisions.current.each.to_a.sort.map(&:value))
    end
  end

  describe "initialize" do
    it "automatically loads all revisions from the underlying IO object" do
      assert_kind_of(HexaPDF::Parser, @revisions.parser)
      assert_equal(20, @revisions.revision(0).object(2).value)
      assert_equal(300, @revisions[1].object(2).value)
      assert_equal(400, @revisions[2].object(2).value)
    end
  end

  it "handles invalid PDFs that have a loop via the xref /Prev or /XRefStm entries" do
    io = StringIO.new(<<~EOF)
      %PDF-1.7
      1 0 obj
      10
      endobj

      xref
      0 2
      0000000000 65535 f 
      0000000009 00000 n 
      trailer
      << /Size 2 /Prev 148>>
      startxref
      28
      %%EOF

      2 0 obj
      300
      endobj

      xref
      2 1
      0000000301 00000 n 
      trailer
      << /Size 3 /Prev 28 /XRefStm 148>>
      startxref
      148
      %%EOF
    EOF
    doc = HexaPDF::Document.new(io: io)
    assert_equal(2, doc.revisions.count)
  end

  it "uses the reconstructed revision if errors are found when loading from an IO" do
    io = StringIO.new(<<~EOF)
      %PDF-1.7
      1 0 obj
      10
      endobj

      xref
      0 2
      0000000000 65535 f 
      0000000009 00000 n 
      trailer
      << /Size 5 >>
      startxref
      28
      %%EOF

      2 0 obj
      300
      endobj

      xref
      2 1
      0000000301 00000 n 
        trailer
      << /Size 3 /Prev 100>>
      startxref
      139
      %%EOF
    EOF
    doc = HexaPDF::Document.new(io: io)
    assert_equal(2, doc.revisions.count)
    assert_same(doc.revisions[0].trailer.value, doc.revisions[1].trailer.value)
  end
end
