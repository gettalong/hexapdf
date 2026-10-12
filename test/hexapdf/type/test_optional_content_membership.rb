# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/type/optional_content_membership'
require 'hexapdf/document'

describe HexaPDF::Type::OptionalContentMembership do
  before do
    @doc = HexaPDF::Document.new
    @ocmd = @doc.add({Type: :OCMD})
  end

  describe "ocgs" do
    before do
      @ocg = @doc.add({Type: :OCG, Name: "test"})
    end

    it "uses the /OCGs entry if /VE is not available" do
      assert_equal([], @ocmd.ocgs)

      @ocmd[:OCGs] = []
      assert_equal([], @ocmd.ocgs)

      @ocmd[:OCGs] = @ocg
      assert_equal([@ocg], @ocmd.ocgs)

      null = @doc.add({})
      null.data.value = nil
      @ocmd[:OCGS] = [@ocg, nil, null, @ocg]
      assert_equal([@ocg], @ocmd.ocgs)
    end

    it "uses the /VE entry if available" do
      null = @doc.add({})
      null.data.value = nil
      @ocmd[:VE] = [:Or, @ocg, nil, [:Not, @ocg], [:And, @ocg, [:Or, null, @ocg]]]
      assert_equal([@ocg], @ocmd.ocgs)
    end
  end
end
