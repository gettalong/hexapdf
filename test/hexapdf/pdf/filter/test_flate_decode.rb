# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/filter/flate_decode'

class PDFFilterFlateDecodeTest < Minitest::Test

  include TestHelper
  include FilterHelper

  def setup
    @obj = HexaPDF::PDF::Filter::FlateDecode
  end

  def test_decoder
    assert_raises(HexaPDF::Error) do
      collector(@obj.decoder(feeder("some test")))
    end
  end

end
