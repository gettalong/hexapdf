# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/type/optional_content_group'
require 'hexapdf/document'

describe HexaPDF::Type::OptionalContentGroup do
  it "resolves all referenced type classes" do
    doc = HexaPDF::Document.new
    hash = {
      Usage: {
        CreatorInfo: {},
        Language: {},
        Export: {},
        Zoom: {},
        Print: {},
        View: {},
        User: {},
        PageElement: {}
      }
    }
    ocg = doc.add(hash, type: :OCG)
    assert_kind_of(HexaPDF::Type::OptionalContentGroup, ocg)
    ocu = ocg[:Usage]
    assert_kind_of(HexaPDF::Type::OptionalContentGroup::OptionalContentUsage, ocu)
    assert_kind_of(HexaPDF::Type::OptionalContentGroup::OptionalContentUsage::CreatorInfo,
                   ocu[:CreatorInfo])
    assert_kind_of(HexaPDF::Type::OptionalContentGroup::OptionalContentUsage::Language,
                   ocu[:Language])
    assert_kind_of(HexaPDF::Type::OptionalContentGroup::OptionalContentUsage::Export,
                   ocu[:Export])
    assert_kind_of(HexaPDF::Type::OptionalContentGroup::OptionalContentUsage::Zoom,
                   ocu[:Zoom])
    assert_kind_of(HexaPDF::Type::OptionalContentGroup::OptionalContentUsage::Print,
                   ocu[:Print])
    assert_kind_of(HexaPDF::Type::OptionalContentGroup::OptionalContentUsage::View,
                   ocu[:View])
    assert_kind_of(HexaPDF::Type::OptionalContentGroup::OptionalContentUsage::User,
                   ocu[:User])
    assert_kind_of(HexaPDF::Type::OptionalContentGroup::OptionalContentUsage::PageElement,
                   ocu[:PageElement])
  end
end
