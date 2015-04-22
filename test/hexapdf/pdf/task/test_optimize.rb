# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/document'
require 'hexapdf/pdf/task/optimize'

describe HexaPDF::PDF::Task::Optimize do

  class TestType < HexaPDF::PDF::Dictionary
    define_field :Optional, type: Symbol, default: :Optional
  end

  before do
    @doc = HexaPDF::PDF::Document.new
    @obj = @doc.add(@doc.wrap({Optional: :Optional}, type: TestType))
  end

  it "deletes entries which are optional and set to their default value" do
    @doc.task(:optimize, delete_fields_with_defaults: true)
    refute(@obj.value.key?(:Optional))
  end

end
