# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/revisions'
require 'hexapdf/pdf/document'
require 'stringio'

describe HexaPDF::PDF::Revisions do

  before do
    @io = StringIO.new(<<EOF)
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
200
endobj

xref
2 1
0000000158 00000 n 
trailer
<< /Size 3 /Prev 47 >>
startxref
178
%%EOF
EOF
    @doc = HexaPDF::PDF::Document.new(io: @io)
    @revisions = @doc.revisions
  end

  describe "add" do
    it "adds an empty revision as the current revision" do
      rev = @revisions.add
      assert_equal({Size: 3}, rev.trailer.value)
      assert_equal(rev, @revisions.current)
    end
  end

  describe "delete_revision" do
    it "allows deleting a revision by index" do
      rev = @revisions.revision(0)
      @revisions.delete(0)
      refute(@revisions.any? {|r| r == rev})
    end

    it "allows deleting a revision by specifying a revision" do
      rev = @revisions.revision(0)
      @revisions.delete(rev)
      refute(@revisions.any? {|r| r == rev})
    end

    it "fails when trying to delete the only existing revision" do
      assert_raises(HexaPDF::Error) { @revisions.delete(0) while @revisions.current }
    end
  end

  describe "initialize" do
    it "automatically loads all revisions from the underlying IO object" do
      assert_equal(20, @revisions.revision(0).object(2).value)
      assert_equal(200, @revisions.revision(1).object(2).value)
    end
  end

end
